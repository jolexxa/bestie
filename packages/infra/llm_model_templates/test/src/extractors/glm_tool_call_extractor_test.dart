// Adjacent string concatenation models the GLM tool-call wire format —
// inserting whitespace between segments would corrupt the test inputs.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

void main() {
  group('GlmToolCallExtractor', () {
    late GlmToolCallExtractor extractor;

    setUp(() {
      extractor = GlmToolCallExtractor();
    });

    test('extracts single tool call with single string parameter', () {
      const text =
          '<tool_call>search'
          '<arg_key>query</arg_key>'
          '<arg_value>cows</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cows'});
      expect(calls[0].id, 'tool-call-1');
    });

    test('extracts single tool call with single string parameter '
        '(newline form)', () {
      const text =
          '<tool_call>search\n'
          '<arg_key>query</arg_key>\n'
          '<arg_value>cows</arg_value>\n'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cows'});
    });

    test('extracts tool call with multiple parameters in order', () {
      const text =
          '<tool_call>get_weather'
          '<arg_key>city</arg_key>'
          '<arg_value>San Francisco</arg_value>'
          '<arg_key>units</arg_key>'
          '<arg_value>celsius</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_weather');
      expect(calls[0].arguments.keys.toList(), ['city', 'units']);
      expect(calls[0].arguments, {
        'city': 'San Francisco',
        'units': 'celsius',
      });
    });

    test('decodes numeric arg_value as int', () {
      const text =
          '<tool_call>add'
          '<arg_key>n</arg_key>'
          '<arg_value>42</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['n'], 42);
      expect(calls[0].arguments['n'], isA<int>());
    });

    test('decodes numeric arg_value as double', () {
      const text =
          '<tool_call>scale'
          '<arg_key>factor</arg_key>'
          '<arg_value>3.14</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['factor'], 3.14);
      expect(calls[0].arguments['factor'], isA<double>());
    });

    test('decodes boolean arg_value', () {
      const text =
          '<tool_call>toggle'
          '<arg_key>enabled</arg_key>'
          '<arg_value>true</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['enabled'], true);
    });

    test('decodes JSON object arg_value to Map', () {
      const text =
          '<tool_call>configure'
          '<arg_key>opts</arg_key>'
          '<arg_value>{"k":1,"v":"x"}</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['opts'], {'k': 1, 'v': 'x'});
    });

    test('decodes JSON array arg_value to List', () {
      const text =
          '<tool_call>pick'
          '<arg_key>ids</arg_key>'
          '<arg_value>[1,2,3]</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['ids'], [1, 2, 3]);
    });

    test('treats unquoted text as raw string', () {
      const text =
          '<tool_call>echo'
          '<arg_key>msg</arg_key>'
          '<arg_value>not valid json</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['msg'], 'not valid json');
    });

    test('decodes JSON-quoted string to unquoted string', () {
      const text =
          '<tool_call>echo'
          '<arg_key>msg</arg_key>'
          '<arg_value>"hello"</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['msg'], 'hello');
    });

    test('preserves multi-line raw string values verbatim', () {
      const text =
          '<tool_call>write'
          '<arg_key>body</arg_key>'
          '<arg_value>line one\n'
          'line two\n'
          'line three</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['body'], 'line one\nline two\nline three');
    });

    test('parses arg_value containing literal < character', () {
      const text =
          '<tool_call>cmp'
          '<arg_key>val</arg_key>'
          '<arg_value><10</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['val'], '<10');
    });

    test('extracts multiple tool calls with sequential ids', () {
      const text =
          '<tool_call>search'
          '<arg_key>query</arg_key>'
          '<arg_value>cats</arg_value>'
          '</tool_call>'
          '<tool_call>search'
          '<arg_key>query</arg_key>'
          '<arg_value>dogs</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(2));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cats'});
      expect(calls[0].id, 'tool-call-1');
      expect(calls[1].name, 'search');
      expect(calls[1].arguments, {'query': 'dogs'});
      expect(calls[1].id, 'tool-call-2');
    });

    test('returns empty list for empty input', () {
      expect(extractor.extract(''), isEmpty);
    });

    test('returns empty list for text without tool_call tags', () {
      expect(extractor.extract('just some regular text'), isEmpty);
    });

    test('extracts tool call with no arguments', () {
      const text = '<tool_call>get_time</tool_call>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_time');
      expect(calls[0].arguments, isEmpty);
    });

    test('skips tool calls with empty function name', () {
      const text =
          '<tool_call>'
          '<arg_key>k</arg_key>'
          '<arg_value>v</arg_value>'
          '</tool_call>';

      expect(extractor.extract(text), isEmpty);
    });

    test('skips arg pairs with empty key', () {
      const text =
          '<tool_call>fn'
          '<arg_key></arg_key>'
          '<arg_value>v</arg_value>'
          '<arg_key>real</arg_key>'
          '<arg_value>kept</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments, {'real': 'kept'});
    });

    test('trims whitespace around arg_key content', () {
      const text =
          '<tool_call>fn'
          '<arg_key>  spaced  </arg_key>'
          '<arg_value>v</arg_value>'
          '</tool_call>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments, {'spaced': 'v'});
    });
  });
}
