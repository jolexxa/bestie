import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show Provider, ProviderFailure, ProviderKeyInfo;
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/models/resolved_model.dart';
import 'package:provider_repository/src/state/provider_session/provider_connection.dart';

/// Starts a timer that calls [fire] once [duration] has passed.
typedef StartTimer = Timer Function(Duration duration, void Function() fire);

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

  /// How far the chosen model is from serving, once its provider says.
  double? activationProgress;

  ProviderKeyInfo? keyInfo;

  AgentProvider? handle;

  /// The provider last asked to activate a model, until the session moves to
  /// another provider.
  Provider? activated;

  ProviderFailure? failure;

  /// How many times in a row the served model was lost.
  int losses = 0;

  /// When the chosen model last started serving.
  late DateTime servingSince;

  /// The wait before activating a lost model again.
  Timer? recovery;
}

/// How a model that stops being served is activated again: after a wait
/// that doubles with each loss in a row, at most [maxLosses] times, where a
/// model that served for [stableAfter] starts the count over.
@model
final class RecoveryPolicy {
  const RecoveryPolicy({
    required this.clock,
    required this.startTimer,
    this.maxLosses = 3,
    this.firstDelay = const Duration(seconds: 1),
    this.stableAfter = const Duration(minutes: 5),
  });

  final Clock clock;

  final StartTimer startTimer;

  final int maxLosses;

  final Duration firstDelay;

  final Duration stableAfter;

  /// The wait before the [loss]th activation in a row, counting from 1.
  Duration delayBefore(int loss) => firstDelay * (1 << (loss - 1));
}
