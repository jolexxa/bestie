import 'package:agent_provider_protocol/src/agent.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of creating the primary agent.
sealed class StartPrimaryResult {
  const StartPrimaryResult();
}

final class StartPrimaryStarted extends StartPrimaryResult {
  const StartPrimaryStarted(this.agent);

  final Agent agent;
}

final class StartPrimaryRejected extends StartPrimaryResult {
  const StartPrimaryRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
