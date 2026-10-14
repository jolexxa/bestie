import 'package:fireworks_client/fireworks_client.dart';
import 'package:test/test.dart';

void main() {
  group('FireworksSettings', () {
    test('compares by value', () {
      expect(
        const FireworksSettings(apiKey: 'fw'),
        const FireworksSettings(apiKey: 'fw'),
      );
      expect(
        const FireworksSettings(apiKey: 'fw').hashCode,
        const FireworksSettings(apiKey: 'fw').hashCode,
      );
      expect(
        const FireworksSettings(apiKey: 'fw'),
        isNot(FireworksSettings.unset),
      );
    });

    test('is set once it has a key', () {
      expect(FireworksSettings.unset.isSet, isFalse);
      expect(const FireworksSettings(apiKey: 'fw').isSet, isTrue);
    });

    test('never prints the key', () {
      expect(
        const FireworksSettings(apiKey: 'fw-secret').toString(),
        'FireworksSettings(apiKey: set)',
      );
      expect(
        FireworksSettings.unset.toString(),
        'FireworksSettings(apiKey: unset)',
      );
    });
  });
}
