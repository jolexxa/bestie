import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/// Gemma 4 chat template formatter.
///
/// Reference: HuggingFace gemma-4-*-it chat_template.jinja
///
/// Key format differences from ChatML-based models:
/// - Turn delimiters: `<|turn>role\n` ... `<turn|>\n`
/// - Role mapping: assistant → model
/// - Tool declarations: `<|tool>declaration:name{...}<tool|>`
/// - Tool calls: `<|tool_call>call:name{key:val}<tool_call|>`
/// - Tool responses: `<|tool_response>response:name{value:val}<tool_response|>`
/// - Reasoning: `<|think|>` in system, `<|channel>thought\n...\n<channel|>`
/// - String values use `<|"|>` delimiters
final class Gemma4PromptFormatter extends PromptFormatter {
  const Gemma4PromptFormatter();

  static const _sd = '<|"|>'; // string delimiter

  @override
  String format({
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required String reasoningMode,
    String? assistantPrefill,
  }) {
    final buffer = StringBuffer();
    final thinkingEnabled = reasoningMode != 'off';

    // Determine which messages go in loop_messages (after system extraction).
    final hasSystem = messages.isNotEmpty && messages.first.isSystemLike;
    final loopMessages = hasSystem ? messages.sublist(1) : messages;

    // ── System block ───────────────────────────────────────────────
    _writeSystemBlock(
      buffer,
      messages: messages,
      tools: tools,
      thinkingEnabled: thinkingEnabled,
    );

    // ── Pre-scan: find last user message index for reasoning guard ─
    var lastUserIndex = -1;
    for (var i = 0; i < loopMessages.length; i++) {
      if (loopMessages[i] is PromptUserMessage) lastUserIndex = i;
    }

    // ── Message loop ───────────────────────────────────────────────
    // Tracks prev_message_type for turn closing logic.
    var prevMessageType = _MsgType.none;

    for (var i = 0; i < loopMessages.length; i++) {
      final message = loopMessages[i];

      // Tool messages are consumed by forward-scan, not rendered directly.
      if (message is PromptToolMessage) continue;

      prevMessageType = _MsgType.none;
      final role = message is PromptAssistantMessage
          ? 'model'
          : message.chatMlRole;

      // ── Model turn continuation ────────────────────────────────
      final continueSameModelTurn =
          role == 'model' &&
          _previousNonToolMessage(loopMessages, i) is PromptAssistantMessage;

      if (!continueSameModelTurn) {
        buffer
          ..write('<|turn>')
          ..write(role)
          ..write('\n');
      }

      // ── Reasoning content ──────────────────────────────────────
      final thinkingText = message.reasoning;
      if (thinkingText != null &&
          thinkingText.isNotEmpty &&
          i > lastUserIndex &&
          message.toolCalls.isNotEmpty) {
        buffer
          ..write('<|channel>thought\n')
          ..write(thinkingText)
          ..write('\n<channel|>');
      }

      // ── Tool calls ─────────────────────────────────────────────
      if (message.toolCalls.isNotEmpty) {
        for (final toolCall in message.toolCalls) {
          buffer
            ..write('<|tool_call>call:')
            ..write(toolCall.name)
            ..write('{');
          _writeMapEntries(buffer, toolCall.arguments);
          buffer.write('}<tool_call|>');
        }
        prevMessageType = _MsgType.toolCall;
      }

      // ── Tool responses (forward-scan) ──────────────────────────
      var hasToolResponses = false;
      if (message.toolCalls.isNotEmpty) {
        for (
          var responseIndex = i + 1;
          responseIndex < loopMessages.length &&
              loopMessages[responseIndex] is PromptToolMessage;
          responseIndex++
        ) {
          final toolMsg = loopMessages[responseIndex] as PromptToolMessage;
          final toolName = _resolveToolName(toolMsg, message);
          buffer
            ..write('<|tool_response>response:')
            ..write(toolName)
            ..write('{value:')
            ..write(_formatValue(toolMsg.content, escapeKeys: false))
            ..write('}<tool_response|>');
          hasToolResponses = true;
          prevMessageType = _MsgType.toolResponse;
        }
      }

      // ── Content ────────────────────────────────────────────────
      if (message.content.isNotEmpty) {
        if (role == 'model') {
          buffer.write(_stripThinking(message.content));
        } else {
          buffer.write(message.content.trim());
        }
      }

      // ── Turn closing ───────────────────────────────────────────
      if (prevMessageType == _MsgType.toolCall && !hasToolResponses) {
        // Awaiting tool response — emit bare <|tool_response>.
        buffer.write('<|tool_response>');
      } else if (hasToolResponses && message.content.isEmpty) {
        // Tool responses emitted, no text — turn continues.
      } else {
        buffer.write('<turn|>\n');
        // Divergence from the reference gemma-4 jinja: it leaves
        // prevMessageType as toolResponse after closing the turn, which
        // suppresses the generation prompt below. That strands a *narrated*
        // tool call with thinking off (planning prose lands in content, not a
        // stripped thought channel) on a closed turn with no `<|turn>model` —
        // the model then emits a stop token and the agent loop halts. Closing
        // the turn means we're between turns, so clear the signal and let the
        // generation prompt open a fresh model turn to answer into.
        prevMessageType = _MsgType.none;
      }
    }

    // ── Generation prompt ──────────────────────────────────────────
    if (prevMessageType != _MsgType.toolResponse &&
        prevMessageType != _MsgType.toolCall) {
      buffer.write('<|turn>model\n');
      if (!thinkingEnabled) {
        buffer.write('<|channel>thought\n<channel|>');
      }
      buffer.write(assistantPrefill ?? '');
    }

    return buffer.toString();
  }

  @override
  List<String> get stopSequences => const <String>['<turn|>', '<|turn>'];

  @override
  bool get addBos => true;

  // ── System block ─────────────────────────────────────────────────

  static void _writeSystemBlock(
    StringBuffer buffer, {
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required bool thinkingEnabled,
  }) {
    final hasSystem = messages.isNotEmpty && messages.first.isSystemLike;

    if (!thinkingEnabled && tools.isEmpty && !hasSystem) return;

    buffer.write('<|turn>system\n');

    if (thinkingEnabled) {
      buffer.write('<|think|>\n');
    }

    if (hasSystem) {
      buffer.write(messages.first.content.trim());
    }

    for (final tool in tools) {
      buffer
        ..write('<|tool>')
        ..write(_formatToolDeclaration(tool))
        ..write('<tool|>');
    }

    buffer.write('<turn|>\n');
  }

  // ── Tool declarations ────────────────────────────────────────────

  static String _formatToolDeclaration(PromptTool tool) {
    final buf = StringBuffer()
      ..write('declaration:')
      ..write(tool.name)
      ..write('{description:$_sd')
      ..write(tool.description)
      ..write(_sd);

    final params = tool.parameters;
    if (params.isNotEmpty) {
      buf.write(',parameters:{');

      final rawProps = params['properties'];
      if (rawProps is Map) {
        buf.write('properties:{');
        _writeSchemaProperties(
          buf,
          Map<String, Object?>.from(rawProps),
          (params['required'] as List<Object?>?)?.cast<String>() ?? const [],
        );
        buf.write('},');
      }

      final required = params['required'];
      if (required is List && required.isNotEmpty) {
        buf.write('required:[');
        for (var i = 0; i < required.length; i++) {
          if (i > 0) buf.write(',');
          buf
            ..write(_sd)
            ..write(required[i])
            ..write(_sd);
        }
        buf.write('],');
      }

      final type = params['type'];
      if (type is String) {
        buf
          ..write('type:$_sd')
          ..write(type.toUpperCase())
          ..write('$_sd}');
      }
    }

    buf.write('}');
    return buf.toString();
  }

  /// Writes JSON Schema properties in Gemma's structured format.
  ///
  /// Mirrors the Jinja `format_parameters` macro: iterates properties in
  /// sorted order, skipping standard schema keys used as property names.
  static void _writeSchemaProperties(
    StringBuffer buf,
    Map<String, Object?> properties,
    List<String> required,
  ) {
    const standardKeys = {
      'description',
      'type',
      'properties',
      'required',
      'nullable',
    };

    final sortedKeys = properties.keys.toList()..sort();
    var first = true;

    for (final key in sortedKeys) {
      if (standardKeys.contains(key)) continue;

      final rawValue = properties[key];
      if (rawValue is! Map) continue;
      final value = Map<String, Object?>.from(rawValue);

      if (!first) buf.write(',');
      first = false;

      buf
        ..write(key)
        ..write(':{');

      var addedField = false;

      // description
      final desc = value['description'];
      if (desc is String) {
        buf
          ..write('description:$_sd')
          ..write(desc)
          ..write(_sd);
        addedField = true;
      }

      final type = (value['type'] as String?)?.toUpperCase() ?? '';

      // STRING: optional enum
      if (type == 'STRING') {
        final enumValues = value['enum'];
        if (enumValues is List) {
          if (addedField) buf.write(',');
          buf.write('enum:');
          _writeFormattedValue(buf, enumValues, escapeKeys: true);
          addedField = true;
        }
      }

      // ARRAY: optional items
      if (type == 'ARRAY') {
        final items = value['items'];
        if (items is Map) {
          if (addedField) buf.write(',');
          buf.write('items:{');
          _writeItemsBlock(buf, Map<String, Object?>.from(items));
          buf.write('}');
          addedField = true;
        }
      }

      // nullable
      final nullable = value['nullable'];
      if (nullable == true) {
        if (addedField) buf.write(',');
        buf.write('nullable:true');
        addedField = true;
      }

      // OBJECT: nested properties + required
      if (type == 'OBJECT') {
        final nestedProps = value['properties'];
        if (nestedProps is Map) {
          if (addedField) buf.write(',');
          buf.write('properties:{');
          _writeSchemaProperties(
            buf,
            Map<String, Object?>.from(nestedProps),
            (value['required'] as List<Object?>?)?.cast<String>() ?? const [],
          );
          buf.write('}');
          addedField = true;
        }

        final nestedRequired = value['required'];
        if (nestedRequired is List && nestedRequired.isNotEmpty) {
          if (addedField) buf.write(',');
          buf.write('required:[');
          for (var i = 0; i < nestedRequired.length; i++) {
            if (i > 0) buf.write(',');
            buf
              ..write(_sd)
              ..write(nestedRequired[i])
              ..write(_sd);
          }
          buf.write(']');
          addedField = true;
        }
      }

      // type (always last)
      if (type.isNotEmpty) {
        if (addedField) buf.write(',');
        buf
          ..write('type:$_sd')
          ..write(type)
          ..write(_sd);
      }

      buf.write('}');
    }
  }

  /// Writes the items block for ARRAY types, mirroring the Jinja template's
  /// special handling of items sub-keys.
  static void _writeItemsBlock(StringBuffer buf, Map<String, Object?> items) {
    final sortedKeys = items.keys.toList()..sort();
    var first = true;

    for (final key in sortedKeys) {
      final value = items[key];
      if (value == null) continue;

      if (!first) buf.write(',');
      first = false;

      if (key == 'properties' && value is Map) {
        buf.write('properties:{');
        _writeSchemaProperties(
          buf,
          Map<String, Object?>.from(value),
          (items['required'] as List<Object?>?)?.cast<String>() ?? const [],
        );
        buf.write('}');
      } else if (key == 'required' && value is List) {
        buf.write('required:[');
        for (var i = 0; i < value.length; i++) {
          if (i > 0) buf.write(',');
          buf
            ..write(_sd)
            ..write(value[i])
            ..write(_sd);
        }
        buf.write(']');
      } else if (key == 'type') {
        buf.write('type:');
        if (value is String) {
          buf
            ..write(_sd)
            ..write(value.toUpperCase())
            ..write(_sd);
        } else if (value is List) {
          _writeFormattedValue(
            buf,
            value
                .map((item) => item is String ? item.toUpperCase() : item)
                .toList(),
            escapeKeys: true,
          );
        }
      } else {
        buf
          ..write(key)
          ..write(':');
        _writeFormattedValue(buf, value, escapeKeys: true);
      }
    }
  }

  // ── Value formatting ─────────────────────────────────────────────

  /// Formats a value in Gemma's structured format.
  ///
  /// When [escapeKeys] is true, map keys are wrapped in `<|"|>...<|"|>`.
  /// When false, keys are bare.
  static String _formatValue(Object? value, {required bool escapeKeys}) {
    final buf = StringBuffer();
    _writeFormattedValue(buf, value, escapeKeys: escapeKeys);
    return buf.toString();
  }

  static void _writeFormattedValue(
    StringBuffer buf,
    Object? value, {
    required bool escapeKeys,
  }) {
    if (value is String) {
      buf
        ..write(_sd)
        ..write(value)
        ..write(_sd);
    } else if (value is bool) {
      buf.write(value ? 'true' : 'false');
    } else if (value is Map) {
      buf.write('{');
      final sortedKeys = value.keys.map((key) => key.toString()).toList()
        ..sort();
      for (var i = 0; i < sortedKeys.length; i++) {
        if (i > 0) buf.write(',');
        final key = sortedKeys[i];
        if (escapeKeys) {
          buf
            ..write(_sd)
            ..write(key)
            ..write(_sd);
        } else {
          buf.write(key);
        }
        buf.write(':');
        _writeFormattedValue(buf, value[key], escapeKeys: escapeKeys);
      }
      buf.write('}');
    } else if (value is List) {
      buf.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) buf.write(',');
        _writeFormattedValue(buf, value[i], escapeKeys: escapeKeys);
      }
      buf.write(']');
    } else {
      buf.write(value);
    }
  }

  /// Writes map entries as `key:value,key:value` with sorted, bare keys.
  static void _writeMapEntries(
    StringBuffer buf,
    Map<String, Object?> map,
  ) {
    final sortedKeys = map.keys.toList()..sort();
    for (var i = 0; i < sortedKeys.length; i++) {
      if (i > 0) buf.write(',');
      buf
        ..write(sortedKeys[i])
        ..write(':');
      _writeFormattedValue(buf, map[sortedKeys[i]], escapeKeys: false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Strips `<|channel>...<channel|>` blocks from model content.
  static String _stripThinking(String text) {
    final buf = StringBuffer();
    for (final part in text.split('<channel|>')) {
      final channelIndex = part.indexOf('<|channel>');
      if (channelIndex != -1) {
        buf.write(part.substring(0, channelIndex));
      } else {
        buf.write(part);
      }
    }
    return buf.toString().trim();
  }

  /// Finds the role of the previous non-tool message, or null.
  static PromptMessage? _previousNonToolMessage(
    List<PromptMessage> messages,
    int currentIndex,
  ) {
    for (var j = currentIndex - 1; j >= 0; j--) {
      if (messages[j] is! PromptToolMessage) return messages[j];
    }
    return null;
  }

  /// Resolves the tool function name from a tool response message.
  ///
  /// Tries to match `toolCallId` against the preceding assistant's tool
  /// calls, falling back to the message's `name` field.
  static String _resolveToolName(
    PromptToolMessage toolMsg,
    PromptMessage assistantMsg,
  ) {
    for (final tc in assistantMsg.toolCalls) {
      if (tc.id == toolMsg.toolCallId) return tc.name;
    }
    return toolMsg.name;
  }
}

enum _MsgType { none, toolCall, toolResponse }
