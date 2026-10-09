import 'dart:convert';

import 'package:llm_model_templates/src/formatters/chat_ml_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/// Qwen 3 Coder chat template with XML-style tool definitions and tool calls.
final class Qwen3CoderPromptFormatter extends ChatMlPromptFormatter {
  const Qwen3CoderPromptFormatter();

  static const _defaultSystemPrompt =
      'You are Qwen, a helpful AI assistant that can interact with a '
      'computer to solve tasks.';

  @override
  void writeSystemBlock(
    StringBuffer buffer,
    List<PromptMessage> messages,
    List<PromptTool> tools,
  ) {
    if (tools.isNotEmpty) {
      buffer.write('<|im_start|>system\n');
      if (messages.isNotEmpty && messages.first.isSystemLike) {
        buffer
          ..write(messages.first.content)
          ..write('\n\n');
      } else {
        buffer
          ..write(_defaultSystemPrompt)
          ..write('\n\n');
      }
      buffer.write(
        '# Tools\n\nYou have access to the following functions:\n\n<tools>',
      );
      for (final tool in tools) {
        _writePromptTool(buffer, tool);
      }
      buffer.write(
        '\n</tools>\n\n'
        'If you choose to call a function ONLY reply in the following format '
        'with NO suffix:\n\n'
        '<tool_call>\n'
        '<function=example_function_name>\n'
        '<parameter=example_parameter_1>\n'
        'value_1\n'
        '</parameter>\n'
        '<parameter=example_parameter_2>\n'
        'This is the value for the second parameter\n'
        'that can span\n'
        'multiple lines\n'
        '</parameter>\n'
        '</function>\n'
        '</tool_call>\n\n'
        '<IMPORTANT>\n'
        'Reminder:\n'
        '- Function calls MUST follow the specified format: an inner '
        '<function=...></function> block must be nested within '
        '<tool_call></tool_call> XML tags\n'
        '- Required parameters MUST be specified\n'
        '- You may provide optional reasoning for your function call in '
        'natural language BEFORE the function call, but NOT after\n'
        '- If there is no function call available, answer the question like '
        'normal with your current knowledge and do not tell the user about '
        'function calls\n'
        '</IMPORTANT>'
        '<|im_end|>\n',
      );
    } else if (messages.isNotEmpty && messages.first.isSystemLike) {
      buffer
        ..write('<|im_start|>system\n')
        ..write(messages.first.content)
        ..write('<|im_end|>\n');
    }
  }

  static void _writePromptTool(StringBuffer buffer, PromptTool tool) {
    buffer
      ..write('\n<function>\n<name>')
      ..write(tool.name)
      ..write('</name>');
    if (tool.description.isNotEmpty) {
      buffer
        ..write('\n<description>')
        ..write(tool.description)
        ..write('</description>');
    }
    buffer.write('\n<parameters>');
    final rawProps = tool.parameters['properties'];
    final properties = rawProps is Map
        ? Map<String, Object?>.from(rawProps)
        : <String, Object?>{};
    for (final entry in properties.entries) {
      final rawSpec = entry.value is Map
          ? Map<String, Object?>.from(entry.value! as Map)
          : <String, Object?>{};
      buffer
        ..write('\n<parameter>\n<name>')
        ..write(entry.key)
        ..write('</name>');
      if (rawSpec['type'] case final String type) {
        buffer
          ..write('\n<type>')
          ..write(type)
          ..write('</type>');
      }
      if (rawSpec['description'] case final String desc) {
        buffer
          ..write('\n<description>')
          ..write(desc)
          ..write('</description>');
      }
      if (rawSpec['enum'] case final List<Object?> values) {
        buffer
          ..write('\n<enum>')
          ..write(jsonEncode(values))
          ..write('</enum>');
      }
      buffer.write('\n</parameter>');
    }
    // Render extra keys on the parameters object (e.g. required).
    final rawRequired = tool.parameters['required'];
    if (rawRequired is List && rawRequired.isNotEmpty) {
      buffer
        ..write('\n<required>')
        ..write(jsonEncode(rawRequired))
        ..write('</required>');
    }
    buffer.write('\n</parameters>\n</function>');
  }

  @override
  void writeAssistantMessage(
    StringBuffer buffer,
    PromptAssistantMessage message,
    int index,
    List<PromptMessage> messages,
  ) {
    final content = message.content;
    buffer
      ..write('<|im_start|>assistant\n')
      ..write(content);
    ChatMlPromptFormatter.writeXmlToolCalls(
      buffer,
      message,
      content,
      firstSeparator: '\n',
    );
    buffer.write('<|im_end|>\n');
  }

  @override
  List<String> get stopSequences => const <String>[
    '<|im_end|>',
    '<|im_start|>',
  ];

  @override
  bool get addBos => true;
}
