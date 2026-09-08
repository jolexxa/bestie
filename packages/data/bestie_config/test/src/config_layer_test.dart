import 'package:bestie_config/bestie_config.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigLayer', () {
    test('reads nested paths from a copied tree', () {
      final source = {
        'provider': {
          'endpoints': {
            'custom': {'streamingEnabled': true},
          },
        },
      };

      final layer = ConfigLayer(source);
      (source['provider']! as Map<String, Object?>).clear();

      expect(
        layer.read([
          'provider',
          'endpoints',
          'custom',
          'streamingEnabled',
        ]),
        isTrue,
      );
    });

    test('writes nested values and creates parents', () {
      final layer = ConfigLayer()
        ..write(['models', 'qwen', 'runtimeConfig', 'temperature'], 0.8);

      expect(layer.toMap(), {
        'models': {
          'qwen': {
            'runtimeConfig': {'temperature': 0.8},
          },
        },
      });
    });

    test('null write deletes and prunes empty parents', () {
      final layer = ConfigLayer()
        ..write(['models', 'qwen', 'runtimeConfig', 'temperature'], 0.8)
        ..write(['models', 'qwen', 'runtimeConfig', 'temperature'], null);

      expect(layer.isEmpty, isTrue);
      expect(layer.toMap(), isEmpty);
    });

    test('null fields in maps are treated as absent layer values', () {
      final layer = ConfigLayer({
        'app': {'themeName': null, 'themeEffects': false},
      });

      expect(layer.read(['app', 'themeName']), isNull);
      expect(layer.toMap(), {
        'app': {'themeEffects': false},
      });
    });

    test('writing to an empty path is rejected', () {
      expect(
        () => ConfigLayer().write(const [], 'cow'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returned maps cannot mutate the layer', () {
      final layer = ConfigLayer({
        'app': {'themeName': 'cow'},
      });

      final app = layer.read(['app'])! as Map<String, Object?>;
      app['themeName'] = 'other';

      expect(layer.read(['app', 'themeName']), 'cow');
    });
  });
}
