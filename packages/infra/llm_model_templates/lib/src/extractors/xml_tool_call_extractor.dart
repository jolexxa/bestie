import 'package:llm_model_templates/src/stream/tool_call_extractor.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Extracts tool calls from XML-formatted text (Qwen3-Coder style).
///
/// Handles the format:
/// ```xml
/// <function=function_name>
/// <parameter=param_name>
/// value
/// </parameter>
/// </function>
/// ```
final class XmlToolCallExtractor implements ToolCallExtractor {
  XmlToolCallExtractor();

  static final _functionRegex = RegExp(
    r'<function=(.*?)>([\s\S]*?)</function>',
  );

  static final _parameterRegex = RegExp(
    r'<parameter=(.*?)>\n?([\s\S]*?)\n?</parameter>',
  );

  @override
  List<ToolCall> extract(String text) {
    final matches = _functionRegex.allMatches(text);
    if (matches.isEmpty) return const [];

    final calls = <ToolCall>[];

    for (final match in matches) {
      final name = match.group(1)?.trim();
      if (name == null || name.isEmpty) continue;

      final body = match.group(2) ?? '';
      final arguments = <String, Object?>{};

      for (final paramMatch in _parameterRegex.allMatches(body)) {
        final paramName = paramMatch.group(1)?.trim();
        if (paramName == null || paramName.isEmpty) continue;

        var value = paramMatch.group(2) ?? '';
        // Strip leading/trailing newlines per Jinja convention.
        if (value.startsWith('\n')) value = value.substring(1);
        if (value.endsWith('\n')) {
          value = value.substring(0, value.length - 1);
        }

        arguments[paramName] = value;
      }

      calls.add(
        ToolCallDefault(
          id: 'tool-call-${++_callCounter}',
          name: name,
          arguments: arguments,
        ),
      );
    }

    return calls;
  }

  int _callCounter = 0;
}
