import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Describes the provider's agents in the pool vocabulary the domain reads:
/// the endpoint's [report] says how the context is divided, and each agent's
/// last usage says how much of its share it fills. Agents the endpoint has
/// not reported yet are left out.
ContextPoolSnapshot poolSnapshotOf({
  required AgentPoolReport report,
  required Map<AgentHandle, RemoteUsage?> usageByAgent,
}) {
  final claims = {
    for (final entry in report.agents) entry.agent.id: entry.claimedTokens,
  };
  return ContextPoolSnapshot(
    contextSize: report.contextSize,
    reservedClaims: report.reservedTokens,
    leases: [
      for (final MapEntry(key: handle, value: usage) in usageByAgent.entries)
        if (claims[handle.id] case final claim?)
          PoolLeaseOccupancy(
            handle: handle,
            residentTokens: usage?.total ?? 0,
            claimTokens: claim,
          ),
    ],
  );
}
