import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:intentions/intentions.dart';

/// The glyph and accent a timeline row wears for its status, derived once so
/// the chat stub and the details header you open cannot disagree.
@model
final class ActivityBadge {
  const ActivityBadge({required this.glyph, required this.accent});

  final String glyph;
  final DetailAccent accent;

  /// The badge for [item], or null for rows that carry no status of their
  /// own — plain messages, notices, model cards.
  static ActivityBadge? fromTimelineItem(TimelineItem item) => switch (item) {
    ActivityStubTimelineItem(running: true) => const ActivityBadge(
      glyph: '·',
      accent: DetailAccent.running,
    ),
    BackgroundJobTimelineItem(settled: null) => const ActivityBadge(
      glyph: '●',
      accent: DetailAccent.running,
    ),
    BackgroundJobTimelineItem(:final settled) => _outcome(
      succeeded: settled!.succeeded,
    ),
    JobReportTimelineItem(:final report) => _outcome(
      succeeded: report.succeeded,
    ),
    ToolActivityTimelineItem(:final result) => switch (result) {
      ToolCallCanceled() || null => const ActivityBadge(
        glyph: '⚠',
        accent: DetailAccent.muted,
      ),
      ToolCallFailed() => _outcome(succeeded: false),
      ToolCallSucceeded() => _outcome(succeeded: true),
    },
    ReasoningStubTimelineItem() => const ActivityBadge(
      glyph: '·',
      accent: DetailAccent.muted,
    ),
    ToolCallDraftTimelineItem() => const ActivityBadge(
      glyph: '·',
      accent: DetailAccent.running,
    ),
    _ => null,
  };
}

ActivityBadge _outcome({required bool succeeded}) => succeeded
    ? const ActivityBadge(glyph: '✓', accent: DetailAccent.success)
    : const ActivityBadge(glyph: '✗', accent: DetailAccent.error);
