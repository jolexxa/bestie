import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// A provider with no account APIs: it lists models from `GET /models` and
/// serves completions from the same base URL.
@dataSource
final class OpenAiCompatProvider implements Provider {
  OpenAiCompatProvider({
    required ProviderDescriptor descriptor,
    required Uri baseUrl,
    required String apiKey,
    required http.Client client,
  }) : _descriptor = descriptor,
       _baseUrl = baseUrl,
       _apiKey = apiKey,
       _client = client,
       endpoints = {
         InferenceProtocolId.openAiCompat: InferenceEndpoint(
           baseUrl: baseUrl,
           apiKey: apiKey.isEmpty ? null : apiKey,
           dialect: descriptor.dialect,
         ),
       };

  final ProviderDescriptor _descriptor;
  final Uri _baseUrl;
  final String _apiKey;
  final http.Client _client;

  @override
  final Map<InferenceProtocolId, InferenceEndpoint> endpoints;

  @override
  String get id => _descriptor.id;

  @override
  String get displayName => _descriptor.displayName;

  @override
  Future<CreditsResult> credits() async => const CreditsUnsupported();

  @override
  Future<KeyInfoResult> keyInfo() async => const KeyInfoUnsupported();

  @override
  Future<ProviderModelsResult> models() async {
    final http.Response response;
    try {
      response = await _client.get(
        _modelsUrl,
        headers: {if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey'},
      );
    } on http.ClientException catch (error) {
      return ProviderModelsFailed(
        ProviderFailure(
          kind: InferenceFailureKind.network,
          message: error.message,
        ),
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
    final models = _parseModels(document);
    return models == null
        ? ProviderModelsFailed(_malformed(_unexpectedShape))
        : ProviderModelsListed(models);
  }

  Uri get _modelsUrl => _baseUrl.replace(
    path: '${_baseUrl.path.replaceAll(RegExp(r'/+$'), '')}/models',
  );

  static const _unexpectedShape = 'expected a "data" list of models with ids.';

  /// Null unless the body is `{"data": [{"id": ...}, ...]}`.
  static List<ProviderModel>? _parseModels(Object? document) {
    if (document is! Map<String, Object?>) return null;
    final entries = document['data'];
    if (entries is! List<Object?>) return null;
    final models = <ProviderModel>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) return null;
      final id = entry['id'];
      if (id is! String) return null;
      models.add(
        ProviderModel(
          id: id,
          name: id,
          contextLength: _contextLength(entry),
          supportsTools: true,
        ),
      );
    }
    return models;
  }

  /// llama.cpp reports the training context under `meta.n_ctx_train`; a
  /// few gateways use a top-level `context_length`.
  static int? _contextLength(Map<String, Object?> entry) {
    final meta = entry['meta'];
    final trained = meta is Map<String, Object?> ? meta['n_ctx_train'] : null;
    final declared = trained ?? entry['context_length'];
    return declared is num ? declared.toInt() : null;
  }

  static ProviderFailure _failureForStatus(http.Response response) =>
      ProviderFailure(
        kind: switch (response.statusCode) {
          401 || 403 => InferenceFailureKind.auth,
          429 => InferenceFailureKind.rateLimit,
          >= 500 => InferenceFailureKind.server,
          _ => InferenceFailureKind.badRequest,
        },
        message: 'HTTP ${response.statusCode} listing models.',
      );

  static ProviderFailure _malformed(String detail) => ProviderFailure(
    kind: InferenceFailureKind.malformedResponse,
    message: 'Unreadable model list: $detail',
  );
}
