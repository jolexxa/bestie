import 'dart:convert';

import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/// An assistant message split into visible content and reasoning.
final class AssistantSegments {
  const AssistantSegments({required this.content, required this.reasoning});

  final String content;
  final String reasoning;
}

/// Shared skeleton for ChatML-framed chat templates
/// (`<|im_start|>role\n...<|im_end|>\n`).
///
/// Subclasses provide the system block, assistant-turn rendering, and any
/// generation-prompt prologue; message framing, tool-response grouping, and
/// the trailing assistant header are common to the family.
abstract base class ChatMlPromptFormatter extends PromptFormatter {
  const ChatMlPromptFormatter();

  @override
  String format({
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required String reasoningMode,
    String? assistantPrefill,
  }) {
    final buffer = StringBuffer();

    writeSystemBlock(buffer, messages, tools);

    for (var i = 0; i < messages.length; i += 1) {
      final message = messages[i];

      switch (message) {
        case PromptSystemMessage() || PromptDeveloperMessage():
          if (i == 0) continue;
          buffer
            ..write('<|im_start|>system\n')
            ..write(renderContent(message.content))
            ..write('<|im_end|>\n');
        case PromptUserMessage():
          buffer
            ..write('<|im_start|>user\n')
            ..write(renderContent(message.content))
            ..write('<|im_end|>\n');
        case PromptAssistantMessage():
          writeAssistantMessage(buffer, message, i, messages);
        case PromptToolMessage():
          _writeToolMessage(buffer, message, i, messages);
      }
    }

    buffer.write('<|im_start|>assistant\n');
    writeGenerationPrologue(buffer, reasoningMode);
    buffer.write(assistantPrefill ?? '');
    return buffer.toString();
  }

  /// Renders user, non-leading system, and tool-response content before it is
  /// framed.
  String renderContent(String content) => content;

  /// Writes the leading system block (and tool declarations when present).
  void writeSystemBlock(
    StringBuffer buffer,
    List<PromptMessage> messages,
    List<PromptTool> tools,
  );

  /// Writes one historical assistant turn, including its tool calls and the
  /// closing `<|im_end|>\n`.
  void writeAssistantMessage(
    StringBuffer buffer,
    PromptAssistantMessage message,
    int index,
    List<PromptMessage> messages,
  );

  /// Writes template-specific text between the trailing
  /// `<|im_start|>assistant\n` header and the caller-supplied prefill.
  /// Nothing by default.
  void writeGenerationPrologue(StringBuffer buffer, String reasoningMode) {}

  void _writeToolMessage(
    StringBuffer buffer,
    PromptToolMessage message,
    int i,
    List<PromptMessage> messages,
  ) {
    final previousIsTool = i > 0 && messages[i - 1] is PromptToolMessage;
    final nextIsTool =
        i + 1 < messages.length && messages[i + 1] is PromptToolMessage;
    if (!previousIsTool) {
      buffer.write('<|im_start|>user');
    }
    buffer
      ..write('\n<tool_response>\n')
      ..write(renderContent(message.content))
      ..write('\n</tool_response>');
    if (!nextIsTool) {
      buffer.write('<|im_end|>\n');
    }
  }

  /// Carves reasoning out of an assistant message the way the shared Jinja
  /// templates do: explicit `reasoning` wins; otherwise the last
  /// `</think>`-terminated block is split out of the content.
  static AssistantSegments splitReasoning(PromptAssistantMessage message) {
    var content = message.content;
    var reasoning = '';
    final rawReasoning = message.reasoning;
    if (rawReasoning != null) {
      reasoning = rawReasoning;
    } else if (message.content.contains('</think>')) {
      final parts = message.content.split('</think>');
      content = parts.last.replaceFirst(RegExp(r'^\n+'), '');
      final beforeThink = parts.first;
      reasoning = beforeThink
          .split('<think>')
          .last
          .replaceFirst(RegExp(r'^\n+'), '')
          .replaceFirst(RegExp(r'\n+$'), '');
    }
    return AssistantSegments(content: content, reasoning: reasoning);
  }

  /// Mirrors the templates' `last_query_index` scan: the index of the last
  /// user message that is a genuine query rather than a wrapped tool
  /// response, defaulting to the final message.
  static int findLastQueryIndex(
    List<PromptMessage> messages, {
    required bool Function(String content) isToolResponseContent,
  }) {
    var lastQueryIndex = messages.length - 1;
    var multiStepTool = true;
    for (var i = messages.length - 1; i >= 0; i -= 1) {
      final message = messages[i];
      if (multiStepTool &&
          message is PromptUserMessage &&
          !isToolResponseContent(message.content)) {
        multiStepTool = false;
        lastQueryIndex = i;
      }
    }
    return lastQueryIndex;
  }

  /// Writes tool calls in the XML `<function=...><parameter=...>` form.
  /// [firstSeparator] precedes the first call when [content] is non-empty
  /// (`\n` for Qwen3-Coder, `\n\n` for Qwen 3.5); later calls are always
  /// `\n`-separated. Map and List argument values are JSON-encoded, everything
  /// else is stringified.
  static void writeXmlToolCalls(
    StringBuffer buffer,
    PromptAssistantMessage message,
    String content, {
    required String firstSeparator,
  }) {
    for (
      var callIndex = 0;
      callIndex < message.toolCalls.length;
      callIndex += 1
    ) {
      final toolCall = message.toolCalls[callIndex];
      if (callIndex == 0 && content.isNotEmpty) {
        buffer.write(firstSeparator);
      } else if (callIndex > 0) {
        buffer.write('\n');
      }
      buffer
        ..write('<tool_call>\n<function=')
        ..write(toolCall.name)
        ..write('>\n');
      for (final entry in toolCall.arguments.entries) {
        buffer
          ..write('<parameter=')
          ..write(entry.key)
          ..write('>\n');
        final value = entry.value;
        if (value is Map || value is List) {
          buffer.write(jsonEncode(value));
        } else {
          buffer.write(value);
        }
        buffer.write('\n</parameter>\n');
      }
      buffer.write('</function>\n</tool_call>');
    }
  }

  /// The `{type: function, function: {...}}` JSON declaration shape shared by
  /// Qwen-lineage `<tools>` blocks.
  static Map<String, Object?> functionToolDeclaration(PromptTool tool) {
    return <String, Object?>{
      'type': 'function',
      'function': <String, Object?>{
        'name': tool.name,
        'description': tool.description,
        'parameters': tool.parameters,
      },
    };
  }
}
