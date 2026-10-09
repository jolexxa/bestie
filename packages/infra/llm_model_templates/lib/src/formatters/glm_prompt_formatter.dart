import 'dart:convert';

import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:llm_model_templates/src/formatters/prompt_message_formatting.dart';
import 'package:llm_model_templates/src/formatters/prompt_tool.dart';

/*

[gMASK]<sop>
{%- if tools -%}
<|system|>
# Tools

You may call one or more functions to assist with the user query.

You are provided with function signatures within <tools></tools> XML tags:
<tools>
{% for tool in tools %}
{{ tool | tojson(ensure_ascii=False) }}
{% endfor %}
</tools>

For each function call, output the function name and arguments within the following XML format:
<tool_call>{function-name}<arg_key>{arg-key-1}</arg_key><arg_value>{arg-value-1}</arg_value><arg_key>{arg-key-2}</arg_key><arg_value>{arg-value-2}</arg_value>...</tool_call>{%- endif -%}
{%- macro visible_text(content) -%}
    {%- if content is string -%}
        {{- content }}
    {%- elif content is iterable and content is not mapping -%}
        {%- for item in content -%}
            {%- if item is mapping and item.type == 'text' -%}
                {{- item.text }}
            {%- elif item is string -%}
                {{- item }}
            {%- endif -%}
        {%- endfor -%}
    {%- else -%}
        {{- content }}
    {%- endif -%}
{%- endmacro -%}
{%- set ns = namespace(last_user_index=-1) %}
{%- for m in messages %}
    {%- if m.role == 'user' %}
        {% set ns.last_user_index = loop.index0 -%}
    {%- endif %}
{%- endfor %}
{% for m in messages %}
{%- if m.role == 'user' -%}<|user|>{{ visible_text(m.content) }}
{%- elif m.role == 'assistant' -%}
<|assistant|>
{%- set reasoning_content = '' %}
{%- set content = visible_text(m.content) %}
{%- if m.reasoning_content is string %}
    {%- set reasoning_content = m.reasoning_content %}
{%- else %}
    {%- if '</think>' in content %}
        {%- set reasoning_content = content.split('</think>')[0].rstrip('\n').split('<think>')[-1].lstrip('\n') %}
        {%- set content = content.split('</think>')[-1].lstrip('\n') %}
    {%- endif %}
{%- endif %}
{%- if ((clear_thinking is defined and not clear_thinking) or loop.index0 > ns.last_user_index) and reasoning_content -%}
{{ '<think>' + reasoning_content.strip() +  '</think>'}}
{%- else -%}
{{ '</think>' }}
{%- endif -%}
{%- if content.strip() -%}
{{ content.strip() }}
{%- endif -%}
{% if m.tool_calls %}
{% for tc in m.tool_calls %}
{%- if tc.function %}
    {%- set tc = tc.function %}
{%- endif %}
{{- '<tool_call>' + tc.name -}}
{% set _args = tc.arguments %}{% for k, v in _args.items() %}<arg_key>{{ k }}</arg_key><arg_value>{{ v | tojson(ensure_ascii=False) if v is not string else v }}</arg_value>{% endfor %}</tool_call>{% endfor %}
{% endif %}
{%- elif m.role == 'tool' -%}
{%- if m.content is string -%}
{%- if loop.first or (messages[loop.index0 - 1].role != "tool") %}
    {{- '<|observation|>' }}
{%- endif %}
{{- '<tool_response>' }}
{{- m.content }}
{{- '</tool_response>' }}
{%- else -%}
<|observation|>{% for tr in m.content %}
<tool_response>{{ tr.output if tr.output is defined else tr }}</tool_response>{% endfor -%}
{% endif -%}
{%- elif m.role == 'system' -%}
<|system|>{{ visible_text(m.content) }}
{%- endif -%}
{%- endfor -%}
{%- if add_generation_prompt -%}
    <|assistant|>{{- '</think>' if (enable_thinking is defined and not enable_thinking) else '<think>' -}}
{%- endif -%}

*/

/// GLM-4 / GLM-4.5 / GLM-4.6 / GLM-4.7 chat template (listed above) with
/// support for tools and reasoning.
final class GlmPromptFormatter extends PromptFormatter {
  const GlmPromptFormatter();

  @override
  String format({
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required String reasoningMode,
    String? assistantPrefill,
  }) {
    final buffer = StringBuffer()..write('[gMASK]<sop>');

    if (tools.isNotEmpty) {
      _writeToolsSystemBlock(buffer, tools);
    }

    final lastUserIndex = _findLastUserIndex(messages);

    for (var i = 0; i < messages.length; i += 1) {
      final message = messages[i];
      switch (message) {
        case PromptUserMessage():
          buffer
            ..write('<|user|>')
            ..write(message.content);
        case PromptSystemMessage() || PromptDeveloperMessage():
          buffer
            ..write('<|system|>')
            ..write(message.content);
        case PromptAssistantMessage():
          _writeAssistantMessage(buffer, message, i, lastUserIndex);
        case PromptToolMessage():
          _writeToolMessage(buffer, message, i, messages);
      }
    }

    buffer.write('<|assistant|>');
    if (reasoningMode == 'off') {
      buffer.write('</think>');
    } else {
      buffer.write('<think>');
    }
    buffer.write(assistantPrefill ?? '');
    return buffer.toString();
  }

  @override
  bool prefillsReasoning(String reasoningMode) => reasoningMode != 'off';

  static void _writeToolsSystemBlock(
    StringBuffer buffer,
    List<PromptTool> tools,
  ) {
    buffer.write(
      '<|system|>\n'
      '# Tools\n\n'
      'You may call one or more functions to assist with the user query.\n\n'
      'You are provided with function signatures within <tools></tools> XML tags:\n'
      '<tools>\n',
    );
    for (final tool in tools) {
      buffer
        ..write(jsonEncode(_toolDeclaration(tool)))
        ..write('\n');
    }
    buffer.write(
      '</tools>\n\n'
      'For each function call, output the function name and arguments within the following XML format:\n'
      '<tool_call>{function-name}<arg_key>{arg-key-1}</arg_key>'
      '<arg_value>{arg-value-1}</arg_value>'
      '<arg_key>{arg-key-2}</arg_key>'
      '<arg_value>{arg-value-2}</arg_value>...</tool_call>',
    );
  }

  static int _findLastUserIndex(List<PromptMessage> messages) {
    var lastUserIndex = -1;
    for (var i = 0; i < messages.length; i += 1) {
      if (messages[i] is PromptUserMessage) {
        lastUserIndex = i;
      }
    }
    return lastUserIndex;
  }

  static void _writeAssistantMessage(
    StringBuffer buffer,
    PromptAssistantMessage message,
    int i,
    int lastUserIndex,
  ) {
    var content = message.content;
    var reasoningContent = '';
    final raw = message.reasoning;
    if (raw != null) {
      reasoningContent = raw;
    } else if (content.contains('</think>')) {
      final parts = content.split('</think>');
      // reasoning_content = before.rstrip('\n').split('<think>')[-1].lstrip('\n')
      final beforeThink = parts.first.replaceFirst(RegExp(r'\n+$'), '');
      reasoningContent = beforeThink
          .split('<think>')
          .last
          .replaceFirst(RegExp(r'^\n+'), '');
      // content = after.lstrip('\n')
      content = parts.last.replaceFirst(RegExp(r'^\n+'), '');
    }

    buffer.write('<|assistant|>');

    final preserveReasoning =
        i > lastUserIndex && reasoningContent.trim().isNotEmpty;
    if (preserveReasoning) {
      buffer
        ..write('<think>')
        ..write(reasoningContent.trim())
        ..write('</think>');
    } else {
      buffer.write('</think>');
    }

    final stripped = content.trim();
    if (stripped.isNotEmpty) {
      buffer.write(stripped);
    }

    for (final toolCall in message.toolCalls) {
      buffer
        ..write('<tool_call>')
        ..write(toolCall.name);
      for (final entry in toolCall.arguments.entries) {
        buffer
          ..write('<arg_key>')
          ..write(entry.key)
          ..write('</arg_key>')
          ..write('<arg_value>')
          ..write(_argValue(entry.value))
          ..write('</arg_value>');
      }
      buffer.write('</tool_call>');
    }
  }

  static void _writeToolMessage(
    StringBuffer buffer,
    PromptToolMessage message,
    int i,
    List<PromptMessage> messages,
  ) {
    final previousIsTool = i > 0 && messages[i - 1] is PromptToolMessage;
    if (!previousIsTool) {
      buffer.write('<|observation|>');
    }
    buffer
      ..write('<tool_response>')
      ..write(message.content)
      ..write('</tool_response>');
  }

  /// Renders a tool-call argument value the way the Jinja template does:
  /// strings are emitted verbatim, everything else is JSON-encoded.
  static String _argValue(Object? value) {
    if (value is String) return value;
    return jsonEncode(value);
  }

  @override
  List<String> get stopSequences => const <String>[
    '<|user|>',
    '<|observation|>',
    '<|system|>',
  ];

  /// GLM templates emit `[gMASK]<sop>` inline as part of the rendered prompt,
  /// so we don't ask the tokenizer to add a BOS on top — that would double up.
  @override
  bool get addBos => false;

  static Map<String, Object?> _toolDeclaration(PromptTool tool) {
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
