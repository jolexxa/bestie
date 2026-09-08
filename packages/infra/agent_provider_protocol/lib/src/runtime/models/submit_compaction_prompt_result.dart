import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of submitting compaction prompt content to an agent waiting on it.
sealed class SubmitCompactionPromptResult {
  const SubmitCompactionPromptResult();
}

final class SubmitCompactionPromptAccepted
    extends SubmitCompactionPromptResult {
  const SubmitCompactionPromptAccepted();
}

final class SubmitCompactionPromptRejected
    extends SubmitCompactionPromptResult {
  const SubmitCompactionPromptRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
