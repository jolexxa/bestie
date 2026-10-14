import 'package:bestie_fireworks_use_case/bestie_fireworks_use_case.dart';
import 'package:config_repository/testing.dart';
import 'package:fireworks_repository/fireworks_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:test/test.dart';

final class _MockRepository extends Mock implements FireworksRepository {}

void main() {
  setUpAll(() => registerFallbackValue(FireworksSettings.unset));

  group('FireworksConfigKeys', () {
    final keys = FireworksConfigKeys.defaults();

    test('keeps the key where it was stored, masked', () {
      expect(keys.apiKey.id, 'provider.fireworks.api_key');
      expect(keys.apiKey.path, ['provider', 'fireworks', 'apiKey']);
      expect(keys.apiKey.defaultValue(), '');
      expect(keys.apiKey.field.label, 'Fireworks AI API key');
      expect(keys.apiKey.field.secret, isTrue);
      expect(keys.settingsKeys, [keys.apiKey]);
    });
  });

  group('FireworksUseCase', () {
    late FakeConfigRepository config;
    late _MockRepository repository;

    FireworksUseCase useCaseWith([Map<String, Object?> values = const {}]) {
      config = FakeConfigRepository(values);
      repository = _MockRepository();
      when(() => repository.configure(any())).thenReturn(null);
      return FireworksUseCase(
        config: config,
        configKeys: FireworksConfigKeys.defaults(),
        repository: repository,
      );
    }

    List<FireworksSettings> configured() => verify(
      () => repository.configure(captureAny()),
    ).captured.cast<FireworksSettings>();

    test('contributes no commands', () {
      expect(useCaseWith().commands, isEmpty);
    });

    test('configures the repository from config at construction', () {
      final useCase = useCaseWith({'provider.fireworks.api_key': ' sk \n'});

      expect(useCase.settings, const FireworksSettings(apiKey: 'sk'));
      expect(configured(), [const FireworksSettings(apiKey: 'sk')]);
    });

    test('leaves the provider unset without a key', () {
      final useCase = useCaseWith({'provider.fireworks.api_key': '  '});

      expect(useCase.settings, FireworksSettings.unset);
    });

    test('reconfigures when its key changes', () async {
      useCaseWith();
      config['provider.fireworks.api_key'] = 'sk-new';
      await pumpEventQueue();

      expect(configured().last, const FireworksSettings(apiKey: 'sk-new'));
    });

    test('ignores other keys', () async {
      useCaseWith();
      config['app.theme'] = 'dark';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });

    test('stops following config once disposed', () async {
      await useCaseWith().dispose();
      config['provider.fireworks.api_key'] = 'sk-new';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });
  });
}
