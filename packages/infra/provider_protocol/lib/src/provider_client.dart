import 'package:provider_protocol/src/models/credits_result.dart';
import 'package:provider_protocol/src/models/provider_availability.dart';
import 'package:provider_protocol/src/models/provider_model_load.dart';
import 'package:provider_protocol/src/models/provider_model_load_request.dart';
import 'package:provider_protocol/src/models/provider_models_result.dart';

/// One provider bestie ships, configured by its own feature: what it is
/// called, whether it is usable, and the models it lists, loads, and bills.
abstract interface class ProviderClient {
  /// Stable identifier, e.g. `openrouter`.
  String get id;

  String get displayName;

  ProviderAvailability get availability;

  /// Reports [availability] every time the client's settings change, so
  /// whoever runs a model on it can start over.
  Stream<ProviderAvailability> get reconfigured;

  /// The models the provider lists, with every fact an agent needs filled
  /// in. Never throws.
  Future<ProviderModelsResult> models();

  /// The account balance. Never throws.
  Future<CreditsResult> credits();

  /// Gets one of the provider's models ready to serve completions.
  ProviderModelLoad load(ProviderModelLoadRequest request);
}
