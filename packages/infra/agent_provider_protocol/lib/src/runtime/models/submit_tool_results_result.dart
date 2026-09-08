import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of submitting tool results to an agent waiting on them.
sealed class SubmitToolResultsResult {
  const SubmitToolResultsResult();
}

final class SubmitToolResultsAccepted extends SubmitToolResultsResult {
  const SubmitToolResultsAccepted();
}

final class SubmitToolResultsRejected extends SubmitToolResultsResult {
  const SubmitToolResultsRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
