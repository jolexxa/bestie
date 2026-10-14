import 'package:agent_runtime/src/turn/agent_turn_data.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';

/// Describes the runtime's agents in the pool vocabulary the domain reads:
/// the endpoint's [report] says how the context is divided, and each agent's
/// last usage says how much of its share it fills. Agents the endpoint has
/// not reported yet are left out.
ContextPoolSnapshot poolSnapshotOf({
  required AgentPoolReport report,
  required Map<AgentHandle, AgentUsage?> usageByAgent,
}) {
  final entries = {for (final entry in report.agents) entry.agent.id: entry};
  return ContextPoolSnapshot(
    contextSize: report.contextSize,
    reservedClaims: report.reservedTokens,
    leases: [
      for (final MapEntry(key: handle, value: usage) in usageByAgent.entries)
        if (entries[handle.id] case final entry?)
          PoolLeaseOccupancy(
            handle: handle,
            residentTokens: entry.usedTokens ?? usage?.total ?? 0,
            claimTokens: entry.claimedTokens,
          ),
    ],
  );
}
