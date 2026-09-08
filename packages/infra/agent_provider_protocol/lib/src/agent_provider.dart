import 'dart:async';

import 'package:agent_provider_protocol/src/agent.dart';
import 'package:agent_provider_protocol/src/runtime/agent_config.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';
import 'package:agent_provider_protocol/src/runtime/models/context_pool_snapshot.dart';
import 'package:agent_provider_protocol/src/runtime/models/dispose_agent_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/dispose_provider_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/start_primary_result.dart';
import 'package:agent_provider_protocol/src/runtime/models/start_subagent_result.dart';

/// Owns the birth and death of agents; each [Agent] owns its own life.
///
/// Start mints an agent without running it — the first turn (and every turn
/// after) goes through [Agent.run]. An agent lives until [disposeAgent]; there
/// is no separate "end".
abstract interface class AgentProvider {
  int get maxAgents;

  /// Whole-pool occupancy snapshots, emitted whenever the shared KV pool
  /// changes. Agent-independent — there is one pool across all agents.
  Stream<ContextPoolSnapshot> get pool;

  /// Every charge a completion reports, in the provider's currency, as it
  /// lands.
  Stream<double> get spend;

  Future<StartPrimaryResult> startPrimary({required AgentConfig config});

  Future<StartSubagentResult> startSubagent({
    required AgentConfig config,
    String? label,
  });

  /// Releases the agent's lease and record. A still-running agent is rejected
  /// with [AgentRuntimeRejectionReason.busy] — cancel it first.
  Future<DisposeAgentResult> disposeAgent(Agent agent);

  Future<DisposeProviderResult> dispose();
}
