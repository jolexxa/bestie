import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

const _search = ToolDefinition(
  name: 'search',
  description: 'Searches things.',
  parameters: {},
  onProgress: 'Running',
  onSuccess: 'Ran',
  onError: 'Failed',
);

const _spawn = ToolDefinition(
  name: 'spawn',
  description: 'Fulfilled by a route.',
  parameters: {},
  onProgress: 'Spawning',
  onSuccess: 'Spawned',
  onError: 'Failed',
);

void main() {
  group('ToolDefinitions', () {
    test('offers every definition it was given, in order', () {
      final offered = ToolDefinitions([_search, _spawn]);

      expect(offered.definitions, [_search, _spawn]);
    });

    test('finds a definition by name', () {
      final offered = ToolDefinitions([_search, _spawn]);

      expect(offered.definitionFor('spawn'), _spawn);
    });

    test('has nothing to say about a name it was not given', () {
      final offered = ToolDefinitions([_search]);

      expect(offered.definitionFor('spawn'), isNull);
    });

    test('offers nothing by default', () {
      expect(ToolDefinitions().definitions, isEmpty);
      expect(ToolDefinitions().definitionFor('search'), isNull);
    });

    test('cannot be added to after the fact', () {
      final offered = ToolDefinitions([_search]);

      expect(() => offered.definitions.add(_spawn), throwsUnsupportedError);
    });
  });
}
