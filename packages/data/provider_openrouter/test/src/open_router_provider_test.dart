import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

class MockOpenRouter extends Mock implements openrouter.OpenRouter {}

class MockCreditsResource extends Mock implements openrouter.CreditsResource {}

class MockApiKeysResource extends Mock implements openrouter.ApiKeysResource {}

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

openrouter.ApiKeyMetadata _keyMetadata({double? limit, double? remaining}) =>
    openrouter.ApiKeyMetadata(
      byokUsage: 0,
      byokUsageDaily: 0,
      byokUsageMonthly: 0,
      byokUsageWeekly: 0,
      includeByokInLimit: false,
      isFreeTier: true,
      isManagementKey: false,
      label: 'sk-or-v1-abc',
      limit: limit,
      limitRemaining: remaining,
      usage: 1.25,
      usageDaily: 0,
      usageMonthly: 0,
      usageWeekly: 0,
    );

void main() {
  late MockOpenRouter client;
  late MockCreditsResource creditsResource;
  late MockApiKeysResource apiKeysResource;
  late MockModelsResource modelsResource;
  late OpenRouterProvider provider;

  setUp(() {
    client = MockOpenRouter();
    creditsResource = MockCreditsResource();
    apiKeysResource = MockApiKeysResource();
    modelsResource = MockModelsResource();
    when(() => client.credits).thenReturn(creditsResource);
    when(() => client.apiKeys).thenReturn(apiKeysResource);
    when(() => client.models).thenReturn(modelsResource);
    provider = OpenRouterProvider(
      client: client,
      apiKey: 'sk-or-v1-abc',
      appTitle: 'bestie',
      httpReferer: 'https://chickensoft.games',
      appCategories: const ['cli-agent', 'general-chat'],
    );
  });

  test('identifies itself', () {
    expect(provider.id, 'openrouter');
    expect(provider.displayName, 'OpenRouter');
  });

  test('exposes the OpenAI-compatible endpoint with attribution', () {
    expect(provider.endpoints.keys, [InferenceProtocolId.openAiCompat]);
    expect(
      provider.endpoints[InferenceProtocolId.openAiCompat],
      InferenceEndpoint(
        baseUrl: Uri.parse('https://openrouter.ai/api/v1'),
        apiKey: 'sk-or-v1-abc',
        dialect: InferenceDialect.openRouter,
        headers: const {
          'HTTP-Referer': 'https://chickensoft.games',
          'X-OpenRouter-Title': 'bestie',
          'X-OpenRouter-Categories': 'cli-agent,general-chat',
        },
      ),
    );
  });

  test('omits attribution headers when not configured', () {
    final bare = OpenRouterProvider(client: client, apiKey: 'sk');

    expect(bare.endpoints[InferenceProtocolId.openAiCompat]!.headers, isEmpty);
  });

  group('credits', () {
    test('maps the balance', () async {
      when(creditsResource.getCredits).thenAnswer(
        (_) async => (totalCredits: 25.0, totalUsage: 4.5),
      );

      final result = await provider.credits();

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
      const cases = {
        401: InferenceFailureKind.auth,
        403: InferenceFailureKind.auth,
        429: InferenceFailureKind.rateLimit,
        500: InferenceFailureKind.server,
        402: InferenceFailureKind.badRequest,
      };
      for (final entry in cases.entries) {
        when(creditsResource.getCredits).thenThrow(
          openrouter.OpenRouterException(
            message: 'error ${entry.key}',
            code: entry.key,
            metadata: null,
          ),
        );

        final result = await provider.credits();

        expect(
          (result as CreditsFailed).failure,
          ProviderFailure(kind: entry.value, message: 'error ${entry.key}'),
        );
      }
    });

    test('maps other errors as network failures', () async {
      when(creditsResource.getCredits).thenThrow(Exception('offline'));

      final result = await provider.credits();

      expect(
        (result as CreditsFailed).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.network,
          message: 'Exception: offline',
        ),
      );
    });
  });

  group('keyInfo', () {
    test('maps the key metadata', () async {
      when(
        apiKeysResource.getCurrentKeyMetadata,
      ).thenAnswer((_) async => _keyMetadata(limit: 20, remaining: 18.75));

      final result = await provider.keyInfo();

      expect(
        (result as KeyInfoFetched).keyInfo,
        const ProviderKeyInfo(
          label: 'sk-or-v1-abc',
          usage: 1.25,
          isFreeTier: true,
          limit: 20,
          limitRemaining: 18.75,
        ),
      );
    });

    test('maps failures', () async {
      when(apiKeysResource.getCurrentKeyMetadata).thenThrow(
        openrouter.OpenRouterException(
          message: 'bad key',
          code: 401,
          metadata: null,
        ),
      );

      final result = await provider.keyInfo();

      expect(
        (result as KeyInfoFailed).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.auth,
          message: 'bad key',
        ),
      );
    });
  });

  group('models', () {
    test('maps the catalog', () async {
      when(modelsResource.list).thenAnswer(
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

      final result = await provider.models();

      expect((result as ProviderModelsListed).models, const [
        ProviderModel(
          id: 'a/tools',
          name: 'Model a/tools',
          contextLength: 32000,
          supportsTools: true,
          promptPricePerToken: 0.000001,
          completionPricePerToken: 0.000002,
        ),
        ProviderModel(
          id: 'b/advertised',
          name: 'Model b/advertised',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningToggle(),
        ),
        ProviderModel(
          id: 'c/toggle',
          name: 'Model c/toggle',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningToggle(enabledByDefault: true),
        ),
        ProviderModel(
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
        ProviderModel(
          id: 'e/optional',
          name: 'Model e/optional',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningEfforts(
            efforts: ['low', 'medium', 'high', 'xhigh'],
            canDisable: true,
          ),
        ),
        ProviderModel(
          id: 'f/plain',
          name: 'Model f/plain',
          contextLength: 32000,
          supportsTools: false,
        ),
        ProviderModel(
          id: 'g/fixed',
          name: 'Model g/fixed',
          contextLength: 32000,
          supportsTools: false,
          reasoning: ProviderReasoningFixed(),
        ),
      ]);
    });

    test('maps failures', () async {
      when(modelsResource.list).thenThrow(
        openrouter.OpenRouterException(
          message: 'slow down',
          code: 429,
          metadata: null,
        ),
      );

      final result = await provider.models();

      expect(
        (result as ProviderModelsFailed).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.rateLimit,
          message: 'slow down',
        ),
      );
    });
  });
}
