import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('coerceArguments', () {
    const untyped = ToolDefinition(
      onProgress: 'Running',
      onSuccess: 'Ran',
      onError: 'Failed',
      name: 'search',
      description: 'Searches things.',
      parameters: {'type': 'object'},
    );

    const typed = ToolDefinition(
      onProgress: 'Running',
      onSuccess: 'Ran',
      onError: 'Failed',
      name: 'typed',
      description: 'Uses typed parameters.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
          'max_results': {'type': 'integer'},
          'threshold': {'type': 'number'},
          'strict': {'type': 'boolean'},
          'filters': {'type': 'array'},
          'options': {'type': 'object'},
          'limit': {
            'type': ['integer', 'null'],
          },
        },
      },
    );

    test('coerces string arguments to schema-declared types', () {
      expect(
        coerceArguments(typed, const {
          'query': '42',
          'max_results': '5',
          'threshold': '0.75',
          'strict': 'true',
          'filters': '["a","b"]',
          'options': '{"depth":2}',
          'limit': 'null',
        }),
        {
          'query': '42',
          'max_results': 5,
          'threshold': 0.75,
          'strict': true,
          'filters': ['a', 'b'],
          'options': {'depth': 2},
          'limit': null,
        },
      );
    });

    test('resolves a union type by trying each member in order', () {
      expect(
        coerceArguments(typed, const {'limit': '7'}),
        {'limit': 7},
      );
    });

    test('leaves typed, undeclared, and uncoercible arguments untouched', () {
      expect(
        coerceArguments(typed, const {
          'max_results': 5,
          'strict': 'maybe',
          'unknown': '7',
        }),
        {'max_results': 5, 'strict': 'maybe', 'unknown': '7'},
      );
    });

    test('leaves a value alone when its JSON does not match the type', () {
      expect(
        coerceArguments(typed, const {
          'filters': '{"not":"a list"}',
          'options': '["not a map"]',
        }),
        {'filters': '{"not":"a list"}', 'options': '["not a map"]'},
      );
    });

    test('leaves a value alone when its JSON is malformed', () {
      expect(
        coerceArguments(typed, const {'filters': '[oops'}),
        {'filters': '[oops'},
      );
    });

    test('coerces false as well as true', () {
      expect(
        coerceArguments(typed, const {'strict': 'false'}),
        {'strict': false},
      );
    });

    test('ignores a property whose spec is not a map', () {
      const oddly = ToolDefinition(
        onProgress: 'Running',
        onSuccess: 'Ran',
        onError: 'Failed',
        name: 'odd',
        description: 'Has a malformed property spec.',
        parameters: {
          'type': 'object',
          'properties': {'count': 'integer'},
        },
      );

      expect(coerceArguments(oddly, const {'count': '5'}), {'count': '5'});
    });

    test('tolerates a schema without properties', () {
      expect(
        coerceArguments(untyped, const {'query': '5'}),
        {'query': '5'},
      );
    });
  });
}
