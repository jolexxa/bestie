/// A job that outlived its call and kept running, addressed to the agent that
/// started it.
final class JobBackgrounded {
  const JobBackgrounded({
    required this.conversationId,
    required this.agentId,
    required this.callId,
    required this.toolName,
    required this.arguments,
  });

  final String conversationId;
  final String agentId;
  final String callId;
  final String toolName;

  /// The originating call's arguments, so a consumer can label the job.
  final Map<String, Object?> arguments;
}
