import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show BlockStat, Role, TranscriptBlock, TranscriptParagraphBlock;
import 'package:agent_repository/src/conversation/job_in_background.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:agent_repository/src/message/model_snapshot.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show ToolCall, ToolCallResponse;

/// View-facing timeline element for the chat list.
@model
sealed class TimelineItem {
  const TimelineItem();

  String get id;

  /// Extra selectable sub-slots beneath this row, on top of the row
  /// itself. Default 0 — the row is selectable as a single slot.
  ///
  /// A row with `N` selectable children (e.g. a message with `N`
  /// attachments) returns `N`, contributing `1 + N` total cursor
  /// positions: `subIndex = 0` is the row itself, `subIndex = 1..N`
  /// address the children in their natural order.
  int get childSelectionCount => 0;
}

/// A live timeline row that can display prompt-prefill progress while the model
/// reprocesses context for it. Unifies every prefill-bar host — the pending
/// response stub and the in-flight compaction marker — so the view renders the
/// bar through a single path.
mixin Prefillable {
  /// Prompt prefill progress `[0, 1)`, or null when not reprocessing.
  double? get prefillFraction;
}

/// A single chat row carrying transcript blocks: one user entry, or a
/// whole turn's assistant and tool entries merged by `responseId`.
@model
final class MessageTimelineItem extends TimelineItem {
  const MessageTimelineItem({
    required this.id,
    required this.role,
    required this.timestamp,
    required this.blocks,
    this.responseId,
    this.running = false,
  });

  @override
  final String id;

  /// Message role.
  final Role role;

  final DateTime timestamp;
  final int? responseId;
  final List<TranscriptBlock> blocks;

  /// True while [blocks] are still being appended to.
  final bool running;

  /// Convenience: concatenates all paragraph blocks.
  String get text =>
      blocks.whereType<TranscriptParagraphBlock>().map((b) => b.text).join();
}

/// A single unit of assistant activity within a turn — one reasoning run or
/// one tool call — shown as a one-line stub in the chat list, with its full
/// content in the details pane on selection.
@model
sealed class ActivityStubTimelineItem extends TimelineItem {
  const ActivityStubTimelineItem({
    required this.id,
    required this.timestamp,
    this.running = false,
  });

  @override
  final String id;
  final DateTime timestamp;

  /// True while still in flight — live turns only.
  final bool running;
}

/// One reasoning run, shown as a `Thought for …` stub.
@model
final class ReasoningStubTimelineItem extends ActivityStubTimelineItem
    with Prefillable {
  const ReasoningStubTimelineItem({
    required super.id,
    required super.timestamp,
    required this.text,
    this.stat,
    super.running,
    this.prefillFraction,
  });

  /// The coalesced reasoning text.
  final String text;

  /// Timing and token stats for the reasoning run.
  final BlockStat? stat;

  @override
  final double? prefillFraction;
}

/// One tool call paired with its result.
@model
final class ToolActivityTimelineItem extends ActivityStubTimelineItem {
  const ToolActivityTimelineItem({
    required super.id,
    required super.timestamp,
    required this.toolCall,
    this.result,
    this.labelTemplate,
    super.running,
  });

  final ToolCall toolCall;

  /// The call's terminal response, once it has landed.
  final ToolCallResponse? result;

  /// Denormalized label template (e.g. `'Read ${path:basename}'`), interpolated
  /// against [toolCall]'s arguments. Null falls back to the tool name.
  final String? labelTemplate;
}

/// One call whose work carried on after it answered, shown as a stub that
/// reads as in progress until its report lands.
@model
final class BackgroundJobTimelineItem extends ActivityStubTimelineItem {
  const BackgroundJobTimelineItem({
    required super.id,
    required super.timestamp,
    required this.job,
    this.settled,
  });

  final JobInBackground job;

  /// The report that finished this job off, or null while it is still going.
  final DeliveredJobReport? settled;
}

/// The frontier row while the model is still writing a tool call.
@model
final class ToolCallDraftTimelineItem extends TimelineItem {
  const ToolCallDraftTimelineItem({required this.id, required this.timestamp});

  @override
  final String id;
  final DateTime timestamp;
}

/// A UI-only system notice row (welcome / reset / alert lines).
@model
final class NoticeTimelineItem extends TimelineItem {
  const NoticeTimelineItem({
    required this.id,
    required this.timestamp,
    required this.text,
  });

  @override
  final String id;
  final DateTime timestamp;
  final String text;
}

/// A model card row: a persisted model change, or the live runtime model
/// status.
@model
final class ModelCardTimelineItem extends TimelineItem {
  const ModelCardTimelineItem({
    required this.id,
    required this.timestamp,
    required this.card,
  });

  @override
  final String id;
  final DateTime timestamp;
  final ModelSnapshot card;
}

/// The visible compaction frontier marker.
@model
final class CompactionMarkerTimelineItem extends TimelineItem with Prefillable {
  const CompactionMarkerTimelineItem({
    required this.id,
    required this.timestamp,
    required this.summary,
    required this.tokensBefore,
    this.summaryReasoning = '',
    this.running = false,
    this.prefillFraction,
  });

  @override
  final String id;
  final DateTime timestamp;

  /// The rolling memory note shown to the model. Streams in while [running].
  final String summary;

  /// The summarizer's reasoning-channel stream, captured live while [running].
  /// Empty for committed markers — reasoning is not persisted with the fold.
  final String summaryReasoning;

  /// Real prefix-token cost of everything folded into this summary.
  final int tokensBefore;

  /// True while the compaction is still folding — summary streaming, context
  /// reprocessing (live turns only). A committed marker is never running.
  final bool running;

  @override
  final double? prefillFraction;
}

/// One settled background job report, shown as a one-line stub in the chat
/// list.
@model
final class JobReportTimelineItem extends TimelineItem {
  const JobReportTimelineItem({
    required this.id,
    required this.timestamp,
    required this.report,
  });

  @override
  final String id;
  final DateTime timestamp;
  final DeliveredJobReport report;
}
