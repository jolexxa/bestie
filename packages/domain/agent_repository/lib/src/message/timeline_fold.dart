import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        BlockStat,
        Role,
        TranscriptBlock,
        TranscriptParagraphBlock,
        TranscriptReasoningBlock,
        TranscriptToolCallBlock,
        TranscriptToolCallResponseBlock;
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:agent_repository/src/message/model_snapshot.dart';
import 'package:agent_repository/src/message/timeline_item.dart';
import 'package:tool_protocol/tool_protocol.dart' show ToolCallResponse;

/// Folds conversation entries into chat rows. User entries become rows; an
/// assistant turn (its assistant + tool entries, merged by `responseId`) is
/// split into ordered activity stubs — one [ReasoningStubTimelineItem] per
/// reasoning run, one [ToolActivityTimelineItem] per tool call, with a
/// [BackgroundJobTimelineItem] tucked under the call whose work carried on —
/// followed by the answer as a [MessageTimelineItem]. Other UI-only entries
/// become their own item kinds.
///
/// Pass [live] `true` for the in-flight turn so unresolved tool calls read as
/// running. Pass [tailOpen] `false` when something the fold cannot see — a
/// tool call still being drafted — already follows the last block, so the
/// trailing reasoning run and answer read as settled.
List<TimelineItem> foldTimeline(
  Iterable<ConversationEntry> entries, {
  bool live = false,
  bool tailOpen = true,
}) {
  final reports = <String, DeliveredJobReport>{
    for (final entry in entries)
      if (entry is JobReportEntry)
        for (final report in entry.reports) report.callId: report,
  };
  final items = <TimelineItem>[];
  _Turn? open;

  void flush() {
    if (open == null) return;
    _splitTurn(
      open!,
      live: live,
      tailOpen: tailOpen,
      reports: reports,
      into: items,
    );
    open = null;
  }

  for (final entry in entries) {
    switch (entry) {
      case MessageEntry():
        switch (entry.entry.role) {
          case Role.user:
            flush();
            items.add(
              MessageTimelineItem(
                id: entry.id,
                role: Role.user,
                timestamp: entry.timestamp,
                responseId: entry.responseId,
                blocks: entry.entry.blocks,
              ),
            );
          case Role.assistant || Role.tool:
            if (open != null && open!.responseId == entry.responseId) {
              open!.blocks.addAll(entry.entry.blocks);
            } else {
              flush();
              open = _Turn(
                id: entry.id,
                timestamp: entry.timestamp,
                responseId: entry.responseId,
                blocks: [...entry.entry.blocks],
              );
            }
          case Role.system:
            break; // Summary checkpoints are CompactionEntry, not MessageEntry.
        }
      case NoticeEntry():
        flush();
        items.add(
          NoticeTimelineItem(
            id: entry.id,
            timestamp: entry.timestamp,
            text: entry.text,
          ),
        );
      case ModelChangeEntry():
        flush();
        items.add(
          ModelCardTimelineItem(
            id: entry.id,
            timestamp: entry.timestamp,
            card: ModelSnapshot(
              modelId: entry.modelId,
              displayName: entry.displayName,
              contextSize: entry.contextSize,
              provider: entry.provider,
              phase: ModelCardPhase.ready,
            ),
          ),
        );
      case CompactionEntry():
        flush();
        items.add(
          CompactionMarkerTimelineItem(
            id: entry.id,
            timestamp: entry.timestamp,
            summary: entry.summary,
            tokensBefore: entry.tokensBefore,
          ),
        );
      case JobBackgroundedEntry():
        if (open != null) {
          open!.jobs.add(entry);
        } else {
          items.add(_backgroundJob(entry, reports));
        }
      case JobReportEntry():
        flush();
        for (final (i, report) in entry.reports.indexed) {
          items.add(
            JobReportTimelineItem(
              id: '${entry.id}#report-$i',
              timestamp: entry.timestamp,
              report: report,
            ),
          );
        }
    }
  }
  flush();
  return items;
}

/// Splits an assistant turn's blocks into ordered stub items, appending to
/// [into]. Contiguous reasoning coalesces into one stub; each tool call folds
/// in its result (matched by id) and is followed by its backgrounded job, if
/// any; the remaining blocks form the answer row. Jobs no call in the turn
/// claims trail it.
void _splitTurn(
  _Turn turn, {
  required bool live,
  required bool tailOpen,
  required Map<String, DeliveredJobReport> reports,
  required List<TimelineItem> into,
}) {
  final responses = <String, ToolCallResponse>{
    for (final b in turn.blocks)
      if (b is TranscriptToolCallResponseBlock) b.response.callId: b.response,
  };
  final jobsByCall = <String, JobBackgroundedEntry>{
    for (final job in turn.jobs) job.job.callId: job,
  };

  final reasoning = <TranscriptReasoningBlock>[];
  final answer = <TranscriptBlock>[];
  var reasoningSeq = 0;
  var answerSeq = 0;

  // A reasoning run flushed mid-turn is settled; only one flushed at the very
  // end (nothing after it) is still running.
  void flushReasoning({required bool tail}) {
    final text = StringBuffer();
    BlockStat? stat;
    for (final r in reasoning) {
      // Drop whitespace-only reasoning blocks
      if (r.text.trim().isEmpty) continue;
      text.write(r.text);
      stat = _mergeStats(stat, r.stat);
    }
    reasoning.clear();
    if (text.isEmpty) return;
    into.add(
      ReasoningStubTimelineItem(
        id: '${turn.id}#reasoning-${reasoningSeq++}',
        timestamp: turn.timestamp,
        text: text.toString(),
        stat: stat,
        running: live && tail,
      ),
    );
  }

  // An answer flushed mid-turn is settled.
  void flushAnswer({required bool tail}) {
    // drop whitespace-only paragraphs rather than render a blank assistant row.
    final visible = answer
        .where(
          (block) =>
              block is! TranscriptParagraphBlock ||
              block.text.trim().isNotEmpty,
        )
        .toList();
    answer.clear();
    if (visible.isEmpty) return;
    into.add(
      MessageTimelineItem(
        id: '${turn.id}#answer-${answerSeq++}',
        role: Role.assistant,
        timestamp: turn.timestamp,
        responseId: turn.responseId,
        blocks: visible,
        running: live && tail,
      ),
    );
  }

  for (final block in turn.blocks) {
    switch (block) {
      case TranscriptReasoningBlock():
        flushAnswer(tail: false);
        reasoning.add(block);
      case TranscriptToolCallBlock():
        flushReasoning(tail: false);
        flushAnswer(tail: false);
        final result = responses[block.toolCall.id];
        into.add(
          ToolActivityTimelineItem(
            id: '${turn.id}#tool-${block.toolCall.id}',
            timestamp: turn.timestamp,
            toolCall: block.toolCall,
            result: result,
            labelTemplate: block.labelTemplate,
            running: live && result == null,
          ),
        );
        final job = jobsByCall.remove(block.toolCall.id);
        if (job != null) into.add(_backgroundJob(job, reports));
      case TranscriptToolCallResponseBlock():
        break; // Consumed into its tool activity above.
      default:
        flushReasoning(tail: false);
        answer.add(block);
    }
  }
  flushReasoning(tail: tailOpen);
  flushAnswer(tail: tailOpen);
  for (final job in jobsByCall.values) {
    into.add(_backgroundJob(job, reports));
  }
}

BackgroundJobTimelineItem _backgroundJob(
  JobBackgroundedEntry entry,
  Map<String, DeliveredJobReport> reports,
) => BackgroundJobTimelineItem(
  id: entry.id,
  timestamp: entry.timestamp,
  job: entry.job,
  settled: reports[entry.job.callId],
);

BlockStat? _mergeStats(BlockStat? a, BlockStat? b) {
  if (a == null) return b;
  if (b == null) return a;
  final tokens = (a.tokenCount ?? 0) + (b.tokenCount ?? 0);
  return BlockStat(
    startedAt: a.startedAt.isBefore(b.startedAt) ? a.startedAt : b.startedAt,
    endedAt: a.endedAt.isAfter(b.endedAt) ? a.endedAt : b.endedAt,
    tokenCount: tokens > 0 ? tokens : null,
  );
}

class _Turn {
  _Turn({
    required this.id,
    required this.timestamp,
    required this.responseId,
    required this.blocks,
  });

  final String id;
  final DateTime timestamp;
  final int? responseId;
  final List<TranscriptBlock> blocks;

  /// Calls of this turn whose work carried on past their answer.
  final List<JobBackgroundedEntry> jobs = [];
}
