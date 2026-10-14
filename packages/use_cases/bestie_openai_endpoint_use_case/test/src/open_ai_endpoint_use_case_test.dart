import 'package:bestie_openai_endpoint_use_case/bestie_openai_endpoint_use_case.dart';
import 'package:config_repository/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_endpoint_client/openai_endpoint_client.dart';
import 'package:openai_endpoint_repository/openai_endpoint_repository.dart';
import 'package:test/test.dart';

final class _MockRepository extends Mock implements OpenAiEndpointRepository {}

void main() {
  setUpAll(() => registerFallbackValue(OpenAiEndpointSettings.unset));

  group('OpenAiEndpointConfigKeys', () {
    final keys = OpenAiEndpointConfigKeys.defaults();

    test('keeps every setting where it was stored', () {
      expect(keys.baseUrl.id, 'provider.custom.base_url');
      expect(keys.baseUrl.path, ['provider', 'custom', 'baseUrl']);
      expect(keys.apiKey.id, 'provider.custom.api_key');
      expect(keys.apiKey.path, ['provider', 'custom', 'apiKey']);
      expect(keys.contextWindow.id, 'provider.custom.context_window');
      expect(keys.contextWindow.path, ['provider', 'custom', 'contextWindow']);
      expect(
        keys.contextWindow.defaultValue(),
        OpenAiEndpointSettings.defaultContextWindow,
      );
      expect(keys.settingsKeys, [
        keys.baseUrl,
        keys.apiKey,
        keys.contextWindow,
      ]);
    });

    test('words every field after the endpoint, masking only the key', () {
      expect(keys.baseUrl.field.label, 'Custom endpoint URL');
      expect(keys.apiKey.field.label, 'Custom endpoint API key');
      expect(
        keys.apiKey.field.description,
        'Bearer token for the endpoint, if it wants one.',
      );
      expect(keys.contextWindow.field.label, 'Custom endpoint context window');
      expect(keys.apiKey.field.secret, isTrue);
      expect(keys.baseUrl.field.secret, isFalse);
      expect(keys.contextWindow.field.secret, isFalse);
    });
  });

  group('OpenAiEndpointUseCase', () {
    late FakeConfigRepository config;
    late _MockRepository repository;

    OpenAiEndpointUseCase useCaseWith([
      Map<String, Object?> values = const {},
    ]) {
      config = FakeConfigRepository(values);
      repository = _MockRepository();
      when(() => repository.configure(any())).thenReturn(null);
      return OpenAiEndpointUseCase(
        config: config,
        configKeys: OpenAiEndpointConfigKeys.defaults(),
        repository: repository,
      );
    }

    List<OpenAiEndpointSettings> configured() => verify(
      () => repository.configure(captureAny()),
    ).captured.cast<OpenAiEndpointSettings>();

    test('contributes no commands', () {
      expect(useCaseWith().commands, isEmpty);
    });

    test('configures the repository from config at construction', () {
      final useCase = useCaseWith({
        'provider.custom.base_url': ' http://localhost:8080/v1 ',
        'provider.custom.api_key': ' tok ',
        'provider.custom.context_window': 8192,
      });

      final settings = OpenAiEndpointSettings(
        baseUrl: Uri.parse('http://localhost:8080/v1'),
        apiKey: 'tok',
        contextWindow: 8192,
      );
      expect(useCase.settings, settings);
      expect(configured(), [settings]);
    });

    test('reaches an endpoint without a key when it wants none', () {
      final useCase = useCaseWith({
        'provider.custom.base_url': 'http://localhost:8080/v1',
      });

      expect(useCase.settings.apiKey, isNull);
      expect(
        useCase.settings.contextWindow,
        OpenAiEndpointSettings.defaultContextWindow,
      );
    });

    test('leaves the endpoint unset without an absolute URL', () {
      expect(useCaseWith().settings.isSet, isFalse);
      expect(
        useCaseWith({'provider.custom.base_url': 'garbage'}).settings.isSet,
        isFalse,
      );
      expect(
        useCaseWith({'provider.custom.base_url': '/v1'}).settings.isSet,
        isFalse,
      );
    });

    test('reconfigures when one of its keys changes', () async {
      useCaseWith();
      config['provider.custom.context_window'] = 4096;
      await pumpEventQueue();

      expect(configured().last.contextWindow, 4096);
    });

    test('ignores other keys', () async {
      useCaseWith();
      config['app.theme'] = 'dark';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });

    test('stops following config once disposed', () async {
      await useCaseWith().dispose();
      config['provider.custom.base_url'] = 'http://localhost:8080/v1';
      await pumpEventQueue();

      expect(configured(), hasLength(1));
    });
  });
}
