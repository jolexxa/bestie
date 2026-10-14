import 'dart:async';
import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:clock/clock.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_fireworks/src/fireworks_settings.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Fireworks AI: models and billing from the management API, completions
/// from its OpenAI-compatible inference API, all behind one API key. It
/// lists nothing until it has one. Fireworks reports no balance, so
/// [credits] carries spend alone.
@dataSource
final class FireworksClient implements ProviderClient, ProviderConnection {
  FireworksClient({
    required http.Client client,
    Uri? managementUrl,
    Clock clock = const Clock(),
  }) : _client = client,
       _managementUrl =
           managementUrl ?? Uri.parse('https://api.fireworks.ai/v1'),
       _clock = clock;

  /// Where Fireworks serves its OpenAI-compatible API.
  static final Uri inferenceUrl = Uri.parse(
    'https://api.fireworks.ai/inference/v1',
  );

  static const _noKey = ProviderAuthFailed(
    'No Fireworks AI API key configured.',
  );

  final http.Client _client;
  final Uri _managementUrl;
  final Clock _clock;
  final _reconfigured = StreamController<ProviderAvailability>.broadcast();
  FireworksSettings _settings = FireworksSettings.unset;

  /// The account slug behind the key, kept after the first successful lookup.
  String? _accountId;

  @override
  String get id => 'fireworks';

  @override
  String get displayName => 'Fireworks AI';

  @override
  ProviderAvailability get availability =>
      _settings.isSet ? const ProviderReady() : const ProviderNotSetUp(_noKey);

  @override
  Stream<ProviderAvailability> get reconfigured => _reconfigured.stream;

  /// Reaches Fireworks with [settings] from now on.
  void configure(FireworksSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _accountId = null;
    _reconfigured.add(availability);
  }

  /// The serverless chat models, the only ones a key alone can run.
  @override
  Future<ProviderModelsResult> models() async {
    if (!_settings.isSet) return const ProviderModelsListed([]);
    final models = <ProviderModelInfo>[];
    String? pageToken;
    do {
      final fetched = await _get(
        _url(
          'accounts/fireworks/models',
          query: {'pageSize': '200', 'pageToken': ?pageToken},
        ),
        reading: 'models',
      );
      switch (fetched) {
        case _FetchFailed(:final failure):
          return ProviderModelsFailed(failure);
        case _Fetched(:final value):
          final page = _ModelPage.parse(value);
          if (page == null) {
            return ProviderModelsFailed(_malformed('models', _modelsShape));
          }
          models.addAll(page.models);
          pageToken = page.nextPageToken;
      }
    } while (pageToken != null);
    return ProviderModelsListed(models);
  }

  @override
  Future<CreditsResult> credits() async {
    if (!_settings.isSet) return const CreditsFailed(_noKey);
    final summary = await _summary();
    return switch (summary) {
      _FetchFailed(:final failure) => CreditsFailed(failure),
      _Fetched(:final value) => switch (_spendIn(value)) {
        null => CreditsFailed(_malformed('billing', _summaryShape)),
        final spent => CreditsFetched(
          ProviderCredits(spent: spent, window: SpendWindow.monthToDate),
        ),
      },
    };
  }

  @override
  ProviderModelLoad load(ProviderModelLoadRequest request) =>
      ProviderModelLoad.settled(
        _settings.isSet
            ? ProviderModelLoaded(
                HostedProviderModel(
                  runtime: CompletionAgentRuntime.perAgentWindow(
                    client: OpenAiCompletionClient(
                      baseUrl: inferenceUrl,
                      apiKey: _settings.apiKey,
                      clientFactory: http.Client.new,
                    ),
                    options: AgentRuntimeOptions(
                      modelId: request.modelId,
                      contextWindow: request.contextWindow,
                      maxAgents: request.maxAgents,
                    ),
                  ),
                  contextWindow: request.contextWindow,
                  maxAgents: request.maxAgents,
                ),
              )
            : const ProviderModelLoadFailed(_noKey),
      );

  @override
  Future<void> close() async {}

  Future<_Fetch<Object?>> _summary() async {
    final account = await _account();
    return switch (account) {
      _FetchFailed(:final failure) => _FetchFailed(failure),
      _Fetched(:final value) => _get(_summaryUrl(value), reading: 'billing'),
    };
  }

  Future<_Fetch<String>> _account() async {
    if (_accountId case final id?) return _Fetched(id);
    final fetched = await _get(_url('accounts'), reading: 'billing');
    return switch (fetched) {
      _FetchFailed(:final failure) => _FetchFailed(failure),
      _Fetched(:final value) => switch (_accountIdIn(value)) {
        null => _FetchFailed(_malformed('billing', _accountShape)),
        final id => _Fetched(_accountId = id),
      },
    };
  }

  /// One management-API call; [reading] names what it reads in failures.
  Future<_Fetch<Object?>> _get(Uri url, {required String reading}) async {
    final http.Response response;
    try {
      response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer ${_settings.apiKey}'},
      );
    } on http.ClientException catch (error) {
      return _FetchFailed(
        ProviderUnreachable(error.message),
      );
    }
    if (response.statusCode != 200) {
      return _FetchFailed(_failureForStatus(response, reading));
    }
    try {
      return _Fetched(jsonDecode(response.body));
    } on FormatException catch (error) {
      return _FetchFailed(_malformed(reading, error.message));
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

  static const _modelsShape = 'expected "models" whose entries have a "name".';
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

  static ProviderFailure _failureForStatus(
    http.Response response,
    String reading,
  ) => ProviderFailure.forStatus(
    response.statusCode,
    'HTTP ${response.statusCode} reading Fireworks $reading.',
  );

  static ProviderFailure _malformed(String reading, String detail) =>
      ProviderResponseMalformed('Unreadable Fireworks $reading: $detail');
}

/// One page of the management API's model list.
final class _ModelPage {
  const _ModelPage({required this.models, required this.nextPageToken});

  /// The page in `{"models": [...], "nextPageToken": "..."}`, keeping the
  /// serverless chat models; null when the shape is off.
  static _ModelPage? parse(Object? document) {
    if (document is! Map<String, Object?>) return null;
    final entries = document['models'] ?? const <Object?>[];
    if (entries is! List<Object?>) return null;
    final models = <ProviderModelInfo>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) return null;
      final name = entry['name'];
      if (name is! String) return null;
      if (entry['supportsServerless'] != true) continue;
      if (entry['kind'] == 'EMBEDDING_MODEL') continue;
      final displayName = entry['displayName'];
      final contextLength = entry['contextLength'];
      models.add(
        ProviderModelInfo(
          id: name,
          name: displayName is String && displayName.isNotEmpty
              ? displayName
              : name.split('/').last,
          contextLength: contextLength is num ? contextLength.toInt() : null,
          supportsTools: entry['supportsTools'] == true,
        ),
      );
    }
    final token = document['nextPageToken'];
    return _ModelPage(
      models: models,
      nextPageToken: token is String && token.isNotEmpty ? token : null,
    );
  }

  final List<ProviderModelInfo> models;

  final String? nextPageToken;
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
