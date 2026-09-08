import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:agent_repository/src/message/timeline_item.dart';
import 'package:intentions/intentions.dart';

/// A read-only view of one agent's history within a conversation: the
/// persisted append-only entry log, plus the two views derived from it — a
/// token-stable transcript for the agent and a timeline for the chat list.
///
/// Reading history is everyone's business; changing it is not. Mutation and
/// persistence live together behind `AgentJournal`, which the repository owns
/// and nothing above it can name.
@model
abstract interface class AgentTranscript {
  /// The conversation this agent belongs to. Shared with every other agent in
  /// it, including the one that spawned this agent.
  String get conversationId;

  /// Which agent of that conversation this is.
  String get agentId;

  /// Where the app was running when the conversation began.
  String get workingDirectory;

  DateTime get createdAt;

  DateTime get updatedAt;

  /// The persisted entry collection.
  List<ConversationEntry> get entries;

  /// Token-stable transcript fed to `AgentProvider.startPrimary`.
  Transcript get transcript;

  /// Committed chat rows for the view.
  List<TimelineItem> get timeline;

  /// Whether anything has been committed yet.
  bool get isEmpty;

  /// Whether anything since the last compaction could be folded away.
  bool get hasFoldableHistory;

  /// The text of the user message entry [entryId], or null when no user
  /// message carries that id.
  String? userMessageText(String entryId);
}
