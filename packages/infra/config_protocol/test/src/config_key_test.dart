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
}

ConfigKey<double> _doubleKey(String id) => ConfigKey<double>(
  id: id,
  path: const ['runtimeConfig', 'temperature'],
  codec: ConfigCodecs.doubles,
  defaultValue: () => 0.7,
);

ConfigScope _modelScope(String modelId) =>
    ConfigScope.path(['models', modelId]);

ConfigScope _providerScope(String providerId) =>
    ConfigScope.path(['providers', providerId]);

ConfigScope _profileScope(String profileId) =>
    ConfigScope.path(['profiles', profileId]);
