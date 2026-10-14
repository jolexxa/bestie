import 'package:agent_runtime/agent_runtime.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openrouter_client/openrouter_client.dart';
import 'package:openrouter_client/src/open_router_dialect.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

class MockOpenRouter extends Mock implements openrouter.OpenRouter {}

class MockCreditsResource extends Mock implements openrouter.CreditsResource {}

class MockModelsResource extends Mock implements openrouter.ModelsResource {}

openrouter.Model _model({
  required String id,
  List<String> supportedParameters = const [],
  String? promptPrice,
  String? completionPrice,
  Map<String, Object?>? reasoning,
}) => openrouter.Model.fromJson({
  'id': id,
  'name': 'Model $id',
  'canonical_slug': id,
  'created': 1700000000,
  'context_length': 32000,
  'pricing': {'prompt': ?promptPrice, 'completion': ?completionPrice},
  'supported_parameters': supportedParameters,
  'reasoning': ?reasoning,
});

void main() {
  late MockOpenRouter client;
  late MockCreditsResource creditsResource;
  late MockModelsResource modelsResource;
  late OpenRouterClient connection;

  Future<List<openrouter.Model>> textModels() =>
      modelsResource.list(outputModalities: {openrouter.Modality.text});

  setUp(() {
    client = MockOpenRouter();
    creditsResource = MockCreditsResource();
    modelsResource = MockModelsResource();
    when(() => client.credits).thenReturn(creditsResource);
    when(() => client.models).thenReturn(modelsResource);
    connection = OpenRouterClient(
      appTitle: 'bestie',
      sdkFactory: (_) => client,
    )..configure(const OpenRouterSettings(apiKey: 'sk-or-v1-abc'));
  });

  test('is named for the palette', () {
    expect(connection.id, 'openrouter');
    expect(connection.displayName, 'OpenRouter');
  });

  group('configure', () {
    const noKey = ProviderAuthFailed('No OpenRouter API key configured.');

    test('is not set up until it has a key', () {
      final bare = OpenRouterClient(sdkFactory: (_) => client);

      expect(bare.availability, const ProviderNotSetUp(noKey));

      bare.configure(const OpenRouterSettings(apiKey: 'sk'));

      expect(bare.availability, const ProviderReady());
    });

    test('reports each change, and only changes', () async {
      final bare = OpenRouterClient(sdkFactory: (_) => client);
      final reported = <ProviderAvailability>[];
      final listening = bare.reconfigured.listen(reported.add);

      bare
        ..configure(const OpenRouterSettings(apiKey: 'sk'))
        ..configure(const OpenRouterSettings(apiKey: 'sk'))
        ..configure(OpenRouterSettings.unset);
      await pumpEventQueue();

      expect(reported, const [
        ProviderReady(),
        ProviderNotSetUp(noKey),
      ]);
      await listening.cancel();
    });

    test('hands the key to the SDK it builds', () {
      final keys = <String>[];
      OpenRouterClient(
        sdkFactory: (apiKey) {
          keys.add(apiKey);
          return client;
        },
      ).configure(const OpenRouterSettings(apiKey: 'sk-or'));

      expect(keys, ['', 'sk-or']);
    });

    test('builds the real SDK when none is injected', () {
      expect(
        () => OpenRouterClient(
          appTitle: 'bestie',
        ).configure(const OpenRouterSettings(apiKey: 'sk')),
        returnsNormally,
      );
    });
  });

  const request = ProviderModelLoadRequest(
    modelId: 'openai/gpt-4o-mini',
    contextWindow: 128000,
    maxAgents: 3,
  );

  test('serves models from its OpenAI-compatible endpoint at once', () async {
    final load = connection.load(request);

    expect(await load.progress.toList(), isEmpty);
    final model = (await load.result as ProviderModelLoaded).model;
    expect(model, isA<HostedProviderModel>());
    expect(model.contextWindow, 128000);
    expect(model.maxAgents, 3);
    final runtime = model.runtime as CompletionAgentRuntime;
    expect(runtime.options.modelId, 'openai/gpt-4o-mini');
    expect(runtime.options.contextWindow, 128000);
    expect(runtime.options.maxAgents, 3);
    final served = runtime.client as OpenAiCompletionClient;
    expect(served.baseUrl, Uri.parse('https://openrouter.ai/api/v1'));
    expect(served.apiKey, 'sk-or-v1-abc');
    expect(served.headers, const {'X-OpenRouter-Title': 'bestie'});
    expect(served.dialect, isA<OpenRouterDialect>());
  });

  test('attributes requests to the app with everything it was given', () async {
    final attributed = OpenRouterClient(
      appTitle: 'bestie',
      httpReferer: 'https://example.test',
      appCategories: const ['cli-agent'],
      sdkFactory: (_) => client,
    )..configure(const OpenRouterSettings(apiKey: 'sk-or-v1-abc'));

    final model =
        (await attributed.load(request).result as ProviderModelLoaded).model;

    final served =
        (model.runtime as CompletionAgentRuntime).client
            as OpenAiCompletionClient;
    expect(served.headers, const {
      'HTTP-Referer': 'https://example.test',
      'X-OpenRouter-Title': 'bestie',
      'X-OpenRouter-Categories': 'cli-agent',
    });
  });

  group('without a key', () {
    const noKey = ProviderAuthFailed('No OpenRouter API key configured.');

    setUp(() {
      connection = OpenRouterClient(sdkFactory: (_) => client);
    });

    test('says a key is missing instead of asking for credits', () async {
      expect((await connection.credits() as CreditsFailed).failure, noKey);
      verifyNever(() => client.credits);
    });

    test('cannot serve models', () async {
      final load = connection.load(request);

      expect((await load.result as ProviderModelLoadFailed).failure, noKey);
    });

    test('still lists models', () async {
      when(textModels).thenAnswer((_) async => [_model(id: 'a/b')]);

      final result = await connection.models();

      expect((result as ProviderModelsListed).models.single.id, 'a/b');
    });
  });

  group('credits', () {
    test('maps the balance', () async {
      when(creditsResource.getCredits).thenAnswer(
        (_) async => (totalCredits: 25.0, totalUsage: 4.5),
      );

      final result = await connection.credits();

      expect(
        (result as CreditsFetched).credits,
        const ProviderCredits(
          spent: 4.5,
          remaining: 20.5,
          window: SpendWindow.lifetime,
        ),
      );
    });

    test('maps OpenRouter errors by code', () async {
      final cases = <int, ProviderFailure Function(String)>{
        401: ProviderAuthFailed.new,
        403: ProviderAuthFailed.new,
        429: ProviderRateLimited.new,
        500: ProviderServerFailed.new,
        402: ProviderRejected.new,
      };
      for (final entry in cases.entries) {
        when(creditsResource.getCredits).thenThrow(
          openrouter.OpenRouterException(
            message: 'error ${entry.key}',
            code: entry.key,
            metadata: null,
          ),
        );

        final result = await connection.credits();

        expect(
          (result as CreditsFailed).failure,
          entry.value('error ${entry.key}'),
        );
      }
    });

    test('maps other errors as network failures', () async {
      when(creditsResource.getCredits).thenThrow(Exception('offline'));

      final result = await connection.credits();

      expect(
        (result as CreditsFailed).failure,
        const ProviderUnreachable('Exception: offline'),
      );
    });
  });

  group('models', () {
    test('asks only for models that answer in text', () async {
      when(textModels).thenAnswer((_) async => [_model(id: 'a/chat')]);

      final result = await connection.models();

      expect(
        (result as ProviderModelsListed).models.map((model) => model.id),
        ['a/chat'],
      );
      verify(textModels).called(1);
      verifyNoMoreInteractions(modelsResource);
    });

    test('maps the catalog', () async {
      when(textModels).thenAnswer(
        (_) async => [
          _model(
            id: 'a/tools',
            supportedParameters: const ['tools', 'temperature'],
            promptPrice: '0.000001',
            completionPrice: '0.000002',
          ),
          _model(
            id: 'b/advertised',
            supportedParameters: const ['reasoning'],
          ),
          _model(
            id: 'c/toggle',
            reasoning: const {'mandatory': false, 'default_enabled': true},
          ),
          _model(
            id: 'd/mandatory',
            reasoning: const {
              'mandatory': true,
              'supported_efforts': ['high', 'medium', 'low'],
              'default_effort': 'medium',
            },
          ),
          _model(
            id: 'e/optional',
            reasoning: const {
              'mandatory': true,
              'supported_efforts': ['xhigh', 'high', 'medium', 'low', 'none'],
              'default_effort': 'none',
              'default_enabled': false,
            },
          ),
          _model(id: 'f/plain'),
          _model(id: 'g/fixed', reasoning: const {'mandatory': true}),
        ],
      );

      final result = await connection.models();

      expect((result as ProviderModelsListed).models, const [
        ProviderModelInfo(
          id: 'a/tools',
          name: 'Model a/tools',
          contextLength: 32000,
          supportsTools: true,
          promptPricePerToken: 0.000001,
          completionPricePerToken: 0.000002,
        ),
        ProviderModelInfo(
          id: 'b/advertised',
          name: 'Model b/advertised',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningToggle(),
        ),
        ProviderModelInfo(
          id: 'c/toggle',
          name: 'Model c/toggle',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningToggle(enabledByDefault: true),
        ),
        ProviderModelInfo(
          id: 'd/mandatory',
          name: 'Model d/mandatory',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningEfforts(
            efforts: ['low', 'medium', 'high'],
            canDisable: false,
            defaultEffort: 'medium',
          ),
        ),
        ProviderModelInfo(
          id: 'e/optional',
          name: 'Model e/optional',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningEfforts(
            efforts: ['low', 'medium', 'high', 'xhigh'],
            canDisable: true,
          ),
        ),
        ProviderModelInfo(
          id: 'f/plain',
          name: 'Model f/plain',
          contextLength: 32000,
          supportsTools: false,
        ),
        ProviderModelInfo(
          id: 'g/fixed',
          name: 'Model g/fixed',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningFixed(),
        ),
      ]);
    });

    test('maps failures', () async {
      when(textModels).thenThrow(
        openrouter.OpenRouterException(
          message: 'slow down',
          code: 429,
          metadata: null,
        ),
      );

      final result = await connection.models();

      expect(
        (result as ProviderModelsFailed).failure,
        const ProviderRateLimited('slow down'),
      );
    });
  });
}
