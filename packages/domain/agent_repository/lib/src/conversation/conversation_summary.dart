import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/conversation/agent_session_data.dart';
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// What a saved conversation looks like from the outside: enough to list it,
/// label it, and search it without holding the whole transcript.
@model
@immutable
final class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.workingDirectory,
    required this.createdAt,
    required this.updatedAt,
    required this.firstUserMessage,
    required this.searchText,
  });

  /// Derives the summary from the primary agent's persisted session.
  factory ConversationSummary.fromSessionData(AgentSessionData data) {
    final searchable = <String>[];
    String? firstUserMessage;
    for (final entry in data.entries) {
      switch (entry) {
        case MessageEntry(:final entry):
          final text = _paragraphText(entry);
          if (text.isEmpty) continue;
          if (entry.role == Role.user) firstUserMessage ??= text;
          if (entry.role == Role.user || entry.role == Role.assistant) {
            searchable.add(text);
          }
        case CompactionEntry(:final summary):
          searchable.add(summary);
        case ModelChangeEntry() ||
            NoticeEntry() ||
            JobReportEntry() ||
            JobBackgroundedEntry():
          continue;
      }
    }
    return ConversationSummary(
      id: data.conversationId,
      workingDirectory: data.workingDirectory,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      firstUserMessage: firstUserMessage ?? '',
      searchText: searchable.join('\n').toLowerCase(),
    );
  }

  final String id;
  final String workingDirectory;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The first thing the user said, or empty when they never said anything.
  final String firstUserMessage;

  /// Lowercased prose of the conversation: what the user and assistant said
  /// and any compaction summaries. Tool output and reasoning are left out.
  final String searchText;

  bool get hasUserMessage => firstUserMessage.isNotEmpty;

  static String _paragraphText(TranscriptEntry entry) => [
    for (final block in entry.blocks)
      if (block is TranscriptParagraphBlock) block.text,
  ].join('\n').trim();
}
