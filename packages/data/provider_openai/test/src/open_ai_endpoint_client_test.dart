import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider_openai/provider_openai.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final Uri _url = Uri.parse('http://localhost:8080/v1');

const _fallbackContextWindow = 8192;

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = [];
  });

  OpenAiConnection connectionFor(
    http.Response Function(http.Request request) respond, {
    String? apiKey = 'local-key',
    Uri? baseUrl,
  }) => OpenAiConnection(
    baseUrl: baseUrl ?? _url,
    apiKey: apiKey,
    fallbackContextWindow: _fallbackContextWindow,
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
  );

  http.Response Function(http.Request) json(Object? body, {int status = 200}) =>
      (_) => http.Response(jsonEncode(body), status);

  test('has no credits', () async {
    final connection = connectionFor(json(const {'data': <Object?>[]}));

    expect(await connection.credits(), isA<CreditsUnsupported>());
  });

  test('serves the requested model from its own address at once', () async {
    final connection = connectionFor(json(const {'data': <Object?>[]}));

    final load = connection.load(
      const ProviderModelLoadRequest(
        modelId: 'llama-3.1-8b',
        contextWindow: 131072,
        maxAgents: 3,
      ),
    );

    expect(await load.progress.toList(), isEmpty);
    final model = (await load.result as ProviderModelLoaded).model;
    expect(model, isA<HostedProviderModel>());
    final runtime = model.runtime as CompletionAgentRuntime;
    expect(runtime.options.modelId, 'llama-3.1-8b');
    expect(runtime.options.contextWindow, 131072);
    expect(runtime.options.maxAgents, 3);
    final client = runtime.client as OpenAiCompletionClient;
    expect(client.baseUrl, _url);
    expect(client.apiKey, 'local-key');
    expect(client.dialect, isA<StandardOpenAiDialect>());
    expect(model.contextWindow, 131072);
    expect(model.maxAgents, 3);
    expect(requests, isEmpty);
  });

  test('holds nothing to close', () async {
    final connection = connectionFor(json(const {'data': <Object?>[]}));

    await expectLater(connection.close(), completes);
    expect(requests, isEmpty);
  });

  group('models', () {
    test(
      'lists ids with the context the server reports, else the fallback',
      () async {
        final connection = connectionFor(
          json(const {
            'data': [
              {'id': 'accounts/fireworks/models/kimi', 'object': 'model'},
              {
                'id': 'llama-3.1-8b',
                'meta': {'n_ctx_train': 131072, 'n_params': 8000000000},
              },
              {'id': 'gateway-model', 'context_length': 32768},
              {'id': 'odd-model', 'meta': 'nope', 'context_length': 'big'},
            ],
          }),
        );

        final result = await connection.models();

        expect((result as ProviderModelsListed).models, const [
          ProviderModelInfo(
            id: 'accounts/fireworks/models/kimi',
            name: 'accounts/fireworks/models/kimi',
            contextLength: _fallbackContextWindow,
            supportsTools: true,
          ),
          ProviderModelInfo(
            id: 'llama-3.1-8b',
            name: 'llama-3.1-8b',
            contextLength: 131072,
            supportsTools: true,
          ),
          ProviderModelInfo(
            id: 'gateway-model',
            name: 'gateway-model',
            contextLength: 32768,
            supportsTools: true,
          ),
          ProviderModelInfo(
            id: 'odd-model',
            name: 'odd-model',
            contextLength: _fallbackContextWindow,
            supportsTools: true,
          ),
        ]);
        final sent = requests.single;
        expect(
          sent.url,
          Uri.parse('http://localhost:8080/v1/models'),
        );
        expect(sent.headers['Authorization'], 'Bearer local-key');
      },
    );

    test(
      'joins the models path and sends no key when it has none',
      () async {
        final connection = connectionFor(
          json(const {'data': <Object?>[]}),
          apiKey: null,
          baseUrl: Uri.parse('http://localhost:8080/v1/'),
        );

        await connection.models();

        expect(
          requests.single.url,
          Uri.parse('http://localhost:8080/v1/models'),
        );
        expect(requests.single.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('maps HTTP status codes to failure kinds', () async {
      final expectations = <int, ProviderFailure Function(String)>{
        401: ProviderAuthFailed.new,
        403: ProviderAuthFailed.new,
        429: ProviderRateLimited.new,
        500: ProviderServerFailed.new,
        503: ProviderServerFailed.new,
        404: ProviderRejected.new,
      };
      for (final entry in expectations.entries) {
        final connection = connectionFor(json(const {}, status: entry.key));

        final result = await connection.models();

        final failure = (result as ProviderModelsFailed).failure;
        expect(
          failure,
          entry.value('HTTP ${entry.key} listing models.'),
          reason: '${entry.key}',
        );
      }
    });

    test('reports transport errors as network failures', () async {
      final connection = connectionFor(
        (_) => throw http.ClientException('connection refused'),
      );

      final result = await connection.models();

      expect(
        (result as ProviderModelsFailed).failure,
        const ProviderUnreachable('connection refused'),
      );
    });

    test('reports unreadable bodies as malformed responses', () async {
      final bodies = [
        'not json',
        '{"data": "nope"}',
        '{"models": []}',
        '{"data": [{"name": "no id"}]}',
      ];
      for (final body in bodies) {
        final connection = connectionFor((_) => http.Response(body, 200));

        final result = await connection.models();

        final failure = (result as ProviderModelsFailed).failure;
        expect(failure, isA<ProviderResponseMalformed>(), reason: body);
        expect(failure.message, startsWith('Unreadable model list: '));
      }
    });
  });
}
