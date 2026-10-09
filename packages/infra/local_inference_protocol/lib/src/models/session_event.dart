import 'package:dart_mappable/dart_mappable.dart';
import 'package:local_inference_protocol/src/models/agent_lease.dart';
import 'package:local_inference_protocol/src/models/model_status.dart';

part 'session_event.mapper.dart';

/// One server-sent event on the owner session.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'type')
sealed class SessionEvent with SessionEventMappable {
  const SessionEvent();
}

/// The session is this client's; the token authorizes its lease and model
/// requests.
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  discriminatorValue: 'session_opened',
)
final class SessionOpened extends SessionEvent with SessionOpenedMappable {
  const SessionOpened({required this.ownerToken});

  final String ownerToken;
}

/// How the loaded model's context is divided among the leased agents.
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  discriminatorValue: 'pool_snapshot',
)
final class PoolSnapshotEvent extends SessionEvent
    with PoolSnapshotEventMappable {
  const PoolSnapshotEvent({
    required this.contextSize,
    required this.maxAgents,
    required this.agents,
    this.borrowedTokens = 0,
  });

  final int contextSize;

  final int maxAgents;

  /// Every leased agent, in lease order.
  final List<PoolAgent> agents;

  /// The context claimed by sequences lent to completions that named no
  /// agent, which the agents cannot use until those completions finish.
  final int borrowedTokens;
}

/// One leased agent's share of the context.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class PoolAgent with PoolAgentMappable {
  const PoolAgent({
    required this.id,
    required this.kind,
    required this.claimedTokens,
    required this.usedTokens,
  });

  final String id;

  final AgentLeaseKind kind;

  /// Context tokens set aside for this agent alone.
  final int claimedTokens;

  /// Tokens resident in this agent's sequence.
  final int usedTokens;
}

/// The model's status changed.
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  discriminatorValue: 'model_status',
)
final class ModelStatusEvent extends SessionEvent
    with ModelStatusEventMappable {
  const ModelStatusEvent({required this.status});

  final ModelStatus status;
}
