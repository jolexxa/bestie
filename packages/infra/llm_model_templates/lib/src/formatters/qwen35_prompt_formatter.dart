import 'dart:convert';

import 'package:llm_model_templates/src/formatters/chat_ml_prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/*

Text-path essentials of the Qwen 3.5 template (vision item handling elided —
prompt messages here are always plain text):

{%- if tools and tools is iterable and tools is not mapping %}
    {{- '<|im_start|>system\n' }}
    {{- "# Tools\n\nYou have access to the following functions:\n\n<tools>" }}
    {%- for tool in tools %}
        {{- "\n" }}
        {{- tool | tojson }}
    {%- endfor %}
    {{- "\n</tools>" }}
    {{- '\n\nIf you choose to call a function ONLY reply in the following format with NO suffix:\n\n<tool_call>\n<function=example_function_name>\n<parameter=example_parameter_1>\nvalue_1\n</parameter>\n<parameter=example_parameter_2>\nThis is the value for the second parameter\nthat can span\nmultiple lines\n</parameter>\n</function>\n</tool_call>\n\n<IMPORTANT>\nReminder:\n- Function calls MUST follow the specified format: an inner <function=...></function> block must be nested within <tool_call></tool_call> XML tags\n- Required parameters MUST be specified\n- You may provide optional reasoning for your function call in natural language BEFORE the function call, but NOT after\n- If there is no function call available, answer the question like normal with your current knowledge and do not tell the user about function calls\n</IMPORTANT>' }}
    {%- if messages[0].role == 'system' %}
        {%- set content = render_content(messages[0].content, false, true)|trim %}
        {%- if content %}
            {{- '\n\n' + content }}
        {%- endif %}
    {%- endif %}
    {{- '<|im_end|>\n' }}
{%- else %}
    {%- if messages[0].role == 'system' %}
        {%- set content = render_content(messages[0].content, false, true)|trim %}
        {{- '<|im_start|>system\n' + content + '<|im_end|>\n' }}
    {%- endif %}
{%- endif %}
{%- set ns = namespace(multi_step_tool=true, last_query_index=messages|length - 1) %}
{%- for message in messages[::-1] %}
    {%- set index = (messages|length - 1) - loop.index0 %}
    {%- if ns.multi_step_tool and message.role == "user" %}
        {%- set content = render_content(message.content, false)|trim %}
        {%- if not(content.startswith('<tool_response>') and content.endswith('</tool_response>')) %}
            {%- set ns.multi_step_tool = false %}
            {%- set ns.last_query_index = index %}
        {%- endif %}
    {%- endif %}
{%- endfor %}
{%- for message in messages %}
    {%- set content = render_content(message.content, true)|trim %}
    {%- if message.role == "user" %}
        {{- '<|im_start|>' + message.role + '\n' + content + '<|im_end|>' + '\n' }}
    {%- elif message.role == "assistant" %}
        {%- set reasoning_content = '' %}
        {%- if message.reasoning_content is string %}
            {%- set reasoning_content = message.reasoning_content %}
        {%- else %}
            {%- if '</think>' in content %}
                {%- set reasoning_content = content.split('</think>')[0].rstrip('\n').split('<think>')[-1].lstrip('\n') %}
                {%- set content = content.split('</think>')[-1].lstrip('\n') %}
            {%- endif %}
        {%- endif %}
        {%- set reasoning_content = reasoning_content|trim %}
        {%- if loop.index0 > ns.last_query_index %}
            {{- '<|im_start|>' + message.role + '\n<think>\n' + reasoning_content + '\n</think>\n\n' + content }}
        {%- else %}
            {{- '<|im_start|>' + message.role + '\n' + content }}
        {%- endif %}
        {%- if message.tool_calls and message.tool_calls is iterable and message.tool_calls is not mapping %}
            {%- for tool_call in message.tool_calls %}
                {%- if tool_call.function is defined %}
                    {%- set tool_call = tool_call.function %}
                {%- endif %}
                {%- if loop.first %}
                    {%- if content|trim %}
                        {{- '\n\n<tool_call>\n<function=' + tool_call.name + '>\n' }}
                    {%- else %}
                        {{- '<tool_call>\n<function=' + tool_call.name + '>\n' }}
                    {%- endif %}
                {%- else %}
                    {{- '\n<tool_call>\n<function=' + tool_call.name + '>\n' }}
                {%- endif %}
                {%- if tool_call.arguments is defined %}
                    {%- for args_name, args_value in tool_call.arguments|items %}
                        {{- '<parameter=' + args_name + '>\n' }}
                        {%- set args_value = args_value | tojson | safe if args_value is mapping or (args_value is sequence and args_value is not string) else args_value | string %}
                        {{- args_value }}
                        {{- '\n</parameter>\n' }}
                    {%- endfor %}
                {%- endif %}
                {{- '</function>\n</tool_call>' }}
            {%- endfor %}
        {%- endif %}
        {{- '<|im_end|>\n' }}
    {%- elif message.role == "tool" %}
        {%- if loop.previtem and loop.previtem.role != "tool" %}
            {{- '<|im_start|>user' }}
        {%- endif %}
        {{- '\n<tool_response>\n' }}
        {{- content }}
        {{- '\n</tool_response>' }}
        {%- if not loop.last and loop.nextitem.role != "tool" %}
            {{- '<|im_end|>\n' }}
        {%- elif loop.last %}
            {{- '<|im_end|>\n' }}
        {%- endif %}
    {%- endif %}
{%- endfor %}
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
    {%- if enable_thinking is defined and enable_thinking is false %}
        {{- '<think>\n\n</think>\n\n' }}
    {%- else %}
        {{- '<think>\n' }}
    {%- endif %}
{%- endif %}

*/

/// Qwen 3.5 chat template (listed above in this file): tools-first system
/// block, XML tool calls, and a generation prompt that always opens a
/// `<think>` block when reasoning is enabled.
final class Qwen35PromptFormatter extends ChatMlPromptFormatter {
  const Qwen35PromptFormatter();

  @override
  String renderContent(String content) => content.trim();

  @override
  void writeSystemBlock(
    StringBuffer buffer,
    List<PromptMessage> messages,
    List<PromptTool> tools,
  ) {
    final leadingSystem = messages.isNotEmpty && messages.first.isSystemLike
        ? messages.first.content.trim()
        : null;

    if (tools.isNotEmpty) {
      buffer.write(
        '<|im_start|>system\n'
        '# Tools\n\nYou have access to the following functions:\n\n<tools>',
      );
      for (final tool in tools) {
        buffer
          ..write('\n')
          ..write(
            jsonEncode(ChatMlPromptFormatter.functionToolDeclaration(tool)),
          );
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
        '</IMPORTANT>',
      );
      if (leadingSystem != null && leadingSystem.isNotEmpty) {
        buffer
          ..write('\n\n')
          ..write(leadingSystem);
      }
      buffer.write('<|im_end|>\n');
    } else if (leadingSystem != null) {
      buffer
        ..write('<|im_start|>system\n')
        ..write(leadingSystem)
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
    final trimmed = PromptAssistantMessage(
      content: message.content.trim(),
      reasoning: message.reasoning,
      toolCalls: message.toolCalls,
    );
    final segments = ChatMlPromptFormatter.splitReasoning(trimmed);
    final content = segments.content;
    final reasoningContent = segments.reasoning.trim();
    final lastQueryIndex = ChatMlPromptFormatter.findLastQueryIndex(
      messages,
      isToolResponseContent: _isToolResponseContent,
    );

    if (index > lastQueryIndex) {
      buffer
        ..write('<|im_start|>assistant\n')
        ..write('<think>\n')
        ..write(reasoningContent)
        ..write('\n</think>\n\n')
        ..write(content);
    } else {
      buffer
        ..write('<|im_start|>assistant\n')
        ..write(content);
    }

    ChatMlPromptFormatter.writeXmlToolCalls(
      buffer,
      message,
      content,
      firstSeparator: '\n\n',
    );
    buffer.write('<|im_end|>\n');
  }

  @override
  void writeGenerationPrologue(StringBuffer buffer, String reasoningMode) {
    if (reasoningMode == 'off') {
      buffer.write('<think>\n\n</think>\n\n');
    } else {
      buffer.write('<think>\n');
    }
  }

  @override
  bool prefillsReasoning(String reasoningMode) => reasoningMode != 'off';

  static bool _isToolResponseContent(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('<tool_response>') &&
        trimmed.endsWith('</tool_response>');
  }

  @override
  List<String> get stopSequences => const <String>[
    '<|im_end|>',
    '<|im_start|>',
  ];

  @override
  bool get addBos => true;
}
