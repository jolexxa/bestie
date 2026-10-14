import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigScope', () {
    test('builds global and nested opaque paths', () {
      expect(ConfigScope.global.path, isEmpty);
      expect(_modelScope('qwen').path, ['models', 'qwen']);
      expect(_providerScope('openai').path, ['providers', 'openai']);
      expect(_profileScope('work').path, ['profiles', 'work']);
      expect(
        _profileScope('work').child(_modelScope('qwen')).path,
        ['profiles', 'work', 'models', 'qwen'],
      );
    });

    test('lists itself and then each parent', () {
      expect(_profileScope('work').child(_modelScope('qwen')).ancestry, [
        _profileScope('work').child(_modelScope('qwen')),
        _profileScope('work'),
        ConfigScope.global,
      ]);
      expect(ConfigScope.global.ancestry, [ConfigScope.global]);
    });

    test('uses structural equality for paths', () {
      expect(_modelScope('qwen'), _modelScope('qwen'));
      expect(
        _modelScope('qwen').hashCode,
        _modelScope('qwen').hashCode,
      );
      expect(_modelScope('qwen'), isNot(_modelScope('mistral')));
    });
  });

  group('ConfigAddress', () {
    test('combines scope and key paths', () {
      final temperature = _doubleKey('sampling.temperature');

      expect(temperature.at(_modelScope('qwen')).path, [
        'models',
        'qwen',
        'runtimeConfig',
        'temperature',
      ]);
    });

    test('exposes its field through the untyped key', () {
      final ConfigKeyBase key = _doubleKey('sampling.temperature');

      expect(key.field.label, 'Temperature');
      expect(key.field.formatValue(0.5), '0.5');
    });

    test('defaults, codes, and addresses untyped values', () {
      final ConfigKeyBase key = _doubleKey('sampling.temperature');

      expect(key.defaultObjectValue(), 0.7);
      expect(key.decode(1), 1.0);
      expect(key.decode('x'), isNull);
      expect(key.encode(0.5), 0.5);
      expect(key.atScope(_modelScope('qwen')).path, [
        'models',
        'qwen',
        'runtimeConfig',
        'temperature',
      ]);
    });

    test('uses key id and scope for equality', () {
      final a = _doubleKey('sampling.temperature').at(_modelScope('qwen'));
      final b = _doubleKey('sampling.temperature').at(_modelScope('qwen'));
      final c = _doubleKey(
        'sampling.temperature',
      ).at(_modelScope('mistral'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('ConfigResolution', () {
    final temperature = _doubleKey('sampling.temperature');
    final fallback = _doubleKey('sampling.default_temperature');
    final scope = _profileScope('work').child(_modelScope('qwen'));

    test('exact looks only at the address itself', () {
      expect(temperature.resolution.chainBase(temperature.at(scope)), [
        temperature.at(scope),
      ]);
    });

    test('scoped walks fallbacks at each ancestor scope', () {
      final scoped = ConfigKey<double>(
        id: 'sampling.temperature',
        path: const ['temperature'],
        codec: ConfigCodecs.doubles,
        defaultValue: () => 0.7,
        field: temperature.field,
        resolution: ConfigResolution.scoped(fallbackKeys: [fallback]),
      );

      expect(scoped.resolution.chainBase(scoped.at(scope)), [
        scoped.at(scope),
        fallback.at(scope),
        scoped.at(_profileScope('work')),
        fallback.at(_profileScope('work')),
        scoped.global,
        fallback.global,
      ]);
    });
  });

  group('ConfigEdit', () {
    test('sets or clears a typed value', () {
      expect(const ConfigEdit<int>.set(3), isA<SetConfigValue<int>>());
      expect(const SetConfigValue<int>(3).value, 3);
      expect(const ConfigEdit<int>.clear(), isA<ClearConfigValue<int>>());
    });

    test('sets or clears an untyped value', () {
      expect(const ConfigEditBase.set(3), isA<SetConfigValue<Object?>>());
      expect(const ConfigEditBase.clear(), isA<ClearConfigValue<Object?>>());
    });
  });
}

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

ConfigScope _providerScope(String providerId) =>
    ConfigScope.path(['providers', providerId]);

ConfigScope _profileScope(String profileId) =>
    ConfigScope.path(['profiles', profileId]);
