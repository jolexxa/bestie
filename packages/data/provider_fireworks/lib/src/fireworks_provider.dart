import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Fireworks AI: an OpenAI-compatible inference endpoint for models and
/// completions, plus the management API's billing summary for month-to-date
/// spend. Fireworks reports no balance, so [credits] carries spend alone.
@dataSource
final class FireworksProvider implements Provider {
  FireworksProvider({
    required Provider inference,
    required String apiKey,
    required http.Client client,
    Uri? managementUrl,
    Clock clock = const Clock(),
  }) : _inference = inference,
       _apiKey = apiKey,
       _client = client,
       _managementUrl =
           managementUrl ?? Uri.parse('https://api.fireworks.ai/v1'),
       _clock = clock;

  final Provider _inference;
  final String _apiKey;
  final http.Client _client;
  final Uri _managementUrl;
  final Clock _clock;

  /// The account slug behind the key, kept after the first successful lookup.
  String? _accountId;

  @override
  String get id => _inference.id;

  @override
  String get displayName => _inference.displayName;

  @override
  Map<InferenceProtocolId, InferenceEndpoint> get endpoints =>
      _inference.endpoints;

  @override
  Future<KeyInfoResult> keyInfo() => _inference.keyInfo();

  @override
  Future<ProviderModelsResult> models() => _inference.models();

  @override
  Future<CreditsResult> credits() async {
    final summary = await _summary();
    return switch (summary) {
      _FetchFailed(:final failure) => CreditsFailed(failure),
      _Fetched(:final value) => switch (_spendIn(value)) {
        null => CreditsFailed(_malformed(_summaryShape)),
        final spent => CreditsFetched(
          ProviderCredits(spent: spent, window: SpendWindow.monthToDate),
        ),
      },
    };
  }

  Future<_Fetch<Object?>> _summary() async {
    final account = await _account();
    return switch (account) {
      _FetchFailed(:final failure) => _FetchFailed(failure),
      _Fetched(:final value) => _get(_summaryUrl(value)),
    };
  }

  Future<_Fetch<String>> _account() async {
    if (_accountId case final id?) return _Fetched(id);
    final fetched = await _get(_url('accounts'));
    return switch (fetched) {
      _FetchFailed(:final failure) => _FetchFailed(failure),
      _Fetched(:final value) => switch (_accountIdIn(value)) {
        null => _FetchFailed(_malformed(_accountShape)),
        final id => _Fetched(_accountId = id),
      },
    };
  }

  Future<_Fetch<Object?>> _get(Uri url) async {
    final http.Response response;
    try {
      response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $_apiKey'},
      );
    } on http.ClientException catch (error) {
      return _FetchFailed(
        ProviderFailure(
          kind: InferenceFailureKind.network,
          message: error.message,
        ),
      );
    }
    if (response.statusCode != 200) {
      return _FetchFailed(_failureForStatus(response));
    }
    try {
      return _Fetched(jsonDecode(response.body));
    } on FormatException catch (error) {
      return _FetchFailed(_malformed(error.message));
    }
  }

  /// The calendar month so far in UTC: the first of the month through the end
  /// of today, since the summary's end is exclusive.
  Uri _summaryUrl(String accountId) {
    final now = _clock.now().toUtc();
    final start = DateTime.utc(now.year, now.month);
    final end = DateTime.utc(now.year, now.month, now.day + 1);
    return _url(
      'accounts/$accountId/billing/summary',
      query: {'startTime': _dayStamp(start), 'endTime': _dayStamp(end)},
    );
  }

  Uri _url(String path, {Map<String, String>? query}) => _managementUrl.replace(
    path: '${_managementUrl.path.replaceAll(RegExp(r'/+$'), '')}/$path',
    queryParameters: query,
  );

  static String _dayStamp(DateTime day) =>
      '${day.toIso8601String().substring(0, 10)}T00:00:00Z';

  static const _accountShape = 'expected an "accounts" list naming one.';
  static const _summaryShape =
      'expected "lineItems" whose "totalCost" is money.';

  /// The slug from `{"accounts": [{"name": "accounts/<slug>"}]}`, or null.
  static String? _accountIdIn(Object? document) {
    if (document is! Map<String, Object?>) return null;
    final accounts = document['accounts'];
    if (accounts is! List<Object?> || accounts.isEmpty) return null;
    final first = accounts.first;
    if (first is! Map<String, Object?>) return null;
    final name = first['name'];
    return name is String ? name.split('/').last : null;
  }

  /// The summed `lineItems[].totalCost`, or null when the shape is off. A
  /// summary with no line items is a month with no spend.
  static double? _spendIn(Object? document) {
    if (document is! Map<String, Object?>) return null;
    final items = document['lineItems'] ?? const <Object?>[];
    if (items is! List<Object?>) return null;
    var total = 0.0;
    for (final item in items) {
      if (item is! Map<String, Object?>) return null;
      final amount = _money(item['totalCost']);
      if (amount == null) return null;
      total += amount;
    }
    return total;
  }

  /// A protobuf `Money` as decimal units: `units` arrives as an int64 string
  /// (or a number), `nanos` as a number, and either may be omitted when zero.
  static double? _money(Object? money) {
    if (money is! Map<String, Object?>) return null;
    final units = switch (money['units']) {
      null => 0.0,
      final num value => value.toDouble(),
      final String value => double.tryParse(value),
      _ => null,
    };
    final nanos = switch (money['nanos']) {
      null => 0.0,
      final num value => value.toDouble(),
      _ => null,
    };
    if (units == null || nanos == null) return null;
    return units + nanos / 1e9;
  }

  static ProviderFailure _failureForStatus(http.Response response) =>
      ProviderFailure(
        kind: switch (response.statusCode) {
          401 || 403 => InferenceFailureKind.auth,
          429 => InferenceFailureKind.rateLimit,
          >= 500 => InferenceFailureKind.server,
          _ => InferenceFailureKind.badRequest,
        },
        message: 'HTTP ${response.statusCode} reading Fireworks billing.',
      );

  static ProviderFailure _malformed(String detail) => ProviderFailure(
    kind: InferenceFailureKind.malformedResponse,
    message: 'Unreadable Fireworks billing: $detail',
  );
}

/// One management-API call: the decoded body, or why it produced none.
sealed class _Fetch<T> {
  const _Fetch();
}

final class _Fetched<T> extends _Fetch<T> {
  const _Fetched(this.value);

  final T value;
}

final class _FetchFailed<T> extends _Fetch<T> {
  const _FetchFailed(this.failure);

  final ProviderFailure failure;
}
