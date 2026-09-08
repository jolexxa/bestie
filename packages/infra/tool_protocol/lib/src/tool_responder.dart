import 'package:tool_protocol/src/models/job.dart';
import 'package:tool_protocol/src/tool_definitions.dart';

/// Feature-level owner of the jobs started by its tool vocabulary.
abstract interface class ToolResponder {
  ToolDefinitions get definitions;

  Future<Job> respond(ToolCallInvocation invocation);
}

/// Immutable context for one responder invocation.
final class ToolCallInvocation {
  const ToolCallInvocation({
    required this.conversationId,
    required this.agentId,
    required this.callId,
    required this.toolName,
    required this.outputPath,
    required this.maxOutputChars,
    required this.arguments,
  });

  final String conversationId;
  final String agentId;
  final String callId;
  final String toolName;
  final String outputPath;

  /// Tool call response cap. Going over fails the call.
  final int maxOutputChars;

  final Map<String, Object?> arguments;
}
