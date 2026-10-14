import 'package:engine_completions/src/completion_turn.dart';
import 'package:engine_completions/src/models/agent_lease_models.dart';
import 'package:engine_protocol/engine_protocol.dart';
import 'package:engine_scheduler/engine_scheduler.dart';

/// One agent's hold on a sequence: its lease, the sampling its sampler chain
/// was built with, and the completion it is running, if any. The tokens the
/// sequence holds are recorded by the scheduler, which plans prefix reuse
/// from them.
final class AgentSequenceSession {
  AgentSequenceSession({
    required this.id,
    required this.lease,
    required this.sampling,
  });

  final String id;

  final Lease lease;

  EngineSampling sampling;

  EngineCompletionTurn? turn;

  bool get isSubagent => lease is SubagentLease;

  int get claimedTokens => switch (lease) {
    PrimaryLease() => 0,
    SubagentLease(:final claimSize) => claimSize,
  };

  /// This agent's share of the pool, with [usedTokens] resident.
  PoolLease poolLease({required int usedTokens}) => switch (lease) {
    PrimaryLease() => PrimaryPoolLease(id: id, usedTokens: usedTokens),
    SubagentLease(:final claimSize) => SubagentPoolLease(
      id: id,
      usedTokens: usedTokens,
      claimedTokens: claimSize,
    ),
  };
}
