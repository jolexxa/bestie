import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

void main() {
  group('GemmaToolCallExtractor', () {
    late GemmaToolCallExtractor extractor;

    setUp(() {
      extractor = GemmaToolCallExtractor();
    });

    test('extracts single call with string arguments', () {
      const text = 'call:search{query:<|"|>cows<|"|>}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'search');
      expect(calls[0].arguments, {'query': 'cows'});
      expect(calls[0].id, 'tool-call-1');
    });

    test('extracts call with multiple string arguments', () {
      const text =
          'call:get_weather'
          '{city:<|"|>San Francisco<|"|>,units:<|"|>celsius<|"|>}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_weather');
      expect(calls[0].arguments, {
        'city': 'San Francisco',
        'units': 'celsius',
      });
    });

    test('extracts call with numeric arguments', () {
      const text = 'call:set_temp{value:42,scale:3.14}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {'value': 42, 'scale': 3.14});
    });

    test('extracts call with boolean arguments', () {
      const text = 'call:toggle{enabled:true,verbose:false}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {'enabled': true, 'verbose': false});
    });

    test('extracts call with mixed argument types', () {
      const text = 'call:complex{name:<|"|>test<|"|>,count:5,active:true}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {
        'name': 'test',
        'count': 5,
        'active': true,
      });
    });

    test('handles empty arguments', () {
      const text = 'call:get_time{}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'get_time');
      expect(calls[0].arguments, isEmpty);
    });

    test('handles commas inside string delimiters', () {
      const text = 'call:search{query:<|"|>cats, dogs, and birds<|"|>}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {'query': 'cats, dogs, and birds'});
    });

    test('handles colons inside string delimiters', () {
      const text = 'call:search{query:<|"|>time: 12:30<|"|>}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {'query': 'time: 12:30'});
    });

    test('handles nested objects', () {
      const text = 'call:config{options:{timeout:30,retries:3}}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {
        'options': {'timeout': 30, 'retries': 3},
      });
    });

    test('handles arrays', () {
      const text = 'call:multi{tags:[<|"|>a<|"|>,<|"|>b<|"|>,<|"|>c<|"|>]}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {
        'tags': ['a', 'b', 'c'],
      });
    });

    test('returns empty list for empty input', () {
      expect(extractor.extract(''), isEmpty);
    });

    test('returns empty list for malformed input', () {
      expect(extractor.extract('not a tool call'), isEmpty);
    });

    test('returns empty list for whitespace-only input', () {
      expect(extractor.extract('   \n  '), isEmpty);
    });

    test('handles whitespace around input', () {
      const text = '  call:search{query:<|"|>test<|"|>}  ';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].name, 'search');
    });

    test('increments call counter across extractions', () {
      extractor.extract('call:a{x:1}');
      final calls = extractor.extract('call:b{y:2}');

      expect(calls[0].id, 'tool-call-2');
    });

    test('handles null value', () {
      const text = 'call:clear{target:null}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments, {'target': null});
    });

    test('handles value with colon inside string delimiter', () {
      const text = 'call:fn{url:<|"|>http://example.com:8080<|"|>}';

      final calls = extractor.extract(text);

      expect(calls, hasLength(1));
      expect(calls[0].arguments['url'], 'http://example.com:8080');
    });
  });
}
