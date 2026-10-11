import 'package:dart_mappable/dart_mappable.dart';

part 'agent_lease.mapper.dart';

/// Whether a lease belongs to the primary agent or one of its subagents.
@MappableEnum(caseStyle: CaseStyle.snakeCase)
enum AgentLeaseKind { primary, subagent }

/// The body of a request to open a lease for one agent.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class AgentOpenRequest with AgentOpenRequestMappable {
  const AgentOpenRequest({required this.kind});

  final AgentLeaseKind kind;
}

/// The server's answer to a lease request.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'result')
sealed class AgentOpenResult with AgentOpenResultMappable {
  const AgentOpenResult();
}

/// The lease is held.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'opened')
final class AgentOpened extends AgentOpenResult with AgentOpenedMappable {
  const AgentOpened({required this.claimedTokens});

  /// Context tokens set aside for this agent alone.
  final int claimedTokens;
}

/// Every sequence the loaded model offers is leased.
@MappableClass(discriminatorValue: 'no_capacity')
final class AgentNoCapacity extends AgentOpenResult
    with AgentNoCapacityMappable {
  const AgentNoCapacity();
}

/// A sequence is free but the context left over is too small to claim.
@MappableClass(discriminatorValue: 'insufficient_claim')
final class AgentInsufficientClaim extends AgentOpenResult
    with AgentInsufficientClaimMappable {
  const AgentInsufficientClaim();
}
