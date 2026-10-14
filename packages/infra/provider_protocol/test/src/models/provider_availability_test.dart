import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderAvailability', () {
    test('compares by value', () {
      const missing = ProviderNotSetUp(ProviderAuthFailed('no key'));

      expect(const ProviderReady(), const ProviderReady());
      expect(const ProviderReady().hashCode, const ProviderReady().hashCode);
      expect(missing, const ProviderNotSetUp(ProviderAuthFailed('no key')));
      expect(
        missing.hashCode,
        const ProviderNotSetUp(ProviderAuthFailed('no key')).hashCode,
      );
      expect(missing, isNot(const ProviderNotSetUp(ProviderRejected('url'))));
      expect(const ProviderReady(), isNot(missing));
    });

    test('describes itself', () {
      expect(const ProviderReady().toString(), 'ProviderReady()');
      expect(
        const ProviderNotSetUp(ProviderAuthFailed('no key')).toString(),
        'ProviderNotSetUp(${const ProviderAuthFailed('no key')})',
      );
    });
  });
}
