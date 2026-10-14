import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart'
    show AgentRuntime;
import 'package:clock/clock.dart';
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

  /// How many times in a row the served model was lost.
  int losses = 0;

  /// When the chosen model last started serving.
  late DateTime servingSince;

  /// The wait before loading a lost model again.
  Timer? recovery;
}

/// How a model that stops being served is loaded again: after a wait that
/// doubles with each loss in a row, at most [maxLosses] times, where a
/// model that served for [stableAfter] starts the count over.
@model
final class RecoveryPolicy {
  const RecoveryPolicy({
    required this.clock,
    this.maxLosses = 3,
    this.firstDelay = const Duration(seconds: 1),
    this.stableAfter = const Duration(minutes: 5),
  });

  final Clock clock;

  final int maxLosses;

  final Duration firstDelay;

  final Duration stableAfter;

  /// The wait before the [loss]th load in a row, counting from 1.
  Duration delayBefore(int loss) => firstDelay * (1 << (loss - 1));
}
