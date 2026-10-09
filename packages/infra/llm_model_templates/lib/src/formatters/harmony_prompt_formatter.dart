import 'dart:convert';

import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/// Prompt formatter for OpenAI's Harmony response format.
///
/// Reference: external/harmony/chat_template.jinja
///
/// **Note:** The Jinja template shipped by OpenAI on HuggingFace has known bugs
/// in its tool call formatting. This implementation follows the corrected spec:
/// - https://huggingface.co/openai/gpt-oss-20b/discussions/160
/// - https://huggingface.co/openai/gpt-oss-120b/discussions/69
final class HarmonyPromptFormatter extends PromptFormatter {
  const HarmonyPromptFormatter();

  @override
  String format({
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required String reasoningMode,
    String? assistantPrefill,
  }) {
    final buffer = StringBuffer()
      // System message (built-in identity + channel instructions).
      ..write('<|start|>system<|message|>')
      ..write(_buildSystemMessage(tools, reasoningMode: reasoningMode))
      ..write('<|end|>');

    // Developer message: first system/developer message + tool definitions.
    final firstMessage = messages.isEmpty ? null : messages.first;
    final hasDeveloperHeader =
        firstMessage is PromptSystemMessage ||
        firstMessage is PromptDeveloperMessage;
    final developerContent = switch (firstMessage) {
      PromptSystemMessage(:final content) ||
      PromptDeveloperMessage(:final content) => content,
      _ => null,
    };
    final loopStart = hasDeveloperHeader ? 1 : 0;

    if (developerContent != null || tools.isNotEmpty) {
      buffer.write('<|start|>developer<|message|>');
      if (developerContent != null) {
        buffer
          ..write('# Instructions\n\n')
          ..write(developerContent)
          ..write('\n\n');
      }
      if (tools.isNotEmpty) {
        buffer
          ..write('# Tools\n\n')
          ..write(_renderToolNamespace('functions', tools));
      }
      buffer.write('<|end|>');
    }

    // Render conversation messages.
    String? lastToolCallName;
    final lastFinalAssistantIndex = _lastFinalAssistantIndex(messages);
    for (var i = loopStart; i < messages.length; i += 1) {
      final message = messages[i];

      switch (message) {
        case PromptUserMessage():
          buffer
            ..write('<|start|>user<|message|>')
            ..write(message.content)
            ..write('<|end|>');

        case PromptAssistantMessage():
          if (message.toolCalls.isNotEmpty) {
            // Tool call turn.
            final toolCall = message.toolCalls.first;
            // Render analysis only if no later assistant `final` exists in
            // history. Per Harmony spec: once a `final` channel message has
            // been emitted, all preceding `analysis` blocks must be pruned.
            // The model was trained on pruned histories; retaining stale
            // analysis is out-of-distribution.
            final reasoning = message.reasoning;
            if (reasoning != null &&
                reasoning.isNotEmpty &&
                i > lastFinalAssistantIndex) {
              buffer
                ..write('<|start|>assistant<|channel|>analysis<|message|>')
                ..write(reasoning)
                ..write('<|end|>');
            }
            buffer
              ..write('<|start|>assistant<|channel|>commentary to=functions.')
              ..write(toolCall.name)
              ..write(' <|constrain|>json<|message|>')
              ..write(jsonEncode(toolCall.arguments))
              ..write('<|call|>');
            lastToolCallName = toolCall.name;
          } else {
            // Regular assistant message → final channel.
            buffer
              ..write('<|start|>assistant<|channel|>final<|message|>')
              ..write(message.content)
              ..write('<|end|>');
            lastToolCallName = null;
          }

        case PromptToolMessage():
          buffer
            ..write('<|start|>functions.')
            ..write(lastToolCallName ?? message.name)
            ..write(' to=assistant<|channel|>commentary<|message|>')
            ..write(jsonEncode(message.content))
            ..write('<|end|>');

        case PromptDeveloperMessage():
          buffer
            ..write('<|start|>developer<|message|>')
            ..write(message.content)
            ..write('<|end|>');

        case PromptSystemMessage():
          // Additional system messages after the first are treated as user.
          buffer
            ..write('<|start|>user<|message|>')
            ..write(message.content)
            ..write('<|end|>');
      }
    }

    // Generation prompt. Harmony always opens an analysis channel first, so
    // seeding the final channel directly is out-of-distribution. To skip
    // reasoning we emit an empty analysis channel and then jump to final, which
    // is in-distribution and lets the prefill seed carry. An empty prefill
    // leaves the model to reason and produce its own final channel.
    if (assistantPrefill == null || assistantPrefill.isEmpty) {
      buffer.write('<|start|>assistant');
    } else {
      buffer
        ..write('<|start|>assistant<|channel|>analysis<|message|><|end|>')
        ..write('<|start|>assistant<|channel|>final<|message|>')
        ..write(assistantPrefill);
    }

    return buffer.toString();
  }

  @override
  List<String> get stopSequences => const <String>[
    '<|call|>',
    '<|return|>',
  ];

  @override
  bool get addBos => true;

  // ── Private ──────────────────────────────────────────

  static String _buildSystemMessage(
    List<PromptTool> tools, {
    required String reasoningMode,
  }) {
    final buf = StringBuffer()
      ..write('You are ChatGPT, a large language model trained by OpenAI.\n')
      ..write('Knowledge cutoff: 2024-06\n\n')
      ..write('Reasoning: $reasoningMode\n\n')
      ..write('# Valid channels: analysis, commentary, final. ')
      ..write('Channel must be included for every message.');
    if (tools.isNotEmpty) {
      buf.write(
        "\nCalls to these tools must go to the commentary channel: 'functions'.",
      );
    }
    return buf.toString();
  }

  /// Index of the last assistant turn with no tool calls, or `-1` if
  /// none. Tool-call turns at indices `<=` this boundary have their
  /// `analysis` channel pruned per Harmony spec.
  static int _lastFinalAssistantIndex(List<PromptMessage> messages) {
    return messages.lastIndexWhere(
      (message) =>
          message is PromptAssistantMessage && message.toolCalls.isEmpty,
    );
  }

  static String _renderToolNamespace(
    String ns,
    List<PromptTool> tools,
  ) {
    final buf = StringBuffer()
      ..write('## $ns\n\n')
      ..write('namespace $ns {\n\n');
    for (final tool in tools) {
      buf
        ..write('// ')
        ..write(tool.description)
        ..write('\n')
        ..write('type ')
        ..write(tool.name)
        ..write(' = ');
      final params = tool.parameters;
      final rawProps = params['properties'];
      final properties = rawProps is Map
          ? Map<String, Object?>.from(rawProps)
          : <String, Object?>{};
      if (properties.isNotEmpty) {
        final required = (params['required'] as List<Object?>? ?? const [])
            .cast<String>()
            .toSet();
        buf.write('(_: {\n');
        final entries = properties.entries.toList();
        for (var i = 0; i < entries.length; i += 1) {
          final entry = entries[i];
          final rawSpec = entry.value;
          final spec = rawSpec is Map
              ? Map<String, Object?>.from(rawSpec)
              : <String, Object?>{};
          final desc = spec['description'] as String?;
          if (desc != null) {
            buf
              ..write('// ')
              ..write(desc)
              ..write('\n');
          }
          buf.write(entry.key);
          if (!required.contains(entry.key)) {
            buf.write('?');
          }
          buf
            ..write(': ')
            ..write(_jsonSchemaToTypeScript(spec))
            ..write(',\n');
        }
        buf.write('}) => any;\n\n');
      } else {
        buf.write('() => any;\n\n');
      }
    }
    buf
      ..write('} // namespace ')
      ..write(ns);
    return buf.toString();
  }

  static String _jsonSchemaToTypeScript(Map<String, Object?> spec) {
    final type = spec['type'];

    if (type == 'string') {
      final enumValues = spec['enum'] as List<Object?>?;
      if (enumValues != null) {
        return enumValues.map((value) => '"$value"').join(' | ');
      }
      return 'string';
    }
    if (type == 'number' || type == 'integer') return 'number';
    if (type == 'boolean') return 'boolean';
    if (type == 'array') {
      final rawItems = spec['items'];
      if (rawItems is Map) {
        return '${_jsonSchemaToTypeScript(Map<String, Object?>.from(rawItems))}[]';
      }
      return 'any[]';
    }
    if (type == 'object') {
      final rawProps = spec['properties'];
      if (rawProps is Map && rawProps.isNotEmpty) {
        final props = Map<String, Object?>.from(rawProps);
        final required = (spec['required'] as List<Object?>? ?? const [])
            .cast<String>()
            .toSet();
        final fields = props.entries
            .map((entry) {
              final rawPSpec = entry.value;
              final pSpec = rawPSpec is Map
                  ? Map<String, Object?>.from(rawPSpec)
                  : <String, Object?>{};
              final opt = required.contains(entry.key) ? '' : '?';
              return '${entry.key}$opt: ${_jsonSchemaToTypeScript(pSpec)}';
            })
            .join(', ');
        return '{ $fields }';
      }
      return 'object';
    }

    return 'any';
  }
}
