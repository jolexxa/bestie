import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigChange', () {
    test('tracks touched keys', () {
      final runtime = _intKey('runtime.primary_context_cap');
      final sampling = _doubleKey('sampling.temperature');
      final runtimeAddress = runtime.global;
      final samplingAddress = sampling.at(_modelScope('qwen'));

      final change = ConfigChange(<ConfigAddressBase>[
        runtimeAddress,
        samplingAddress,
      ]);

      expect(change.contains(runtimeAddress), isTrue);
      expect(change.contains(_intKey('runtime.other').global), isFalse);
      expect(change.containsKey(runtime), isTrue);
      expect(change.containsKey(_intKey('runtime.other')), isFalse);
      expect(change.keyIds, {
        'runtime.primary_context_cap',
        'sampling.temperature',
      });
    });

    test('ids constructor supports test-friendly synthetic events', () {
      const change = ConfigChange.ids(
        keyIds: {'app.theme'},
      );

      expect(change.keyIds, {'app.theme'});
    });
  });
}

ConfigKey<int> _intKey(String id) => ConfigKey<int>(
  id: id,
  path: const ['runtime', 'primaryContextCap'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 0,
  field: const NumericField(
    label: 'Cap',
    description: 'Tokens.',
    min: 0,
    max: 10,
    step: 1,
  ),
);

ConfigKey<double> _doubleKey(String id) => ConfigKey<double>(
  id: id,
  path: const ['runtimeConfig', 'temperature'],
  codec: ConfigCodecs.doubles,
  defaultValue: () => 0.7,
  field: const NumericField(
    label: 'Temperature',
    description: 'How random.',
    min: 0,
    max: 2,
    step: 0.1,
  ),
);

ConfigScope _modelScope(String modelId) =>
    ConfigScope.path(['models', modelId]);
