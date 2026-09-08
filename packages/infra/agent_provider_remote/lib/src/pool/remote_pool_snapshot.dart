import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';

/// Describes remote agents in the pool vocabulary the domain already reads:
/// the primary is budgeted against the whole context window and every
/// subagent gets a window of its own, so nothing is reserved.
ContextPoolSnapshot synthesizePoolSnapshot({
  required int contextWindow,
  required Map<AgentHandle, RemoteUsage?> usageByAgent,
}) => ContextPoolSnapshot(
  contextSize: contextWindow,
  reservedClaims: 0,
  leases: [
    for (final entry in usageByAgent.entries)
      PoolLeaseOccupancy(
        handle: entry.key,
        residentTokens: entry.value?.total ?? 0,
        claimTokens: entry.key.kind == AgentKind.primary ? 0 : contextWindow,
      ),
  ],
);
