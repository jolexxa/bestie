import 'package:provider_protocol/src/models/credits_result.dart';
import 'package:provider_protocol/src/models/provider_model_load.dart';
import 'package:provider_protocol/src/models/provider_model_load_request.dart';
import 'package:provider_protocol/src/models/provider_models_result.dart';

/// One provider reached with the credentials it was connected with.
abstract interface class ProviderConnection {
  /// The models the provider lists, with every fact an agent needs filled
  /// in. Never throws.
  Future<ProviderModelsResult> models();

  /// The account balance. Never throws.
  Future<CreditsResult> credits();

  /// Gets one of the provider's models ready to serve completions.
  ProviderModelLoad load(ProviderModelLoadRequest request);

  /// Lets go of everything the connection holds.
  Future<void> close();
}
