import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderFailure, ProviderKeyInfo;
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/models/resolved_model.dart';
import 'package:provider_repository/src/state/provider_session/provider_connection.dart';

/// Mutable data shared by the provider session states.
@model
final class ProviderSessionData {
  ProviderSessionData();

  ProviderSettings? settings;

  /// Bumped whenever the settings change so a probe that started under older
  /// settings is ignored when it lands.
  int attempt = 0;

  /// One connection per usable account, keyed by provider id.
  Map<String, ProviderConnection> connections = const {};

  /// The connection the chosen model runs on.
  ProviderConnection? connection;

  ResolvedModel? model;

  ProviderKeyInfo? keyInfo;

  AgentProvider? handle;

  ProviderFailure? failure;
}
