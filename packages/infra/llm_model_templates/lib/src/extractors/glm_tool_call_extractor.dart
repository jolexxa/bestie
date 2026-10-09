import 'dart:convert';

import 'package:llm_model_templates/src/stream/tool_call_extractor.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Extracts tool calls from GLM-4.5 / 4.6 / 4.7 output.
///
/// The canonical Jinja-trimmed render is contiguous; the model also
/// commonly emits a newline-separated form. Both are accepted:
/// ```text
/// <tool_call>fn<arg_key>k</arg_key><arg_value>v</arg_value>...</tool_call>
/// ```
///
/// `<arg_value>` content is parsed as JSON when it parses cleanly,
/// otherwise treated as a raw string — matching the reference impls in
/// llama.cpp PR #15904 and Z.AI's TIR guide.
final class GlmToolCallExtractor implements ToolCallExtractor {
  GlmToolCallExtractor();

  // Function name is everything between `<tool_call>` and the first `<`
  // (the start of either `<arg_key>` or `</tool_call>`). `[^<]*` is
  // greedy and captures the whole name region; the lazy `[\s\S]*?` then
  // captures the body up to the closing tag.
  static final _toolCallRegex = RegExp(
    r'<tool_call>([^<]*)([\s\S]*?)</tool_call>',
  );

  // Sibling pairs — NOT nested. Capture key, then value, in order.
  static final _argPairRegex = RegExp(
    r'<arg_key>\s*([\s\S]*?)\s*</arg_key>\s*'
    r'<arg_value>([\s\S]*?)</arg_value>',
  );

  int _callCounter = 0;

  @override
  List<ToolCall> extract(String text) {
    final matches = _toolCallRegex.allMatches(text);
    if (matches.isEmpty) return const [];

    final calls = <ToolCall>[];
    for (final match in matches) {
      final name = match.group(1)?.trim();
      if (name == null || name.isEmpty) continue;

      final body = match.group(2) ?? '';
      final arguments = <String, Object?>{};
      for (final pair in _argPairRegex.allMatches(body)) {
        final key = pair.group(1)?.trim();
        if (key == null || key.isEmpty) continue;
        arguments[key] = _decodeValue(pair.group(2) ?? '');
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

  // JSON-decode if it parses; otherwise return the raw (untrimmed) text.
  // Raw return preserves multi-line content verbatim — only the JSON
  // path trims, since JSON is whitespace-insensitive.
  static Object? _decodeValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    try {
      return jsonDecode(trimmed);
    } on Object catch (_) {
      return raw;
    }
  }
}
