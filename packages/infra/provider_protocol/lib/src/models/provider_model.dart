import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';

/// A model a provider serves completions on, from the moment it is loaded
/// until it is released.
abstract interface class ProviderModel {
  /// The context the model runs with.
  int get contextWindow;

  /// The most agents that may run on the model at once.
  int get maxAgents;

  /// Memory the model takes on the device; null when it runs elsewhere.
  int? get deviceBytes;

  /// Runs agents on the model.
  AgentRuntime get runtime;

  /// Completes once the model stops being served and must be loaded again.
  /// Never completes with an error.
  Future<void> get lost;

  /// Lets go of whatever loading the model held, its runtime included.
  Future<void> release();
}

/// A model served on demand by a hosted endpoint: nothing was loaded and it
/// is never lost.
final class HostedProviderModel implements ProviderModel {
  HostedProviderModel({
    required this.runtime,
    required this.contextWindow,
    required this.maxAgents,
  });

  @override
  final AgentRuntime runtime;

  @override
  final int contextWindow;

  @override
  final int maxAgents;

  @override
  int? get deviceBytes => null;

  @override
  Future<void> get lost => Completer<void>().future;

  @override
  Future<void> release() async {
    await runtime.dispose();
  }
}
