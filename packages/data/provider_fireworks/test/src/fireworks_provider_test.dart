import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

class _MockProvider extends Mock implements Provider {}

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
  late _MockProvider inference;

  setUp(() {
    requests = [];
    inference = _MockProvider();
  });

  http.Response json(Object? body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);

  FireworksProvider providerFor(
    http.Response Function(http.Request request) respond, {
    Uri? managementUrl,
    DateTime? now,
  }) => FireworksProvider(
    inference: inference,
    apiKey: 'fw-key',
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    managementUrl: managementUrl,
    clock: Clock.fixed(now ?? DateTime.utc(2026, 9, 6, 12)),
  );

  /// Serves the accounts list, then [summary] for the billing summary.
  http.Response Function(http.Request) billing(http.Response summary) =>
      (request) => switch (request.url.path) {
        _accountsPath => json(_accounts),
        _summaryPath => summary,
        _ => throw StateError('unexpected ${request.url}'),
      };

  group('delegation', () {
    test(
      'identity, endpoints, models and key info come from inference',
      () async {
        final endpoints = {
          InferenceProtocolId.openAiCompat: InferenceEndpoint(
            baseUrl: Uri.parse('https://api.fireworks.ai/inference/v1'),
            apiKey: 'fw-key',
          ),
        };
        const models = ProviderModelsListed([]);
        const keyInfo = KeyInfoUnsupported();
        when(() => inference.id).thenReturn('fireworks');
        when(() => inference.displayName).thenReturn('Fireworks AI');
        when(() => inference.endpoints).thenReturn(endpoints);
        when(inference.models).thenAnswer((_) async => models);
        when(inference.keyInfo).thenAnswer((_) async => keyInfo);
        final provider = providerFor((_) => throw StateError('no calls'));

        expect(provider.id, 'fireworks');
        expect(provider.displayName, 'Fireworks AI');
        expect(provider.endpoints, same(endpoints));
        expect(await provider.models(), same(models));
        expect(await provider.keyInfo(), same(keyInfo));
        expect(requests, isEmpty);
      },
    );
  });

  group('credits', () {
    test('sums the month-to-date line items into spend', () async {
      final provider = providerFor(
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

      final result = await provider.credits();

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
      final provider = providerFor(billing(json(const <String, Object?>{})));

      expect(
        _creditsOf(await provider.credits()),
        const ProviderCredits(spent: 0, window: SpendWindow.monthToDate),
      );
    });

    test('spans the whole month on its last day', () async {
      final provider = providerFor(
        billing(json(_summaryOf([]))),
        now: DateTime.utc(2026, 1, 31, 23, 59),
      );

      await provider.credits();

      expect(
        requests.last.url.queryParameters,
        {
          'startTime': '2026-01-01T00:00:00Z',
          'endTime': '2026-02-01T00:00:00Z',
        },
      );
    });

    test('looks the account up once and reuses it', () async {
      final provider = providerFor(billing(json(_summaryOf([]))));

      await provider.credits();
      await provider.credits();

      expect(
        requests.map((request) => request.url.path),
        [_accountsPath, _summaryPath, _summaryPath],
      );
    });

    test('retries the account lookup after it fails', () async {
      var accountCalls = 0;
      final provider = providerFor(
        (request) => switch (request.url.path) {
          _accountsPath =>
            ++accountCalls == 1 ? json(const {}, status: 500) : json(_accounts),
          _ => json(_summaryOf([])),
        },
      );

      expect(await provider.credits(), isA<CreditsFailed>());
      expect(await provider.credits(), isA<CreditsFetched>());
      expect(accountCalls, 2);
    });

    test('honours a management URL with a trailing slash', () async {
      final provider = providerFor(
        (request) => request.url.path.endsWith('/accounts')
            ? json(_accounts)
            : json(_summaryOf([])),
        managementUrl: Uri.parse('http://localhost:9000/api/'),
      );

      await provider.credits();

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
      final provider = providerFor(
        (request) => request.url.path == _accountsPath
            ? json(const {
                'accounts': [
                  {'name': 'acme'},
                ],
              })
            : json(_summaryOf([])),
      );

      await provider.credits();

      expect(requests.last.url.path, _summaryPath);
    });

    group('maps HTTP failures', () {
      for (final (status, kind) in [
        (401, InferenceFailureKind.auth),
        (403, InferenceFailureKind.auth),
        (429, InferenceFailureKind.rateLimit),
        (500, InferenceFailureKind.server),
        (503, InferenceFailureKind.server),
        (404, InferenceFailureKind.badRequest),
      ]) {
        test('$status on the account lookup to ${kind.name}', () async {
          final provider = providerFor((_) => json(const {}, status: status));

          expect(
            _failureOf(await provider.credits()),
            ProviderFailure(
              kind: kind,
              message: 'HTTP $status reading Fireworks billing.',
            ),
          );
        });
      }

      test('on the summary as well', () async {
        final provider = providerFor(billing(json(const {}, status: 429)));

        expect(
          _failureOf(await provider.credits()),
          const ProviderFailure(
            kind: InferenceFailureKind.rateLimit,
            message: 'HTTP 429 reading Fireworks billing.',
          ),
        );
      });
    });

    test('reports transport failures as network', () async {
      final provider = providerFor(
        (_) => throw http.ClientException('connection refused'),
      );

      expect(
        _failureOf(await provider.credits()),
        const ProviderFailure(
          kind: InferenceFailureKind.network,
          message: 'connection refused',
        ),
      );
    });

    test('reports bodies that are not JSON as malformed', () async {
      final provider = providerFor((_) => http.Response('<html>', 200));

      final failure = _failureOf(await provider.credits());

      expect(failure.kind, InferenceFailureKind.malformedResponse);
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
          final provider = providerFor((_) => json(body));

          expect(
            _failureOf(await provider.credits()),
            const ProviderFailure(
              kind: InferenceFailureKind.malformedResponse,
              message:
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
          final provider = providerFor(billing(json(body)));

          expect(
            _failureOf(await provider.credits()),
            const ProviderFailure(
              kind: InferenceFailureKind.malformedResponse,
              message:
                  'Unreadable Fireworks billing: expected "lineItems" whose '
                  '"totalCost" is money.',
            ),
          );
        });
      }
    });
  });
}
