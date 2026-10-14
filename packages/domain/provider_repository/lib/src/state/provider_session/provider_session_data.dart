import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show
        ProviderAvailability,
        ProviderClient,
        ProviderFailure,
        ProviderModel,
        ProviderModelLoadProgress;
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/models/resolved_model.dart';

/// Mutable data shared by the provider session states.
@model
final class ProviderSessionData {
  ProviderSessionData();

  ProviderSettings? settings;

  /// Bumped whenever the session starts over, so that work begun before is
  /// ignored when it lands.
  int attempt = 0;

  /// Every provider's client, keyed by provider id.
  Map<String, ProviderClient> clients = {};

  /// Whether each provider is usable, keyed by provider id, as last
  /// reported by its client.
  Map<String, ProviderAvailability> availability = {};

  ResolvedModel? model;

  /// How far the chosen model is from serving, once its provider says.
  ProviderModelLoadProgress? loading;

  /// The model being served; held only while the session is ready.
  ProviderModel? loaded;

  /// The agent runtime running on [loaded].
  AgentRuntime? runtime;

  ProviderFailure? failure;
}
