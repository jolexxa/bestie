import 'package:agent_runtime/src/turn/agent_turn_data.dart';
import 'package:completion_protocol/completion_protocol.dart';

/// Work the owning agent performs on the turn's behalf. Everything else the
/// turn outputs is an `AgentRuntimeEvent` for the event stream.
sealed class AgentTurnWork {
  const AgentTurnWork();
}

/// Open a completion stream and feed its events back tagged
/// [completionId].
final class CompletionRequested extends AgentTurnWork {
  const CompletionRequested({
    required this.completionId,
    required this.request,
  });

  final int completionId;
  final CompletionRequest request;
}

/// The agent's token usage changed; the runtime republishes its pool.
final class UsageChanged extends AgentTurnWork {
  const UsageChanged(this.usage);

  final AgentUsage usage;
}

/// A completion reported what it cost, in the provider's currency.
final class SpendReported extends AgentTurnWork {
  const SpendReported(this.cost);

  final double cost;
}
