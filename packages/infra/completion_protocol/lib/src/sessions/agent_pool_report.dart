import 'package:completion_protocol/src/models/agent_identity.dart';
import 'package:meta/meta.dart';

/// One open session's share of an endpoint's context.
@immutable
final class AgentPoolEntry {
  const AgentPoolEntry({
    required this.agent,
    required this.claimedTokens,
    this.usedTokens,
  });

  final AgentIdentity agent;

  /// Context tokens set aside for this agent alone.
  ///
  /// On a hosted endpoint every agent has a window of its own, so each
  /// subagent claims a full window and nothing comes out of the primary's
  /// share. On the local server agents share one context: each subagent
  /// claims the context divided by the most agents the loaded model serves,
  /// carved out of the primary's share. The primary always claims 0, since it
  /// draws on whatever the subagents leave.
  final int claimedTokens;

  /// Context tokens this agent's conversation holds right now; null when the
  /// endpoint cannot see what it holds, as with a hosted window.
  final int? usedTokens;

  @override
  bool operator ==(Object other) =>
      other is AgentPoolEntry &&
      other.agent == agent &&
      other.claimedTokens == claimedTokens &&
      other.usedTokens == usedTokens;

  @override
  int get hashCode => Object.hash(agent, claimedTokens, usedTokens);

  @override
  String toString() =>
      'AgentPoolEntry(${agent.id}, $claimedTokens, used: $usedTokens)';
}

/// How an endpoint has divided its context among the open sessions.
@immutable
final class AgentPoolReport {
  const AgentPoolReport({
    required this.contextSize,
    required this.reservedTokens,
    required this.agents,
  });

  /// Total context the endpoint shares among its sessions.
  final int contextSize;

  /// Tokens claimed by subagents out of the primary's share.
  final int reservedTokens;

  /// Every open session, in the order they were opened.
  final List<AgentPoolEntry> agents;
}
