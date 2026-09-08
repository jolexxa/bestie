import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

part 'agent_session_data.mapper.dart';

/// The persisted projection of an `AgentTranscript`: one agent's history
/// within a conversation, as written to disk.
@model
@MappableClass()
final class AgentSessionData with AgentSessionDataMappable {
  const AgentSessionData({
    required this.conversationId,
    required this.agentId,
    required this.workingDirectory,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
  });

  final String conversationId;
  final String agentId;

  /// Where the app was running when the conversation began.
  final String workingDirectory;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationEntry> entries;
}
