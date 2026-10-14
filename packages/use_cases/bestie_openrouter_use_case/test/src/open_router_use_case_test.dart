import 'package:bestie_openrouter_use_case/bestie_openrouter_use_case.dart';
import 'package:config_repository/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openrouter_repository/openrouter_repository.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:test/test.dart';

final class _MockRepository extends Mock implements OpenRouterRepository {}

void main() {
  setUpAll(() => registerFallbackValue(OpenRouterSettings.unset));

  group('OpenRouterConfigKeys', () {
    final keys = OpenRouterConfigKeys.defaults();

    test('keeps the key where it was stored, masked', () {
      expect(keys.apiKey.id, 'provider.openrouter.api_key');
      expect(keys.apiKey.path, ['provider', 'openrouter', 'apiKey']);
      expect(keys.apiKey.defaultValue(), '');
      expect(keys.apiKey.field.label, 'OpenRouter API key');
      expect(keys.apiKey.field.secret, isTrue);
      expect(keys.settingsKeys, [keys.apiKey]);
    });
  });

  group('OpenRouterUseCase', () {
    late FakeConfigRepository config;
    late _MockRepository repository;

    OpenRouterUseCase useCaseWith([Map<String, Object?> values = const {}]) {
      config = FakeConfigRepository(values);
      repository = _MockRepository();
      when(() => repository.configure(any())).thenReturn(null);
      return OpenRouterUseCase(
        config: config,
        configKeys: OpenRouterConfigKeys.defaults(),
        repository: repository,
      );
    }

    List<OpenRouterSettings> configured() => verify(
      () => repository.configure(captureAny()),
    ).captured.cast<OpenRouterSettings>();

    test('contributes no commands', () {
      expect(useCaseWith().commands, isEmpty);
    });

    test('configures the repository from config at construction', () {
      final useCase = useCaseWith({'provider.openrouter.api_key': ' sk \n'});

      expect(useCase.settings, const OpenRouterSettings(apiKey: 'sk'));
      expect(configured(), [const OpenRouterSettings(apiKey: 'sk')]);
    });

    test('leaves the provider unset without a key', () {
      final useCase = useCaseWith({'provider.openrouter.api_key': '  '});

      expect(useCase.settings, OpenRouterSettings.unset);
    });

    test('reconfigures when its key changes', () async {
      useCaseWith();
      config['provider.openrouter.api_key'] = 'sk-new';
      await pumpEventQueue();

      expect(configured().last, const OpenRouterSettings(apiKey: 'sk-new'));
    });

    test('ignores other keys', () async {
      useCaseWith();
      config['app.theme'] = 'dark';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });

    test('stops following config once disposed', () async {
      await useCaseWith().dispose();
      config['provider.openrouter.api_key'] = 'sk-new';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });
  });
}
