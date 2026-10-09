import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

void main() {
  group('XmlToolCallExtractor', () {
    late XmlToolCallExtractor extractor;

    setUp(() {
      extractor = XmlToolCallExtractor();
    });

    test('extracts single function with single parameter', () {
      const text =
          '<function=search>\n'
          '<parameter=query>\n'
          'cows\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cows'});
      expect(calls[0].id, 'tool-call-1');
    });

    test('extracts single function with multiple parameters', () {
      const text =
          '<function=get_weather>\n'
          '<parameter=city>\n'
          'San Francisco\n'
          '</parameter>\n'
          '<parameter=units>\n'
          'celsius\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_weather');
      expect(calls[0].arguments, {
        'city': 'San Francisco',
        'units': 'celsius',
      });
    });

    test('extracts multiline parameter values', () {
      const text =
          '<function=write_file>\n'
          '<parameter=content>\n'
          'line one\n'
          'line two\n'
          'line three\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments['content'], 'line one\nline two\nline three');
    });

    test('extracts multiple function calls', () {
      const text =
          '<function=search>\n'
          '<parameter=query>\n'
          'cats\n'
          '</parameter>\n'
          '</function>\n'
          '<function=search>\n'
          '<parameter=query>\n'
          'dogs\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(2));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cats'});
      expect(calls[0].id, 'tool-call-1');
      expect(calls[1].name, 'search');
      expect(calls[1].arguments, {'query': 'dogs'});
      expect(calls[1].id, 'tool-call-2');
    });

    test('extracts function with no parameters', () {
      const text = '<function=get_time>\n</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_time');
      expect(calls[0].arguments, isEmpty);
    });

    test('returns empty list for empty input', () {
      expect(extractor.extract(''), isEmpty);
    });

    test('returns empty list for text without function tags', () {
      expect(extractor.extract('just some regular text'), isEmpty);
    });

    test('handles parameter values containing XML-like content', () {
      const text =
          '<function=render>\n'
          '<parameter=html>\n'
          '<div>hello</div>\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments['html'], '<div>hello</div>');
    });

    test('strips leading and trailing newlines from values', () {
      const text =
          '<function=echo>\n'
          '<parameter=msg>\n'
          'hello\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['msg'], 'hello');
    });

    test('strips trailing newline when value ends with extra newline', () {
      // Two newlines before </parameter>: regex eats one, leaving a
      // trailing \n in the captured group — exercises line 50.
      const text =
          '<function=echo>\n'
          '<parameter=msg>hello\n'
          '\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['msg'], 'hello');
    });

    test('handles parameter value without leading newline', () {
      const text =
          '<function=echo>\n'
          '<parameter=msg>hello\n'
          '</parameter>\n'
          '</function>';

      final calls = extractor.extract(text);

      expect(calls[0].arguments['msg'], 'hello');
    });
  });
}
