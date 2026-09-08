import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of disposing a single agent (releasing its lease and record).
///
/// A running agent is rejected with [AgentRuntimeRejectionReason.busy]; cancel
/// it first. Agents otherwise live until disposed on the provider.
sealed class DisposeAgentResult {
  const DisposeAgentResult();
}

final class DisposeAgentDisposed extends DisposeAgentResult {
  const DisposeAgentDisposed();
}

final class DisposeAgentRejected extends DisposeAgentResult {
  const DisposeAgentRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
