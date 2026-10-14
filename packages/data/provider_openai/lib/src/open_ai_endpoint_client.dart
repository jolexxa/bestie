import 'dart:async';
import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_openai/src/open_ai_endpoint_settings.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// An OpenAI-compatible server the user pointed bestie at: it lists models
/// from `GET /models` and serves completions from the same base URL. It
/// lists nothing until it has an address.
@dataSource
final class OpenAiEndpointClient implements ProviderClient, ProviderConnection {
  OpenAiEndpointClient({required http.Client client}) : _client = client;

  static const _noUrl = ProviderRejected('Custom endpoint URL is not set.');

  final http.Client _client;
  final _reconfigured = StreamController<ProviderAvailability>.broadcast();
  OpenAiEndpointSettings _settings = OpenAiEndpointSettings.unset;

  @override
  String get id => 'custom';

  @override
  String get displayName => 'Custom endpoint';

  @override
  ProviderAvailability get availability =>
      _settings.isSet ? const ProviderReady() : const ProviderNotSetUp(_noUrl);

  @override
  Stream<ProviderAvailability> get reconfigured => _reconfigured.stream;

  /// Reaches the server at [settings] from now on.
  void configure(OpenAiEndpointSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _reconfigured.add(availability);
  }

  @override
  Future<CreditsResult> credits() async => const CreditsUnsupported();

  @override
  ProviderModelLoad load(ProviderModelLoadRequest request) =>
      ProviderModelLoad.settled(switch (_settings.baseUrl) {
        null => const ProviderModelLoadFailed(_noUrl),
        final baseUrl => ProviderModelLoaded(
          HostedProviderModel(
            runtime: CompletionAgentRuntime.perAgentWindow(
              client: OpenAiCompletionClient(
                baseUrl: baseUrl,
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
        ),
      });

  @override
  Future<void> close() async {}

  @override
  Future<ProviderModelsResult> models() async {
    final baseUrl = _settings.baseUrl;
    if (baseUrl == null) return const ProviderModelsListed([]);
    final http.Response response;
    try {
      response = await _client.get(
        _modelsUrl(baseUrl),
        headers: {'Authorization': ?_bearer},
      );
    } on http.ClientException catch (error) {
      return ProviderModelsFailed(
        ProviderUnreachable(error.message),
      );
    }
    if (response.statusCode != 200) {
      return ProviderModelsFailed(_failureForStatus(response));
    }
    final Object? document;
    try {
      document = jsonDecode(response.body);
    } on FormatException catch (error) {
      return ProviderModelsFailed(_malformed(error.message));
    }
    final models = _parseModels(document, _settings.contextWindow);
    return models == null
        ? ProviderModelsFailed(_malformed(_unexpectedShape))
        : ProviderModelsListed(models);
  }

  String? get _bearer => switch (_settings.apiKey) {
    null => null,
    final apiKey => 'Bearer $apiKey',
  };

  static Uri _modelsUrl(Uri baseUrl) => baseUrl.replace(
    path: '${baseUrl.path.replaceAll(RegExp(r'/+$'), '')}/models',
  );

  static const _unexpectedShape = 'expected a "data" list of models with ids.';

  /// Null unless the body is `{"data": [{"id": ...}, ...]}`.
  static List<ProviderModelInfo>? _parseModels(
    Object? document,
    int fallbackContextWindow,
  ) {
    if (document is! Map<String, Object?>) return null;
    final entries = document['data'];
    if (entries is! List<Object?>) return null;
    final models = <ProviderModelInfo>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) return null;
      final id = entry['id'];
      if (id is! String) return null;
      models.add(
        ProviderModelInfo(
          id: id,
          name: id,
          contextLength: _contextLength(entry) ?? fallbackContextWindow,
          supportsTools: true,
        ),
      );
    }
    return models;
  }

  /// llama.cpp reports the training context under `meta.n_ctx_train`; a
  /// few gateways use a top-level `context_length`; anything else gets the
  /// window the user said to assume.
  static int? _contextLength(Map<String, Object?> entry) {
    final meta = entry['meta'];
    final trained = meta is Map<String, Object?> ? meta['n_ctx_train'] : null;
    final declared = trained ?? entry['context_length'];
    return declared is num ? declared.toInt() : null;
  }

  static ProviderFailure _failureForStatus(http.Response response) =>
      ProviderFailure.forStatus(
        response.statusCode,
        'HTTP ${response.statusCode} listing models.',
      );

  static ProviderFailure _malformed(String detail) =>
      ProviderResponseMalformed('Unreadable model list: $detail');
}
