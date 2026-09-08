import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentRunFailureReason;
import 'package:intentions/intentions.dart';

/// Typed record of a failed turn, surfaced on the idle conversation state.
///
/// Carries the agent runtime's [AgentRunFailureReason] so the view can
/// branch on the failure kind rather than parsing a stringified message.
@model
final class TurnFailure {
  const TurnFailure({required this.reason, this.message});

  final AgentRunFailureReason reason;
  final String? message;

  /// Short human-readable summary for system alerts.
  String get summary {
    final detail = message;
    if (detail == null || detail.isEmpty) return reason.name;
    return '${reason.name}: $detail';
  }
}
