import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:clock/clock.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

ProviderCredits _creditsOf(CreditsResult result) =>
    (result as CreditsFetched).credits;

ProviderFailure _failureOf(CreditsResult result) =>
    (result as CreditsFailed).failure;

const _accountsPath = '/v1/accounts';
const _summaryPath = '/v1/accounts/acme/billing/summary';

const _accounts = {
  'accounts': [
    {'name': 'accounts/acme'},
  ],
};

Map<String, Object?> _summaryOf(List<Object?> lineItems) => {
  'lineItems': lineItems,
};

Map<String, Object?> _lineItem(Object? totalCost) => {
  'category': 'LLM input tokens',
  'totalCost': totalCost,
};

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = [];
  });

  http.Response json(Object? body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);

  FireworksClient clientFor(
    http.Response Function(http.Request request) respond, {
    Uri? managementUrl,
    DateTime? now,
  }) => FireworksClient(
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    managementUrl: managementUrl,
    clock: Clock.fixed(now ?? DateTime.utc(2026, 9, 6, 12)),
  );

  FireworksClient connectionFor(
    http.Response Function(http.Request request) respond, {
    Uri? managementUrl,
    DateTime? now,
  }) =>
      clientFor(respond, managementUrl: managementUrl, now: now)
        ..configure(const FireworksSettings(apiKey: 'fw-key'));

  test('is named for the palette', () {
    final client = clientFor((_) => throw StateError('no calls'));

    expect(client.id, 'fireworks');
    expect(client.displayName, 'Fireworks AI');
  });

  group('without a key', () {
    const noKey = ProviderAuthFailed('No Fireworks AI API key configured.');

    test('is not set up', () {
      expect(
        clientFor((_) => throw StateError('no calls')).availability,
        const ProviderNotSetUp(noKey),
      );
    });

    test('lists nothing, asks for no billing and serves no model', () async {
      final client = clientFor((_) => throw StateError('no calls'));

      expect((await client.models() as ProviderModelsListed).models, isEmpty);
      expect((await client.credits() as CreditsFailed).failure, noKey);
      final load = client.load(
        const ProviderModelLoadRequest(
          modelId: 'm',
          contextWindow: 8192,
          maxAgents: 1,
        ),
      );
      expect((await load.result as ProviderModelLoadFailed).failure, noKey);
      expect(requests, isEmpty);
    });
  });

  /// Serves the accounts list, then [summary] for the billing summary.
  http.Response Function(http.Request) billing(http.Response summary) =>
      (request) => switch (request.url.path) {
        _accountsPath => json(_accounts),
        _summaryPath => summary,
        _ => throw StateError('unexpected ${request.url}'),
      };

  group('configure', () {
    test('makes it ready and reports each change', () async {
      final client = clientFor(billing(json(_summaryOf([]))));
      final reported = <ProviderAvailability>[];
      final listening = client.reconfigured.listen(reported.add);

      client
        ..configure(const FireworksSettings(apiKey: 'fw-key'))
        ..configure(const FireworksSettings(apiKey: 'fw-key'))
        ..configure(FireworksSettings.unset);
      await pumpEventQueue();

      expect(reported, const [
        ProviderReady(),
        ProviderNotSetUp(
          ProviderAuthFailed('No Fireworks AI API key configured.'),
        ),
      ]);
      await listening.cancel();
    });

    test('looks the account up again under a new key', () async {
      final client = connectionFor(billing(json(_summaryOf([]))));

      await client.credits();
      client.configure(const FireworksSettings(apiKey: 'fw-other'));
      await client.credits();

      expect(
        requests.map((request) => request.url.path),
        [_accountsPath, _summaryPath, _accountsPath, _summaryPath],
      );
      expect(requests.last.headers['Authorization'], 'Bearer fw-other');
    });
  });

  group('models', () {
    const modelsPath = '/v1/accounts/fireworks/models';

    test('lists the serverless chat models with their facts', () async {
      final connection = connectionFor(
        (_) => json({
          'models': [
            {
              'name': 'accounts/fireworks/models/glm-4p6',
              'displayName': 'GLM 4.6',
              'contextLength': 202752,
              'supportsTools': true,
              'supportsServerless': true,
              'kind': 'HF_BASE_MODEL',
            },
            {
              'name': 'accounts/fireworks/models/plain',
              'supportsServerless': true,
            },
            {
              'name': 'accounts/fireworks/models/dedicated-only',
              'contextLength': 8192,
              'supportsServerless': false,
            },
            {
              'name': 'accounts/fireworks/models/embedder',
              'supportsServerless': true,
              'kind': 'EMBEDDING_MODEL',
            },
          ],
        }),
      );

      final result = await connection.models();

      expect((result as ProviderModelsListed).models, const [
        ProviderModelInfo(
          id: 'accounts/fireworks/models/glm-4p6',
          name: 'GLM 4.6',
          contextLength: 202752,
          supportsTools: true,
        ),
        ProviderModelInfo(
          id: 'accounts/fireworks/models/plain',
          name: 'plain',
          supportsTools: false,
        ),
      ]);
      final sent = requests.single;
      expect(sent.url.path, modelsPath);
      expect(sent.url.queryParameters, {'pageSize': '200'});
      expect(sent.headers['Authorization'], 'Bearer fw-key');
    });

    test('follows the page token until the last page', () async {
      final connection = connectionFor(
        (request) => switch (request.url.queryParameters['pageToken']) {
          null => json({
            'models': [
              {
                'name': 'accounts/fireworks/models/a',
                'supportsServerless': true,
              },
            ],
            'nextPageToken': 'p2',
          }),
          _ => json({
            'models': [
              {
                'name': 'accounts/fireworks/models/b',
                'supportsServerless': true,
              },
            ],
            'nextPageToken': '',
          }),
        },
      );

      final result = await connection.models();

      expect(
        [for (final model in (result as ProviderModelsListed).models) model.id],
        ['accounts/fireworks/models/a', 'accounts/fireworks/models/b'],
      );
      expect(requests.last.url.queryParameters, {
        'pageSize': '200',
        'pageToken': 'p2',
      });
    });

    test('reads a page without models as empty', () async {
      final connection = connectionFor((_) => json(const <String, Object?>{}));

      final result = await connection.models();

      expect((result as ProviderModelsListed).models, isEmpty);
    });

    test('maps HTTP failures', () async {
      final connection = connectionFor((_) => json(const {}, status: 401));

      final result = await connection.models();

      expect(
        (result as ProviderModelsFailed).failure,
        const ProviderAuthFailed('HTTP 401 reading Fireworks models.'),
      );
    });

    test('rejects pages it cannot read', () async {
      final bodies = <Object?>[
        'not a map',
        {'models': 'nope'},
        {
          'models': ['nope'],
        },
        {
          'models': [
            {'displayName': 'no name'},
          ],
        },
      ];
      for (final body in bodies) {
        final connection = connectionFor((_) => json(body));

        final result = await connection.models();

        expect(
          (result as ProviderModelsFailed).failure,
          const ProviderResponseMalformed(
            'Unreadable Fireworks models: expected "models" whose '
            'entries have a "name".',
          ),
          reason: '$body',
        );
      }
    });
  });

  test('serves models from the inference API at once', () async {
    final connection = connectionFor((_) => throw StateError('no calls'));

    final load = connection.load(
      const ProviderModelLoadRequest(
        modelId: 'accounts/fireworks/models/glm-4p6',
        contextWindow: 202752,
        maxAgents: 2,
      ),
    );

    expect(await load.progress.toList(), isEmpty);
    final model = (await load.result as ProviderModelLoaded).model;
    expect(model, isA<HostedProviderModel>());
    expect(model.contextWindow, 202752);
    expect(model.maxAgents, 2);
    final runtime = model.runtime as CompletionAgentRuntime;
    expect(runtime.options.modelId, 'accounts/fireworks/models/glm-4p6');
    expect(runtime.options.contextWindow, 202752);
    expect(runtime.options.maxAgents, 2);
    final served = runtime.client as OpenAiCompletionClient;
    expect(served.baseUrl, Uri.parse('https://api.fireworks.ai/inference/v1'));
    expect(served.apiKey, 'fw-key');
    expect(served.dialect, isA<StandardOpenAiDialect>());
  });

  test('holds nothing to close', () async {
    final connection = connectionFor((_) => throw StateError('no calls'));

    await expectLater(connection.close(), completes);
    expect(requests, isEmpty);
  });

  group('credits', () {
    test('sums the month-to-date line items into spend', () async {
      final connection = connectionFor(
        billing(
          json(
            _summaryOf([
              _lineItem({
                'currencyCode': 'USD',
                'units': '1',
                'nanos': 250000000,
              }),
              _lineItem({'currencyCode': 'USD', 'units': 2}),
              _lineItem({'currencyCode': 'USD', 'nanos': 500000000}),
            ]),
          ),
        ),
      );

      final result = await connection.credits();

      expect(
        _creditsOf(result),
        const ProviderCredits(spent: 3.75, window: SpendWindow.monthToDate),
      );
      const summaryUrl =
          'https://api.fireworks.ai/v1/accounts/acme/billing/summary'
          '?startTime=2026-09-01T00%3A00%3A00Z'
          '&endTime=2026-09-07T00%3A00%3A00Z';
      expect(requests.map((request) => request.url.toString()), [
        'https://api.fireworks.ai/v1/accounts',
        summaryUrl,
      ]);
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer fw-key');
      }
    });

    test('reads zero spend from a month without line items', () async {
      final connection = connectionFor(
        billing(json(const <String, Object?>{})),
      );

      expect(
        _creditsOf(await connection.credits()),
        const ProviderCredits(spent: 0, window: SpendWindow.monthToDate),
      );
    });

    test('spans the whole month on its last day', () async {
      final connection = connectionFor(
        billing(json(_summaryOf([]))),
        now: DateTime.utc(2026, 1, 31, 23, 59),
      );

      await connection.credits();

      expect(
        requests.last.url.queryParameters,
        {
          'startTime': '2026-01-01T00:00:00Z',
          'endTime': '2026-02-01T00:00:00Z',
        },
      );
    });

    test('looks the account up once and reuses it', () async {
      final connection = connectionFor(billing(json(_summaryOf([]))));

      await connection.credits();
      await connection.credits();

      expect(
        requests.map((request) => request.url.path),
        [_accountsPath, _summaryPath, _summaryPath],
      );
    });

    test('retries the account lookup after it fails', () async {
      var accountCalls = 0;
      final connection = connectionFor(
        (request) => switch (request.url.path) {
          _accountsPath =>
            ++accountCalls == 1 ? json(const {}, status: 500) : json(_accounts),
          _ => json(_summaryOf([])),
        },
      );

      expect(await connection.credits(), isA<CreditsFailed>());
      expect(await connection.credits(), isA<CreditsFetched>());
      expect(accountCalls, 2);
    });

    test('honours a management URL with a trailing slash', () async {
      final connection = connectionFor(
        (request) => request.url.path.endsWith('/accounts')
            ? json(_accounts)
            : json(_summaryOf([])),
        managementUrl: Uri.parse('http://localhost:9000/api/'),
      );

      await connection.credits();

      expect(
        requests.first.url.toString(),
        'http://localhost:9000/api/accounts',
      );
      expect(
        requests.last.url.path,
        '/api/accounts/acme/billing/summary',
      );
    });

    test('takes an account name without its collection prefix', () async {
      final connection = connectionFor(
        (request) => request.url.path == _accountsPath
            ? json(const {
                'accounts': [
                  {'name': 'acme'},
                ],
              })
            : json(_summaryOf([])),
      );

      await connection.credits();

      expect(requests.last.url.path, _summaryPath);
    });

    group('maps HTTP failures', () {
      final expectations = <int, ProviderFailure Function(String)>{
        401: ProviderAuthFailed.new,
        403: ProviderAuthFailed.new,
        429: ProviderRateLimited.new,
        500: ProviderServerFailed.new,
        503: ProviderServerFailed.new,
        404: ProviderRejected.new,
      };
      for (final MapEntry(key: status, value: failureOf)
          in expectations.entries) {
        test('$status on the account lookup', () async {
          final connection = connectionFor(
            (_) => json(const {}, status: status),
          );

          expect(
            _failureOf(await connection.credits()),
            failureOf('HTTP $status reading Fireworks billing.'),
          );
        });
      }

      test('on the summary as well', () async {
        final connection = connectionFor(billing(json(const {}, status: 429)));

        expect(
          _failureOf(await connection.credits()),
          const ProviderRateLimited('HTTP 429 reading Fireworks billing.'),
        );
      });
    });

    test('reports transport failures as network', () async {
      final connection = connectionFor(
        (_) => throw http.ClientException('connection refused'),
      );

      expect(
        _failureOf(await connection.credits()),
        const ProviderUnreachable('connection refused'),
      );
    });

    test('reports bodies that are not JSON as malformed', () async {
      final connection = connectionFor((_) => http.Response('<html>', 200));

      final failure = _failureOf(await connection.credits());

      expect(failure, isA<ProviderResponseMalformed>());
      expect(failure.message, startsWith('Unreadable Fireworks billing: '));
    });

    group('rejects account lists that are', () {
      for (final (label, body) in [
        ('not an object', <Object?>[]),
        ('missing accounts', <String, Object?>{}),
        ('empty', {'accounts': <Object?>[]}),
        (
          'not objects',
          {
            'accounts': ['acme'],
          },
        ),
        (
          'unnamed',
          {
            'accounts': [<String, Object?>{}],
          },
        ),
      ]) {
        test(label, () async {
          final connection = connectionFor((_) => json(body));

          expect(
            _failureOf(await connection.credits()),
            const ProviderResponseMalformed(
              'Unreadable Fireworks billing: expected an "accounts" '
              'list naming one.',
            ),
          );
        });
      }
    });

    group('rejects summaries whose', () {
      for (final (label, body) in [
        ('body is not an object', <Object?>[]),
        ('line items are not a list', {'lineItems': 'none'}),
        (
          'line item is not an object',
          {
            'lineItems': ['item'],
          },
        ),
        ('total cost is missing', _summaryOf([_lineItem(null)])),
        (
          'units are not numeric',
          _summaryOf([
            _lineItem({'units': 'lots'}),
          ]),
        ),
        (
          'units are the wrong type',
          _summaryOf([
            _lineItem({'units': true}),
          ]),
        ),
        (
          'nanos are the wrong type',
          _summaryOf([
            _lineItem({'nanos': '1'}),
          ]),
        ),
      ]) {
        test(label, () async {
          final connection = connectionFor(billing(json(body)));

          expect(
            _failureOf(await connection.credits()),
            const ProviderResponseMalformed(
              'Unreadable Fireworks billing: expected "lineItems" whose '
              '"totalCost" is money.',
            ),
          );
        });
      }
    });
  });
}
