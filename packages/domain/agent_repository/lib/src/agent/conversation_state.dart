import 'package:agent_repository/src/message/timeline_item.dart';
import 'package:agent_repository/src/turn/turn_activity.dart';
import 'package:agent_repository/src/turn/turn_failure.dart';
import 'package:intentions/intentions.dart';

/// External-facing lifecycle phase surfaced on every [ConversationState]
/// emission.
@model
enum ConversationPhase {
  /// No turn running. Submissions accepted.
  idle,

  /// A user-submitted turn is streaming through the agent session.
  turnInFlight,
}

/// Reactive state emitted by an agent session.
@model
sealed class ConversationState {
  const ConversationState();

  /// Chat rows: committed history plus, mid-turn, the live rows.
  List<TimelineItem> get timelineItems;

  /// The current lifecycle phase.
  ConversationPhase get conversationPhase;
}

/// No active turn. Ready for a new message.
@model
final class ConversationIdle extends ConversationState {
  const ConversationIdle({
    required this.timelineItems,
    required this.conversationPhase,
    this.failure,
  });

  @override
  final List<TimelineItem> timelineItems;

  @override
  final ConversationPhase conversationPhase;

  /// Non-null if the previous turn failed.
  final TurnFailure? failure;
}

/// A turn is in progress.
@model
final class TurnInProgress extends ConversationState {
  const TurnInProgress({
    required this.timelineItems,
    required this.conversationPhase,
    required this.activity,
    this.reasoningSnippet,
  });

  @override
  final List<TimelineItem> timelineItems;

  @override
  final ConversationPhase conversationPhase;

  /// What the turn is doing right now. While compacting, the streaming summary
  /// and prefill progress live on the in-flight [CompactionMarkerTimelineItem].
  final TurnActivity activity;

  /// A one-line snippet of the latest lexed reasoning block, shown live in the
  /// chat "thinking…" stub. Ground truth — not an LLM summary.
  final String? reasoningSnippet;
}
