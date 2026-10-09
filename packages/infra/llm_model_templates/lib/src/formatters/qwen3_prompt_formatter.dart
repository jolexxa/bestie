import 'dart:convert';

import 'package:llm_model_templates/src/formatters/chat_ml_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';
import 'package:llm_model_templates/src/utils/string_extensions.dart';

/*

{%- if tools %}
    {{- '<|im_start|>system\n' }}
    {%- if messages[0].role == 'system' %}
        {{- messages[0].content + '\n\n' }}
    {%- endif %}
    {{- "# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>" }}
    {%- for tool in tools %}
        {{- "\n" }}
        {{- tool | tojson }}
    {%- endfor %}
    {{- "\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call><|im_end|>\n" }}
{%- else %}
    {%- if messages[0].role == 'system' %}
        {{- '<|im_start|>system\n' + messages[0].content + '<|im_end|>\n' }}
    {%- endif %}
{%- endif %}
{%- set ns = namespace(multi_step_tool=true, last_query_index=messages|length - 1) %}
{%- for index in range(ns.last_query_index, -1, -1) %}
    {%- set message = messages[index] %}
    {%- if ns.multi_step_tool and message.role == "user" and not('<tool_response>' in message.content and '</tool_response>' in message.content) %}
        {%- set ns.multi_step_tool = false %}
        {%- set ns.last_query_index = index %}
    {%- endif %}
{%- endfor %}
{%- for message in messages %}
    {%- if (message.role == "user") or (message.role == "system" and not loop.first) %}
        {{- '<|im_start|>' + message.role + '\n' + message.content + '<|im_end|>' + '\n' }}
    {%- elif message.role == "assistant" %}
        {%- set content = message.content %}
        {%- set reasoning_content = '' %}
        {%- if message.reasoning_content is defined and message.reasoning_content is not none %}
            {%- set reasoning_content = message.reasoning_content %}
        {%- else %}
            {%- if '</think>' in message.content %}
                {%- set content = message.content.split('</think>')[-1].lstrip('\n') %}
                {%- set reasoning_content = message.content.split('</think>')[0].rstrip('\n').split('<think>')[-1].lstrip('\n') %}
            {%- endif %}
        {%- endif %}
        {%- if loop.index0 > ns.last_query_index %}
            {%- if loop.last or (not loop.last and reasoning_content) %}
                {{- '<|im_start|>' + message.role + '\n<think>\n' + reasoning_content.strip('\n') + '\n</think>\n\n' + content.lstrip('\n') }}
            {%- else %}
                {{- '<|im_start|>' + message.role + '\n' + content }}
            {%- endif %}
        {%- else %}
            {{- '<|im_start|>' + message.role + '\n' + content }}
        {%- endif %}
        {%- if message.tool_calls %}
            {%- for tool_call in message.tool_calls %}
                {%- if (loop.first and content) or (not loop.first) %}
                    {{- '\n' }}
                {%- endif %}
                {%- if tool_call.function %}
                    {%- set tool_call = tool_call.function %}
                {%- endif %}
                {{- '<tool_call>\n{"name": "' }}
                {{- tool_call.name }}
                {{- '", "arguments": ' }}
                {%- if tool_call.arguments is string %}
                    {{- tool_call.arguments }}
                {%- else %}
                    {{- tool_call.arguments | tojson }}
                {%- endif %}
                {{- '}\n</tool_call>' }}
            {%- endfor %}
        {%- endif %}
        {{- '<|im_end|>\n' }}
    {%- elif message.role == "tool" %}
        {%- if loop.first or (messages[loop.index0 - 1].role != "tool") %}
            {{- '<|im_start|>user' }}
        {%- endif %}
        {{- '\n<tool_response>\n' }}
        {{- message.content }}
        {{- '\n</tool_response>' }}
        {%- if loop.last or (messages[loop.index0 + 1].role != "tool") %}
            {{- '<|im_end|>\n' }}
        {%- endif %}
    {%- endif %}
{%- endfor %}
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
    {%- if enable_thinking is defined and enable_thinking is false %}
        {{- '<think>\n\n</think>\n\n' }}
    {%- endif %}
{%- endif %}

*/

/// Qwen 3 chat template (listed above in this file) with support for tools
/// and reasoning.
/// <https://huggingface.co/Qwen/Qwen3-8B-GGUF?chat_template=default>
final class Qwen3PromptFormatter extends ChatMlPromptFormatter {
  const Qwen3PromptFormatter();

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
      }
      buffer.write(
        '# Tools\n\nYou may call one or more functions to assist with the '
        'user query.\n\nYou are provided with function signatures within '
        '<tools></tools> XML tags:\n<tools>',
      );
      for (final tool in tools) {
        buffer
          ..write('\n')
          ..write(
            jsonEncode(ChatMlPromptFormatter.functionToolDeclaration(tool)),
          );
      }
      buffer.write(
        '\n</tools>\n\nFor each function call, return a json object with '
        'function name and arguments within <tool_call></tool_call> XML tags:'
        '\n<tool_call>\n{"name": <function-name>, "arguments": '
        '<args-json-object>}\n</tool_call><|im_end|>\n',
      );
    } else if (messages.isNotEmpty && messages.first.isSystemLike) {
      buffer
        ..write('<|im_start|>system\n')
        ..write(messages.first.content)
        ..write('<|im_end|>\n');
    }
  }

  @override
  void writeAssistantMessage(
    StringBuffer buffer,
    PromptAssistantMessage message,
    int index,
    List<PromptMessage> messages,
  ) {
    final segments = ChatMlPromptFormatter.splitReasoning(message);
    final content = segments.content;
    final reasoningContent = segments.reasoning;
    final lastQueryIndex = ChatMlPromptFormatter.findLastQueryIndex(
      messages,
      isToolResponseContent: _isToolResponseContent,
    );

    if (index > lastQueryIndex &&
        (index == messages.length - 1 || reasoningContent.isNotEmpty)) {
      buffer
        ..write('<|im_start|>assistant\n')
        ..write('<think>\n')
        ..write(reasoningContent.stripEdgeNewlines())
        ..write('\n</think>\n\n')
        ..write(content.stripLeadingNewlines());
    } else {
      buffer
        ..write('<|im_start|>assistant\n')
        ..write(content);
    }

    for (
      var callIndex = 0;
      callIndex < message.toolCalls.length;
      callIndex += 1
    ) {
      final toolCall = message.toolCalls[callIndex];
      if ((callIndex == 0 && content.isNotEmpty) || callIndex > 0) {
        buffer.write('\n');
      }
      buffer
        ..write('<tool_call>\n{"name": "')
        ..write(toolCall.name)
        ..write('", "arguments": ')
        ..write(jsonEncode(toolCall.arguments))
        ..write('}\n</tool_call>');
    }
    buffer.write('<|im_end|>\n');
  }

  @override
  void writeGenerationPrologue(StringBuffer buffer, String reasoningMode) {
    if (reasoningMode == 'off') {
      buffer.write('<think>\n\n</think>\n\n');
    }
  }

  static bool _isToolResponseContent(String content) {
    return content.contains('<tool_response>') &&
        content.contains('</tool_response>');
  }

  @override
  List<String> get stopSequences => const <String>[
    '<|im_end|>',
    '<|im_start|>',
  ];

  @override
  bool get addBos => true;
}
