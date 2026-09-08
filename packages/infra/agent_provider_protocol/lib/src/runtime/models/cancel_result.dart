import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of cancelling an agent's current run.
sealed class CancelResult {
  const CancelResult();
}

final class CancelAccepted extends CancelResult {
  const CancelAccepted();
}

final class CancelRejected extends CancelResult {
  const CancelRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
