import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/src/models/credits_result.dart';
import 'package:provider_protocol/src/models/key_info_result.dart';
import 'package:provider_protocol/src/models/model_activation.dart';
import 'package:provider_protocol/src/models/provider_models_result.dart';

/// A model provider such as OpenRouter: the inference protocols it speaks
/// and the account APIs around them.
abstract interface class Provider {
  /// Stable identifier, e.g. `openrouter`.
  String get id;

  String get displayName;

  /// Every inference protocol this provider serves completions in. Where an
  /// activated model is reached is settled by its activation.
  Set<InferenceProtocolId> get protocols;

  Future<CreditsResult> credits();

  Future<KeyInfoResult> keyInfo();

  Future<ProviderModelsResult> models();

  /// Emits whenever [models] would list something different, so a listing
  /// kept from before must be fetched again.
  Stream<void> get modelsChanged;

  /// Gets one of the provider's models ready to serve completions.
  ModelActivation activate(ModelActivationRequest request);

  /// The per-agent sessions completions on an activated model run under.
  AgentSessions openSessions({required int contextWindow});

  /// Lets go of whatever activating a model held, such as a loaded model or
  /// a server session, once the app stops running on this provider.
  Future<void> deactivate();
}
