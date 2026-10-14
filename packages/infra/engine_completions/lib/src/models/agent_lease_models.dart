/// The answer to a request to lease a sequence for an agent.
sealed class AgentOpenOutcome {
  const AgentOpenOutcome();
}

/// The agent holds a sequence.
final class AgentLeaseOpened extends AgentOpenOutcome {
  const AgentLeaseOpened({required this.claimedTokens});

  /// Context tokens set aside for this agent alone. The primary sets none
  /// aside; it grows into whatever the subagents have not claimed.
  final int claimedTokens;
}

/// Every sequence the context offers is leased, or a primary is already
/// leased.
final class AgentLeaseNoCapacity extends AgentOpenOutcome {
  const AgentLeaseNoCapacity();
}

/// A sequence is free, but the context left beside the other claims and the
/// primary's resident tokens is too small to claim.
final class AgentLeaseInsufficientClaim extends AgentOpenOutcome {
  const AgentLeaseInsufficientClaim();
}

/// The backend refused the sequence.
final class AgentLeaseFailed extends AgentOpenOutcome {
  const AgentLeaseFailed({required this.message});

  final String message;
}

/// The answer to a request to give an agent's sequence back.
sealed class AgentCloseOutcome {
  const AgentCloseOutcome();
}

final class AgentLeaseClosed extends AgentCloseOutcome {
  const AgentLeaseClosed();
}

/// No agent with that id holds a lease.
final class AgentLeaseUnknown extends AgentCloseOutcome {
  const AgentLeaseUnknown();
}

/// The runtime could not be reached to give the sequence back.
final class AgentCloseFailed extends AgentCloseOutcome {
  const AgentCloseFailed({required this.message});

  final String message;
}

/// How the context is divided among the leased agents.
final class PoolSnapshot {
  const PoolSnapshot({
    required this.contextSize,
    required this.maxAgents,
    required this.agents,
    this.borrowedTokens = 0,
  });

  final int contextSize;

  final int maxAgents;

  /// Every agent holding a lease, in lease order.
  final List<PoolLease> agents;

  /// The context claimed by sequences lent to requests that named no agent.
  final int borrowedTokens;
}

/// One agent's share of the context.
sealed class PoolLease {
  const PoolLease({required this.id, required this.usedTokens});

  final String id;

  /// Tokens resident in the agent's sequence.
  final int usedTokens;

  /// Context tokens set aside for this agent alone.
  int get claimedTokens;
}

/// The primary agent, which claims nothing and grows into whatever the
/// subagents leave.
final class PrimaryPoolLease extends PoolLease {
  const PrimaryPoolLease({required super.id, required super.usedTokens});

  @override
  int get claimedTokens => 0;
}

final class SubagentPoolLease extends PoolLease {
  const SubagentPoolLease({
    required super.id,
    required super.usedTokens,
    required this.claimedTokens,
  });

  @override
  final int claimedTokens;
}
