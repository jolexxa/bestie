import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_openai_compat/provider_openai_compat.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final _descriptor = ProviderDescriptor(
  id: 'custom',
  displayName: 'Custom endpoint',
  requiresApiKey: false,
  dialect: InferenceDialect.openAi,
  baseUrl: Uri.parse('http://localhost:8080/v1'),
  requiresBaseUrl: true,
);

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = [];
  });

  OpenAiCompatProvider providerFor(
    http.Response Function(http.Request request) respond, {
    String apiKey = 'local-key',
    Uri? baseUrl,
  }) => OpenAiCompatProvider(
    descriptor: _descriptor,
    baseUrl: baseUrl ?? _descriptor.baseUrl!,
    apiKey: apiKey,
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
  );

  http.Response Function(http.Request) json(Object? body, {int status = 200}) =>
      (_) => http.Response(jsonEncode(body), status);

  test('identifies itself through the descriptor', () {
    final provider = providerFor(json(const {'data': <Object?>[]}));

    expect(provider.id, 'custom');
    expect(provider.displayName, 'Custom endpoint');
  });

  test('exposes the endpoint with the descriptor dialect and key', () {
    final provider = providerFor(json(const {'data': <Object?>[]}));

    expect(provider.endpoints, {
      InferenceProtocolId.openAiCompat: InferenceEndpoint(
        baseUrl: _descriptor.baseUrl!,
        apiKey: 'local-key',
      ),
    });
  });

  test('leaves the endpoint key unset without an API key', () {
    final provider = providerFor(json(const {'data': <Object?>[]}), apiKey: '');

    expect(
      provider.endpoints[InferenceProtocolId.openAiCompat]!.apiKey,
      isNull,
    );
  });

  test('has no credits or key metadata', () async {
    final provider = providerFor(json(const {'data': <Object?>[]}));

    expect(await provider.credits(), isA<CreditsUnsupported>());
    expect(await provider.keyInfo(), isA<KeyInfoUnsupported>());
  });

  group('models', () {
    test('lists ids with whatever context length the server reports', () async {
      final provider = providerFor(
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

      final result = await provider.models();

      expect((result as ProviderModelsListed).models, const [
        ProviderModel(
          id: 'accounts/fireworks/models/kimi',
          name: 'accounts/fireworks/models/kimi',
          supportsTools: true,
        ),
        ProviderModel(
          id: 'llama-3.1-8b',
          name: 'llama-3.1-8b',
          contextLength: 131072,
          supportsTools: true,
        ),
        ProviderModel(
          id: 'gateway-model',
          name: 'gateway-model',
          contextLength: 32768,
          supportsTools: true,
        ),
        ProviderModel(id: 'odd-model', name: 'odd-model', supportsTools: true),
      ]);
      final sent = requests.single;
      expect(
        sent.url,
        Uri.parse('http://localhost:8080/v1/models'),
      );
      expect(sent.headers['Authorization'], 'Bearer local-key');
    });

    test(
      'joins the models path onto a base URL with a trailing slash',
      () async {
        final provider = providerFor(
          json(const {'data': <Object?>[]}),
          apiKey: '',
          baseUrl: Uri.parse('http://localhost:8080/v1/'),
        );

        await provider.models();

        expect(
          requests.single.url,
          Uri.parse('http://localhost:8080/v1/models'),
        );
        expect(requests.single.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('maps HTTP status codes to failure kinds', () async {
      const expectations = {
        401: InferenceFailureKind.auth,
        403: InferenceFailureKind.auth,
        429: InferenceFailureKind.rateLimit,
        500: InferenceFailureKind.server,
        503: InferenceFailureKind.server,
        404: InferenceFailureKind.badRequest,
      };
      for (final entry in expectations.entries) {
        final provider = providerFor(json(const {}, status: entry.key));

        final result = await provider.models();

        final failure = (result as ProviderModelsFailed).failure;
        expect(failure.kind, entry.value, reason: '${entry.key}');
        expect(failure.message, 'HTTP ${entry.key} listing models.');
      }
    });

    test('reports transport errors as network failures', () async {
      final provider = providerFor(
        (_) => throw http.ClientException('connection refused'),
      );

      final result = await provider.models();

      expect(
        (result as ProviderModelsFailed).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.network,
          message: 'connection refused',
        ),
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
        final provider = providerFor((_) => http.Response(body, 200));

        final result = await provider.models();

        final failure = (result as ProviderModelsFailed).failure;
        expect(
          failure.kind,
          InferenceFailureKind.malformedResponse,
          reason: body,
        );
        expect(failure.message, startsWith('Unreadable model list: '));
      }
    });
  });
}
