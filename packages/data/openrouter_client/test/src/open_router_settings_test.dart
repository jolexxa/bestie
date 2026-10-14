import 'package:openrouter_client/openrouter_client.dart';
import 'package:test/test.dart';

void main() {
  group('OpenRouterSettings', () {
    test('compares by value', () {
      expect(
        const OpenRouterSettings(apiKey: 'sk'),
        const OpenRouterSettings(apiKey: 'sk'),
      );
      expect(
        const OpenRouterSettings(apiKey: 'sk').hashCode,
        const OpenRouterSettings(apiKey: 'sk').hashCode,
      );
      expect(
        const OpenRouterSettings(apiKey: 'sk'),
        isNot(OpenRouterSettings.unset),
      );
    });

    test('is set once it has a key', () {
      expect(OpenRouterSettings.unset.isSet, isFalse);
      expect(const OpenRouterSettings(apiKey: 'sk').isSet, isTrue);
    });

    test('never prints the key', () {
      expect(
        const OpenRouterSettings(apiKey: 'sk-secret').toString(),
        'OpenRouterSettings(apiKey: set)',
      );
      expect(
        OpenRouterSettings.unset.toString(),
        'OpenRouterSettings(apiKey: unset)',
      );
    });
  });
}
