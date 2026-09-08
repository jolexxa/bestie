import 'package:agent_provider_protocol/src/agent.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_rejection_reason.dart';

/// Outcome of creating a subagent.
sealed class StartSubagentResult {
  const StartSubagentResult();
}

final class StartSubagentStarted extends StartSubagentResult {
  const StartSubagentStarted(this.agent);

  final Agent agent;
}

final class StartSubagentRejected extends StartSubagentResult {
  const StartSubagentRejected({required this.reason, this.message});

  final AgentRuntimeRejectionReason reason;
  final String? message;
}
