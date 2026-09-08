import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of asking an agent to run another turn.
sealed class RunResult {
  const RunResult();
}

final class RunAccepted extends RunResult {
  const RunAccepted();
}

final class RunRejected extends RunResult {
  const RunRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
