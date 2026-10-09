import 'package:llm_model_templates/src/stream/tool_call_extractor.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Extracts tool calls from Gemma 4's structured format.
///
/// Handles the format:
/// ```text
/// call:function_name{key:<|"|>value<|"|>,key2:42}
/// ```
///
/// String values are delimited by `<|"|>`. Nested objects use `{...}`,
/// arrays use `[...]`, booleans are bare `true`/`false`, and numbers
/// are bare digits.
final class GemmaToolCallExtractor implements ToolCallExtractor {
  GemmaToolCallExtractor();

  static final _callPattern = RegExp(r'call:(\w+)\{([\s\S]*)\}$');
  static const _stringDelimiter = '<|"|>';
  static const _delimiterLength = 5; // '<|"|>'.length

  int _callCounter = 0;

  @override
  List<ToolCall> extract(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final match = _callPattern.firstMatch(trimmed);
    if (match == null) return const [];

    final name = match.group(1)!;
    final paramsBlock = match.group(2)!;
    final arguments = paramsBlock.isEmpty
        ? <String, Object?>{}
        : _parseMap(paramsBlock);

    return [
      ToolCallDefault(
        id: 'tool-call-${++_callCounter}',
        name: name,
        arguments: arguments,
      ),
    ];
  }

  /// Parses a comma-separated list of `key:value` pairs into a map.
  static Map<String, Object?> _parseMap(String block) {
    final pairs = _splitAtTopLevel(block, ',');
    final map = <String, Object?>{};

    for (final pair in pairs) {
      final trimmed = pair.trim();
      if (trimmed.isEmpty) continue;

      // Keys are bare identifiers, so the first colon separates the pair.
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      map[trimmed.substring(0, colonIndex)] = _parseValue(
        trimmed.substring(colonIndex + 1),
      );
    }

    return map;
  }

  /// Splits [text] on [separator] only at the top level — outside `<|"|>`
  /// strings and at brace/bracket depth 0.
  static List<String> _splitAtTopLevel(String text, String separator) {
    final parts = <String>[];
    var start = 0;
    var depth = 0;
    var inString = false;

    for (var i = 0; i < text.length; i++) {
      // Check for string delimiter start/end.
      if (i + _delimiterLength <= text.length &&
          text.substring(i, i + _delimiterLength) == _stringDelimiter) {
        inString = !inString;
        i += _delimiterLength - 1; // skip past delimiter
        continue;
      }

      if (inString) continue;

      final character = text[i];
      if (character == '{' || character == '[') {
        depth++;
      } else if (character == '}' || character == ']') {
        depth--;
      } else if (depth == 0 && text.startsWith(separator, i)) {
        parts.add(text.substring(start, i));
        start = i + separator.length;
        i += separator.length - 1;
      }
    }

    if (start < text.length) {
      parts.add(text.substring(start));
    }

    return parts;
  }

  /// Parses a single value from Gemma's structured format.
  static Object? _parseValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // String: <|"|>...<|"|>
    if (value.startsWith(_stringDelimiter) &&
        value.endsWith(_stringDelimiter) &&
        value.length >= _delimiterLength * 2) {
      return value.substring(
        _delimiterLength,
        value.length - _delimiterLength,
      );
    }

    // Nested object: {...}
    if (value.startsWith('{') && value.endsWith('}')) {
      final inner = value.substring(1, value.length - 1);
      return _parseMap(inner);
    }

    // Array: [...]
    if (value.startsWith('[') && value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      if (inner.trim().isEmpty) return <Object?>[];
      final items = _splitAtTopLevel(inner, ',');
      return items.map(_parseValue).toList();
    }

    // Boolean
    if (value == 'true') return true;
    if (value == 'false') return false;

    // Null
    if (value == 'null') return null;

    // Number
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(value);
    if (asDouble != null) return asDouble;

    // Fallback: treat as bare string.
    return value;
  }
}
