import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

final _key = ConfigKey<int>(
  id: 'tools.concurrent',
  path: const ['tools', 'concurrent'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 16,
  field: const NumericField(
    label: 'Concurrent',
    description: 'How many.',
    min: 1,
    max: 64,
    step: 1,
  ),
);

void main() {
  group('Resolved', () {
    final own = _key.at(ConfigScope.path(const ['models', 'qwen']));

    test('is a default when nothing supplied the value', () {
      const resolved = Resolved<int>(value: 16, source: null);

      expect(resolved.isDefault, isTrue);
      expect(resolved.inheritedInto(own), isFalse);
    });

    test('is inherited when another address supplied the value', () {
      final resolved = Resolved<int>(value: 4, source: _key.global);

      expect(resolved.isDefault, isFalse);
      expect(resolved.inheritedInto(own), isTrue);
      expect(resolved.inheritedInto(_key.global), isFalse);
    });
  });
}
