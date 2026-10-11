import 'package:agent_runtime/agent_runtime.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  const provider = OpenRouterProvider(
    appTitle: 'bestie',
    httpReferer: 'https://example.test',
    appCategories: ['cli-agent'],
  );

  test('asks for an API key', () {
    expect(provider.id, 'openrouter');
    expect(provider.displayName, 'OpenRouter');
    expect(provider.credentialsKind, ProviderCredentialsKind.apiKey);
  });

  test('connects with the key and attributes requests to the app', () async {
    final connection = provider.connect(const ApiKeyCredentials('sk-or'));

    expect(connection, isA<OpenRouterConnection>());
    final load = connection.load(
      const ProviderModelLoadRequest(
        modelId: 'm',
        contextWindow: 8192,
        maxAgents: 1,
      ),
    );
    final model = (await load.result as ProviderModelLoaded).model;
    final served =
        (model.runtime as CompletionAgentRuntime).client
            as OpenAiCompletionClient;
    expect(served.apiKey, 'sk-or');
    expect(served.headers, const {
      'HTTP-Referer': 'https://example.test',
      'X-OpenRouter-Title': 'bestie',
      'X-OpenRouter-Categories': 'cli-agent',
    });
  });

  test('connects without a key, which cannot serve models', () async {
    final connection = provider.connect(const NoCredentials());

    final load = connection.load(
      const ProviderModelLoadRequest(
        modelId: 'm',
        contextWindow: 8192,
        maxAgents: 1,
      ),
    );
    expect(await load.result, isA<ProviderModelLoadFailed>());
  });

  test('sends no attribution when none is configured', () async {
    const bare = OpenRouterProvider();

    final load = bare
        .connect(const ApiKeyCredentials('sk'))
        .load(
          const ProviderModelLoadRequest(
            modelId: 'm',
            contextWindow: 8192,
            maxAgents: 1,
          ),
        );

    final model = (await load.result as ProviderModelLoaded).model;
    final served =
        (model.runtime as CompletionAgentRuntime).client
            as OpenAiCompletionClient;
    expect(served.headers, isEmpty);
  });

  test('refuses an endpoint', () {
    expect(
      () => provider.connect(
        EndpointCredentials(
          baseUrl: Uri.parse('http://localhost:8080/v1'),
          fallbackContextWindow: 8192,
        ),
      ),
      throwsArgumentError,
    );
  });
}
