import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/src/models/credits_result.dart';
import 'package:provider_protocol/src/models/key_info_result.dart';
import 'package:provider_protocol/src/models/provider_models_result.dart';

/// A hosted model provider such as OpenRouter: the inference endpoints it
/// serves and the account APIs around them.
abstract interface class Provider {
  /// Stable identifier, e.g. `openrouter`.
  String get id;

  String get displayName;

  /// Every inference protocol this provider speaks, with the endpoint to
  /// reach it.
  Map<InferenceProtocolId, InferenceEndpoint> get endpoints;

  Future<CreditsResult> credits();

  Future<KeyInfoResult> keyInfo();

  Future<ProviderModelsResult> models();
}
