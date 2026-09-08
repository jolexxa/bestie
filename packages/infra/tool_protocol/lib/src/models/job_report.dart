import 'package:tool_protocol/src/models/job.dart';

/// A background job's settled outcome, addressed to the agent that started it.
final class JobReport {
  const JobReport({
    required this.conversationId,
    required this.agentId,
    required this.callId,
    required this.toolName,
    required this.arguments,
    required this.outcome,
    required this.outstanding,
  });

  final String conversationId;
  final String agentId;
  final String callId;
  final String toolName;

  /// The originating call's arguments, so a consumer can label the report.
  final Map<String, Object?> arguments;

  final JobOutcome outcome;
  final int outstanding;
}
