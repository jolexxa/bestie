import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        AgentCancelled,
        AgentCompactionCompleted,
        AgentCompactionFailed,
        AgentCompactionOutcome,
        AgentCompactionStarted,
        AgentCompactionSucceeded,
        AgentCompleted,
        AgentFailed,
        AgentHandle,
        AgentNeedsCompactionPrompt,
        AgentNeedsToolResults,
        AgentPrefillProgress,
        AgentReasoningDelta,
        AgentRunFailureReason,
        AgentRuntimeEvent,
        AgentStarted,
        AgentSummaryDelta,
        AgentSummaryReasoningDelta,
        AgentTextDelta,
        AgentToolCallEmitted,
        AgentToolCallStarted,
        AgentToolResponseApplied,
        AgentUpdated,
        BlockStat,
        Role,
        ToolCall,
        ToolCallResponse,
        Transcript,
        TranscriptBlock,
        TranscriptBlockId,
        TranscriptEntry,
        TranscriptEntryId,
        TranscriptParagraphBlock,
        TranscriptReasoningBlock,
        TranscriptToolCallBlock,
        TranscriptToolCallResponseBlock;
import 'package:agent_repository/src/agent/agent_session.dart';
import 'package:agent_repository/src/turn/turn_activity.dart';
import 'package:intentions/intentions.dart';

/// Outcome of feeding one [AgentRuntimeEvent] to a [TurnProjector].
@model
sealed class TurnProjection {
  const TurnProjection();
}

/// The active turn advanced; the repository should re-emit state.
@model
final class TurnProgressed extends TurnProjection {
  const TurnProgressed();
}

/// A tool call surfaced from the model's stream. The repository starts
/// executing it eagerly; the later [TurnNeedsTools] barrier joins the results.
@model
final class TurnToolCallEmitted extends TurnProjection {
  const TurnToolCallEmitted(this.toolCall);
  final ToolCall toolCall;
}

/// The agent finished generating and paused for tool results. The repository
/// joins the already-running tools and submits them back through [agent].
@model
final class TurnNeedsTools extends TurnProjection {
  const TurnNeedsTools(this.agent, this.toolCalls);
  final AgentHandle agent;
  final List<ToolCall> toolCalls;
}

/// The agent's compaction is paused waiting for summarizer prompt content.
@model
final class TurnNeedsCompactionPrompt extends TurnProjection {
  const TurnNeedsCompactionPrompt(this.agent);
  final AgentHandle agent;
}

/// The turn finished successfully; commit and persist.
@model
final class TurnCompletedProjection extends TurnProjection {
  const TurnCompletedProjection();
}

/// The turn was cancelled; commit the partial turn and idle.
@model
final class TurnCancelledProjection extends TurnProjection {
  const TurnCancelledProjection();
}

/// The turn failed; surface [reason]/[message] and idle.
@model
final class TurnFailedProjection extends TurnProjection {
  const TurnFailedProjection(this.reason, this.message);
  final AgentRunFailureReason reason;
  final String? message;
}

/// An in-isolate compaction pass produced a rolling [summary], folding
/// [tokensBefore] tokens of prefix into rolling memory.
@model
final class CompactionCommitted extends TurnProjection {
  const CompactionCommitted(this.summary, this.tokensBefore);
  final String summary;
  final int tokensBefore;
}

/// The event has no bearing on chat state.
@model
final class TurnProjectionIgnored extends TurnProjection {
  const TurnProjectionIgnored();
}

/// Mirrors one agent's transcript across a single in-progress turn.
@PartOf(AgentSession)
final class TurnProjector {
  int _responseId = 0;
  bool _active = false;
  final List<TranscriptEntry> _entries = [];
  int _turnStart = 0;
  final List<String> _alerts = [];
  String? _liveSummary;
  String? _liveSummaryReasoning;
  double? _prefillFraction;
  TurnActivity _activity = TurnActivity.thinking;
  int? _compactionTokensBefore;

  int get responseId => _responseId;
  bool get active => _active;
  List<String> get alerts => _alerts;
  String? get liveSummary => _liveSummary;

  /// The summarizer's reasoning-channel stream for the in-flight compaction.
  /// Non-null once the model emits analysis tokens; distinct from
  /// [liveSummary], which is the final-channel summary output.
  String? get liveSummaryReasoning => _liveSummaryReasoning;

  /// What the turn is doing right now, folded from the events so far.
  TurnActivity get activity => _activity;

  /// The pre-fold used-token count of the in-flight compaction, if any.
  int? get compactionTokensBefore => _compactionTokensBefore;

  /// Prompt prefill progress `[0, 1)`, non-null only while the model is still
  /// reprocessing the prompt with nothing to stream yet.
  double? get prefillFraction => _prefillFraction;

  /// This turn's entries: everything the agent has streamed or handed back
  /// since the history the turn started from.
  ///
  /// A mirror that came back shorter than that history reads as having
  /// produced nothing rather than throwing — the turn's seed is committed
  /// before the turn runs, so there is nothing here left to rescue.
  List<TranscriptEntry> get turnEntries =>
      _entries.sublist(_turnStart.clamp(0, _entries.length));

  /// Begins a new turn over [base], which already holds everything the turn
  /// answers, so only generations after it commit.
  void begin({
    required int responseId,
    required List<TranscriptEntry> base,
  }) {
    _responseId = responseId;
    _active = true;
    _entries
      ..clear()
      ..addAll(base);
    _turnStart = base.length;
    _alerts.clear();
    _liveSummary = null;
    _liveSummaryReasoning = null;
    _prefillFraction = null;
    _activity = TurnActivity.thinking;
    _compactionTokensBefore = null;
  }

  /// Ends the active turn without consuming a terminal event (manual
  /// cancel). Subsequent events are ignored until the next [begin].
  void endNow() {
    _active = false;
  }

  /// Appends a system alert string to the active turn.
  void addAlert(String text) => _alerts.add(text);

  TurnProjection apply(AgentRuntimeEvent event) {
    if (!_active) return const TurnProjectionIgnored();
    switch (event) {
      case AgentStarted(:final transcript):
        _replaceMirror(transcript);
        return const TurnProgressed();
      case AgentTextDelta(
            :final timestamp,
            :final entryId,
            :final blockId,
            :final text,
          )
          when text.isNotEmpty:
        _prefillFraction = null;
        if (text.trim().isNotEmpty) _activity = TurnActivity.responding;
        _patchText(entryId, blockId, text, at: timestamp, reasoning: false);
        return const TurnProgressed();
      case AgentReasoningDelta(
            :final timestamp,
            :final entryId,
            :final blockId,
            :final text,
          )
          when text.isNotEmpty:
        _prefillFraction = null;
        _activity = TurnActivity.thinking;
        _patchText(entryId, blockId, text, at: timestamp, reasoning: true);
        return const TurnProgressed();
      case AgentToolCallStarted():
        _prefillFraction = null;
        _activity = TurnActivity.draftingToolCall;
        return const TurnProgressed();
      case AgentToolCallEmitted(
        :final timestamp,
        :final entryId,
        :final blockId,
        :final toolCall,
      ):
        _prefillFraction = null;
        _activity = TurnActivity.executingTools;
        _putBlock(
          entryId,
          TranscriptToolCallBlock(
            id: blockId,
            toolCall: toolCall,
            stat: BlockStat(startedAt: timestamp, endedAt: timestamp),
          ),
        );
        return TurnToolCallEmitted(toolCall);
      case AgentSummaryDelta(:final text):
        _prefillFraction = null;
        _liveSummary = '${_liveSummary ?? ''}$text';
        return const TurnProgressed();
      case AgentSummaryReasoningDelta(:final text):
        _prefillFraction = null;
        _liveSummaryReasoning = '${_liveSummaryReasoning ?? ''}$text';
        return const TurnProgressed();
      case AgentPrefillProgress(:final completed, :final total):
        final fraction = total > 0 && completed < total
            ? completed / total
            : null;
        if (_prefillFraction == fraction) return const TurnProjectionIgnored();
        _prefillFraction = fraction;
        return const TurnProgressed();
      case AgentCompactionStarted(:final tokensBefore):
        _activity = TurnActivity.compacting;
        _compactionTokensBefore = tokensBefore;
        return const TurnProgressed();
      case AgentCompactionCompleted(:final outcome):
        return _onCompaction(outcome);
      case AgentNeedsToolResults(:final agent, :final entry, :final toolCalls):
        _upsertEntry(entry);
        return TurnNeedsTools(agent, toolCalls);
      case AgentNeedsCompactionPrompt(:final agent):
        return TurnNeedsCompactionPrompt(agent);
      case AgentToolResponseApplied(
        :final entryId,
        :final blockId,
        :final response,
      ):
        _applyToolResponse(entryId, blockId, response);
        return const TurnProgressed();
      case AgentUpdated(:final transcript):
        _replaceMirror(transcript);
        _activity = TurnActivity.thinking;
        return const TurnProgressed();
      case AgentCompleted(:final transcript):
        _replaceMirror(transcript);
        _active = false;
        return const TurnCompletedProjection();
      case AgentCancelled(:final transcript):
        _replaceMirror(transcript);
        _active = false;
        return const TurnCancelledProjection();
      case AgentFailed(:final reason, :final message):
        _active = false;
        return TurnFailedProjection(reason, message);
      case _:
        return const TurnProjectionIgnored();
    }
  }

  // ── Mirror maintenance ────────────────────────────────

  void _replaceMirror(Transcript transcript) {
    _entries
      ..clear()
      ..addAll(transcript.entries);
  }

  void _upsertEntry(TranscriptEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  TranscriptEntry _ensureEntry(TranscriptEntryId entryId, Role role) {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index >= 0) return _entries[index];
    final entry = TranscriptEntry(id: entryId, role: role, blocks: const []);
    _entries.add(entry);
    return entry;
  }

  void _replaceEntry(TranscriptEntry entry, List<TranscriptBlock> blocks) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    _entries[index] = TranscriptEntry(
      id: entry.id,
      role: entry.role,
      name: entry.name,
      blocks: blocks,
    );
  }

  void _putBlock(TranscriptEntryId entryId, TranscriptBlock block) {
    final entry = _ensureEntry(entryId, Role.assistant);
    final blocks = List.of(entry.blocks);
    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index >= 0) {
      blocks[index] = block;
    } else {
      blocks.add(block);
    }
    _replaceEntry(entry, blocks);
  }

  void _patchText(
    TranscriptEntryId entryId,
    TranscriptBlockId blockId,
    String delta, {
    required DateTime at,
    required bool reasoning,
  }) {
    final entry = _ensureEntry(entryId, Role.assistant);
    final existing = entry.blocks
        .whereType<TranscriptBlock>()
        .where((b) => b.id == blockId)
        .firstOrNull;
    final text = switch (existing) {
      TranscriptParagraphBlock(:final text) => '$text$delta',
      TranscriptReasoningBlock(:final text) => '$text$delta',
      _ => delta,
    };
    final stat = BlockStat(
      startedAt: existing?.stat?.startedAt ?? at,
      endedAt: at,
    );
    _putBlock(
      entryId,
      reasoning
          ? TranscriptReasoningBlock(id: blockId, text: text, stat: stat)
          : TranscriptParagraphBlock(id: blockId, text: text, stat: stat),
    );
  }

  void _applyToolResponse(
    TranscriptEntryId entryId,
    TranscriptBlockId blockId,
    ToolCallResponse response,
  ) {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index < 0) {
      _entries.add(
        TranscriptEntry(
          id: entryId,
          role: Role.tool,
          name: response.toolName,
          blocks: [
            TranscriptToolCallResponseBlock(id: blockId, response: response),
          ],
        ),
      );
    } else {
      _putBlock(
        entryId,
        TranscriptToolCallResponseBlock(id: blockId, response: response),
      );
    }
  }

  TurnProjection _onCompaction(AgentCompactionOutcome outcome) {
    final tokensBefore = _compactionTokensBefore ?? 0;
    _liveSummary = null;
    _liveSummaryReasoning = null;
    _activity = TurnActivity.thinking;
    _compactionTokensBefore = null;
    _prefillFraction = null;
    return switch (outcome) {
      AgentCompactionSucceeded(:final summary) => CompactionCommitted(
        summary,
        tokensBefore,
      ),
      AgentCompactionFailed() => const TurnProgressed(),
    };
  }
}
