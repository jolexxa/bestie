import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/agent/agent_repository.dart';
import 'package:agent_repository/src/agent/agent_session_id.dart';
import 'package:agent_repository/src/agent/conversation_state.dart';
import 'package:agent_repository/src/conversation/agent_journal.dart';
import 'package:agent_repository/src/conversation/agent_transcript.dart';
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:agent_repository/src/conversation/job_in_background.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:agent_repository/src/message/model_snapshot.dart';
import 'package:agent_repository/src/message/timeline_fold.dart';
import 'package:agent_repository/src/message/timeline_item.dart';
import 'package:agent_repository/src/turn/interrupted_tool_reconciler.dart';
import 'package:agent_repository/src/turn/pending_tool_calls.dart';
import 'package:agent_repository/src/turn/tool_label_denormalizer.dart';
import 'package:agent_repository/src/turn/turn_activity.dart';
import 'package:agent_repository/src/turn/turn_failure.dart';
import 'package:agent_repository/src/turn/turn_options.dart';
import 'package:agent_repository/src/turn/turn_projector.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:prompt_builder/prompt_builder.dart'
    show CompactionPromptContentBuilder;
import 'package:tool_protocol/tool_protocol.dart';
import 'package:uuid/uuid.dart';

/// A stateful, reactive owner of one conversation, projecting it as a
/// [ConversationState] stream that higher layers subscribe to directly.
@model
@PartOf(AgentRepository)
abstract class AgentSession {
  AgentSession._({
    required this.id,
    required this.compactionRatio,
    required this.maxOutputChars,
    required AgentJournal journal,
    required int? contextSize,
    required PendingToolCalls tools,
  }) : _journal = journal,
       _contextSize = contextSize,
       _tools = tools;

  /// A placeholder for windows without a live agent. Holds and persists
  /// conversation content and emits state, but cannot run turns.
  factory AgentSession.placeholder({
    required AgentSessionId id,
    required double compactionRatio,
    required int maxOutputChars,
    required AgentJournal journal,
    required int? contextSize,
    required PendingToolCalls tools,
  }) = _PlaceholderAgentSession;

  /// A live session driving a ready [agent], starting out under [options].
  factory AgentSession.live({
    required AgentSessionId id,
    required Agent agent,
    required TurnOptions options,
    required double compactionRatio,
    required int maxOutputChars,
    required AgentJournal journal,
    required int? contextSize,
    required PendingToolCalls tools,
    required ToolDefinitions toolDefinitions,
    required CompactionPromptContentBuilder compactionPromptContentBuilder,
  }) = _AgentSession;

  /// This session's id within the repository.
  final AgentSessionId id;

  final int? _contextSize;

  /// Holds this session's outstanding tool calls, filing spilled output under
  /// the conversation currently loaded. Replaced whenever that conversation is.
  PendingToolCalls _tools;

  AgentJournal _journal;
  List<TimelineItem> _committedTimeline = const [];
  ModelCardTimelineItem? _liveModelStatus;
  bool _disposed = false;

  final _stateController = StreamController<ConversationState>.broadcast();
  late ConversationState _lastState;

  // ── Reactive surface ──────────────────────────────────

  /// Broadcast stream of conversation state changes.
  Stream<ConversationState> get stream => _stateController.stream;

  /// Current state.
  ConversationState get state => _lastState;

  /// This session's history, to read.
  AgentTranscript get transcript => _journal;

  /// This session's history, to change. The repository swaps and drains it;
  /// nothing above that layer can name the type.
  AgentJournal get journal => _journal;

  /// Context-window size this session's agent was loaded with, if known.
  int? get sessionContextSize => _contextSize;

  /// Fraction of the compaction limit at which this session's turns fold
  /// their history. Revised from above when configuration changes.
  double compactionRatio;

  /// Room a tool answer may take, revised as this session's context fills.
  ///
  /// Held here rather than with the pending calls, which are replaced whenever
  /// the conversation is — a resume should not silently restore an older
  /// reading.
  int maxOutputChars;

  /// Current committed + live chat rows.
  List<TimelineItem> get timelineItems => _currentTimeline();

  // ── Turn-dependent surface (live sessions override) ───

  /// Whether this session can run turns right now. False for placeholders,
  /// which have no live agent.
  bool get canRunTurns => false;

  /// Current lifecycle phase. Placeholders are always idle.
  ConversationPhase get conversationPhase => ConversationPhase.idle;

  /// This session's agent handle, used to look up its slice of the shared-pool
  /// snapshot. Null for placeholders, which have no live agent.
  AgentHandle? get agentHandle => null;

  /// Last turn failure, if any.
  TurnFailure? get failure => null;

  /// The current turn's reasoning blocks, in order. Empty without a turn.
  List<String> get currentTurnReasoning => const [];

  /// Begin a new turn under [options], seeded by the user's [message].
  /// Placeholders cannot run turns and reject.
  Future<bool> beginTurn({
    required String message,
    required TurnOptions options,
  }) async => false;

  /// Deliver a batch of settled job [reports] as an unsolicited follow-up
  /// turn, returning whether the turn started.
  Future<bool> beginDeliveryTurn(List<DeliveredJobReport> reports) async =>
      false;

  /// Fold everything since the last compaction into a summary checkpoint,
  /// without generating a reply. Returns whether the turn started; there must
  /// be foldable history and no turn in flight.
  Future<bool> beginCompactionTurn(TurnOptions options) async => false;

  /// Cancel the active turn. No-op without a live turn.
  void cancel() {}

  // ── Conversation content (shared) ─────────────────────

  /// Appends a UI-only system notice (welcome / reset lines).
  void addNotice(String text) {
    _journal.append(
      NoticeEntry(id: _nextEntryId(), timestamp: DateTime.now(), text: text),
    );
    _refreshCommitted();
    emitState();
  }

  /// Appends the UI-only row for a call whose work carried on past it.
  void noteBackgrounded(JobInBackground job) {
    _journal.append(
      JobBackgroundedEntry(
        id: job.callId,
        timestamp: DateTime.now(),
        job: job,
      ),
    );
    _refreshCommitted();
    emitState();
  }

  /// Records a durable model-change entry and clears any live status.
  void recordModelChange(ModelSnapshot loaded) {
    _liveModelStatus = null;
    _journal.recordModelChange(
      ModelChangeEntry(
        id: _nextEntryId(),
        timestamp: DateTime.now(),
        modelId: loaded.modelId,
        displayName: loaded.displayName,
        contextSize: loaded.contextSize,
        provider: loaded.provider,
      ),
    );
    _refreshCommitted();
    emitState();
  }

  /// Sets (or clears) the transient live model-status overlay row.
  void setLiveModelStatus(ModelSnapshot? card) {
    _liveModelStatus = card == null
        ? null
        : ModelCardTimelineItem(
            id: 'live-model-status',
            timestamp: DateTime.now(),
            card: card,
          );
    emitState();
  }

  /// Swaps in a different journal (resume / clear), along with [tools] scoped
  /// to it.
  void loadJournal(
    AgentJournal journal,
    PendingToolCalls tools,
  ) {
    _journal = journal;
    _liveModelStatus = null;
    _tools.dispose();
    _tools = tools;
    _resetLiveState();
    _refreshCommitted();
    emitState();
  }

  /// Releases resources, and does not complete until this session's history
  /// is on disk. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _settleForDispose();
    _tools.dispose();
    await _releaseForDispose();
    await _stateController.close();
    await _journal.flush();
  }

  // ── Shared helpers ────────────────────────────────────

  /// Hook for live subclasses to clear in-flight turn state on load.
  void _resetLiveState() {}

  /// Hook for live subclasses to commit an in-flight turn as this session goes
  /// away.
  void _settleForDispose() {}

  /// Hook for live subclasses to release what they subscribed to.
  Future<void> _releaseForDispose() async {}

  String _nextEntryId() => const Uuid().v7();

  void _refreshCommitted() {
    _committedTimeline = _journal.timeline;
  }

  /// Committed history, any in-flight turn rows, then the live model card.
  List<TimelineItem> _currentTimeline() {
    final items = <TimelineItem>[..._committedTimeline, ..._liveTurnRows()];
    final live = _liveModelStatus;
    if (live != null) items.add(live);
    return items;
  }

  /// In-flight turn rows; empty unless a live turn is streaming.
  List<TimelineItem> _liveTurnRows() => const [];

  ConversationIdle _buildIdleState() => ConversationIdle(
    timelineItems: _currentTimeline(),
    conversationPhase: ConversationPhase.idle,
    failure: failure,
  );

  /// Builds the current state. Live sessions override to surface turn state.
  ConversationState _buildState() => _buildIdleState();

  /// Recomputes and publishes the current state.
  void emitState() {
    if (_disposed) return;
    _lastState = _buildState();
    _stateController.add(_lastState);
  }
}

/// A session for windows without a live agent. All behavior is inherited from
/// [AgentSession]; turns are disabled.
final class _PlaceholderAgentSession extends AgentSession {
  _PlaceholderAgentSession({
    required super.id,
    required super.compactionRatio,
    required super.maxOutputChars,
    required super.journal,
    required super.contextSize,
    required super.tools,
  }) : super._() {
    _refreshCommitted();
    _lastState = _buildIdleState();
  }
}

/// A live session driving a ready [Agent] through a turn.
final class _AgentSession extends AgentSession {
  _AgentSession({
    required super.id,
    required Agent agent,
    required TurnOptions options,
    required super.compactionRatio,
    required super.maxOutputChars,
    required super.journal,
    required super.contextSize,
    required super.tools,
    required ToolDefinitions toolDefinitions,
    required CompactionPromptContentBuilder compactionPromptContentBuilder,
  }) : _agent = agent,
       _options = options,
       _toolDefinitions = toolDefinitions,
       _compactionPromptContentBuilder = compactionPromptContentBuilder,
       super._() {
    _eventSub = _agent.events.listen(_onEvent);
    _refreshCommitted();
    _lastState = _buildIdleState();
  }

  final Agent _agent;
  final ToolDefinitions _toolDefinitions;

  /// Resolves the compaction summarizer's prompt content fresh each time the
  /// agent pauses for it.
  final CompactionPromptContentBuilder _compactionPromptContentBuilder;

  /// What turns run under, remembered from the last externally-started turn
  /// so an internally-started delivery turn runs the same way.
  TurnOptions _options;

  final TurnProjector _projector = TurnProjector();
  final TranscriptBlockLexer _lexer = const TranscriptBlockLexer();

  StreamSubscription<AgentRuntimeEvent>? _eventSub;
  Completer<void>? _turnCancelled;

  /// The in-flight runtime cancellation, if a turn was just cancelled.
  Future<void>? _pendingCancel;
  TurnFailure? _failure;
  DateTime? _turnStartedAt;
  final List<_CompactionRecord> _turnCompactions = [];

  /// Jobs backgrounded while a turn is open, held until it ends.
  final List<JobInBackground> _turnJobs = [];

  bool get _turnLive => _projector.active && _turnStartedAt != null;

  // ── Turn-dependent surface ────────────────────────────

  @override
  bool get canRunTurns => true;

  @override
  ConversationPhase get conversationPhase => _projector.active
      ? ConversationPhase.turnInFlight
      : ConversationPhase.idle;

  @override
  AgentHandle? get agentHandle => _agent.handle;

  @override
  TurnFailure? get failure => _failure;

  @override
  List<String> get currentTurnReasoning => [
    for (final entry in _projector.turnEntries)
      if (entry.role == Role.assistant)
        for (final block in entry.blocks)
          if (block is TranscriptReasoningBlock) block.text,
  ];

  /// A one-line preview of the latest lexed reasoning block for the chat stub.
  String? _reasoningSnippet() {
    for (final block in currentTurnReasoning.reversed) {
      final line = block.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (line.isEmpty) continue;
      return line.length > _reasoningSnippetMaxChars
          ? '${line.substring(0, _reasoningSnippetMaxChars)}…'
          : line;
    }
    return null;
  }

  /// Commits the user's [message] to history before the turn it seeds runs, so
  /// what was asked outlives however the turn ends.
  @override
  Future<bool> beginTurn({
    required String message,
    required TurnOptions options,
  }) async {
    if (_projector.active) return false;
    _options = options;
    final responseId = _nextResponseId();
    final seed = _lexer.lexEntry(
      TranscriptEntry(
        id: TranscriptEntryId.v7(),
        role: Role.user,
        blocks: [
          TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: message),
        ],
      ),
    );
    _journal.append(
      MessageEntry(
        id: seed.id.value.uuid,
        timestamp: DateTime.now(),
        entry: seed,
        responseId: responseId,
      ),
    );
    _refreshCommitted();
    emitState();
    return _runTurn(
      base: _journal.transcript,
      responseId: responseId,
      goal: TurnGoal.respond,
    );
  }

  @override
  Future<bool> beginDeliveryTurn(List<DeliveredJobReport> reports) async {
    if (_projector.active) return false; // Guard first — no orphan entry.
    final responseId = _nextResponseId();
    _journal.append(
      JobReportEntry(
        id: _nextEntryId(),
        timestamp: DateTime.now(),
        responseId: responseId,
        reports: reports,
      ),
    );
    _refreshCommitted();
    emitState();
    return _runTurn(
      base: _journal.transcript,
      responseId: responseId,
      goal: TurnGoal.respond,
    );
  }

  @override
  Future<bool> beginCompactionTurn(TurnOptions options) async {
    if (_projector.active || !_journal.hasFoldableHistory) return false;
    _options = options;
    return _runTurn(
      base: _journal.transcript,
      responseId: _nextResponseId(),
      goal: TurnGoal.compact,
    );
  }

  /// The shared turn body: seeds the projector from [base] — which already
  /// holds everything this turn answers — runs the agent toward [goal], and
  /// returns whether the turn started.
  Future<bool> _runTurn({
    required Transcript base,
    required int responseId,
    required TurnGoal goal,
  }) async {
    // Wait for any just-issued cancellation to fully settle in the runtime.
    final pendingCancel = _pendingCancel;
    if (pendingCancel != null) {
      _pendingCancel = null;
      await pendingCancel;
      if (_disposed) return false;
    }

    _failure = null;
    _turnCompactions.clear();
    _tools.reset();

    _turnStartedAt = DateTime.now();
    _turnCancelled = Completer<void>();
    _projector.begin(responseId: responseId, base: base.entries);

    emitState();

    final config = _options.toAgentConfig(
      compactionRatio: compactionRatio,
      tools: _toolDefinitions.definitions,
    );

    final result = await _agent.run(base, config: config, goal: goal);
    if (_disposed) return false;
    if (result is RunRejected) {
      _rejectTurn(result.reason.name);
      return false;
    }

    emitState();
    return true;
  }

  /// The next response id: one past the max already in the conversation, so a
  /// delivered turn groups its generations under a fresh id.
  int _nextResponseId() {
    var maxId = -1;
    for (final entry in _journal.entries) {
      final rid = switch (entry) {
        MessageEntry(:final responseId) => responseId,
        JobReportEntry(:final responseId) => responseId,
        _ => -1,
      };
      if (rid > maxId) maxId = rid;
    }
    return maxId + 1;
  }

  @override
  void cancel() {
    if (!_projector.active) return;
    _projector.endNow();
    _pendingCancel = _agent.cancel();
    _finishTurn(cancelled: true);
  }

  /// Commits whatever the turn in flight has produced, so a session that ends
  /// mid-turn still leaves its work in history.
  @override
  void _settleForDispose() {
    if (_projector.active) {
      _projector.endNow();
      // The result is of no use to a session that is going away, but the
      // runtime still has to hear that its stream should stop.
      unawaited(_agent.cancel());
      _tools.abortTurn();
      _commit(cancelled: true);
    }
    // Drop the pending cancellation without awaiting — the transport may be
    // torn down.
    _pendingCancel = null;
    _endTurnBookkeeping();
  }

  @override
  Future<void> _releaseForDispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
  }

  @override
  void _resetLiveState() {
    _failure = null;
  }

  // ── Turn machinery ────────────────────────────────────

  void _rejectTurn(String reasonName) {
    _failure = TurnFailure(
      reason: AgentRunFailureReason.loopFailed,
      message: 'submission rejected: $reasonName',
    );
    _projector.endNow();
    _endTurnBookkeeping();
    _clearTurnScratch();
    emitState();
  }

  void _onEvent(AgentRuntimeEvent event) {
    if (_disposed) return;
    switch (_projector.apply(event)) {
      case TurnProgressed():
        emitState();
      case TurnToolCallEmitted(:final toolCall):
        _tools.start(toolCall, maxOutputChars: maxOutputChars);
        emitState();
      case TurnNeedsTools(:final toolCalls):
        unawaited(_submitTools(toolCalls));
      case TurnNeedsCompactionPrompt():
        unawaited(
          _agent.submitCompactionPrompt(
            _compactionPromptContentBuilder.build(),
          ),
        );
      case CompactionCommitted(:final summary, :final tokensBefore):
        _onCompactionCommitted(summary, tokensBefore);
      case TurnCompletedProjection():
        _finishTurn();
      case TurnCancelledProjection():
        _finishTurn(cancelled: true);
      case TurnFailedProjection(:final reason, :final message):
        _failTurn(reason, message);
      case TurnProjectionIgnored():
        break;
    }
  }

  Future<void> _submitTools(List<ToolCall> toolCalls) async {
    final results = await _tools.join(
      toolCalls,
      aborted: _turnCancelled?.future,
    );
    if (_disposed || !_projector.active) return;
    await _agent.submitToolResults(results);
  }

  /// Ends the turn. A cancelled one settles every still-pending tool call as
  /// canceled, which the router observes to stop each call's job. A call that
  /// already settled in the background is inert to this and its job runs on.
  void _finishTurn({bool cancelled = false}) {
    if (cancelled) _tools.abortTurn();
    _commit(cancelled: cancelled);
    _endTurnBookkeeping();
    _refreshCommitted();
    emitState();
  }

  void _failTurn(AgentRunFailureReason reason, String? message) {
    final failure = TurnFailure(reason: reason, message: message);
    _projector.addAlert('Turn failed: ${failure.summary}');
    _failure = failure;
    _finishTurn();
  }

  void _onCompactionCommitted(String summary, int tokensBefore) {
    _turnCompactions.add(
      _CompactionRecord(
        id: _nextEntryId(),
        summary: summary,
        tokensBefore: tokensBefore,
      ),
    );
    emitState();
  }

  void _endTurnBookkeeping() {
    final cancelled = _turnCancelled;
    _turnCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  void _clearTurnScratch() {
    _turnStartedAt = null;
    for (final job in _turnJobs) {
      _journal.append(
        JobBackgroundedEntry(
          id: job.callId,
          timestamp: DateTime.now(),
          job: job,
        ),
      );
    }
    _turnJobs.clear();
  }

  void _commit({required bool cancelled}) {
    final responseId = _projector.responseId;

    // Pair any tool call left unanswered by a cancel/fail with a synthetic
    // interrupted result so the committed transcript stays well-formed.
    final entries = reconcileInterruptedToolCalls(
      _projector.turnEntries,
      nextEntryId: TranscriptEntryId.v7,
      nextBlockId: TranscriptBlockId.v7,
    );

    // Any completed compactions whose checkpoint didn't survive the final fold
    // still persist, so nothing is silently dropped — except on cancel, where
    // the runtime reverts a fold it never adopted, so a trailing un-anchored
    // record would be a phantom marker for a fold that didn't happen.
    for (final slot in _projectTurn(entries, trailingCompactions: !cancelled)) {
      switch (slot) {
        case _MessageSlot(:final entry):
          _journal.append(
            MessageEntry(
              id: entry.id.value.uuid,
              timestamp: DateTime.now(),
              entry: _lexer.lexEntry(entry),
              responseId: responseId,
            ),
          );
        case _CompactionSlot(:final index):
          _appendCompaction(_turnCompactions[index]);
        case _JobSlot(:final job):
          _journal.append(
            JobBackgroundedEntry(
              id: job.callId,
              timestamp: DateTime.now(),
              job: job,
            ),
          );
      }
    }

    _turnJobs.clear();
    _appendAlerts();
    _clearTurnScratch();
  }

  void _appendAlerts() {
    for (final alert in _projector.alerts) {
      _journal.append(
        NoticeEntry(
          id: _nextEntryId(),
          timestamp: DateTime.now(),
          text: alert,
        ),
      );
    }
  }

  void _appendCompaction(_CompactionRecord record) {
    _journal.append(
      CompactionEntry(
        id: record.id,
        timestamp: DateTime.now(),
        summary: record.summary,
        tokensBefore: record.tokensBefore,
      ),
    );
  }

  List<TranscriptEntry> _labelTurnEntries(List<TranscriptEntry> entries) =>
      labelTurnEntries(entries, _toolDefinitions.definitionFor);

  bool _isSummaryCheckpoint(TranscriptEntry te) =>
      te.role == Role.system &&
      te.blocks.any((b) => b is TranscriptSummaryBlock);

  @override
  void noteBackgrounded(JobInBackground job) {
    if (!_turnLive) {
      super.noteBackgrounded(job);
      return;
    }
    _turnJobs.add(job);
    emitState();
  }

  /// The turn's rows in the order they belong, as slots for the caller to
  /// materialize.
  List<_TurnSlot> _projectTurn(
    List<TranscriptEntry> entries, {
    required bool trailingCompactions,
  }) {
    final slots = <_TurnSlot>[];
    final pending = [..._turnJobs];
    // Each summary checkpoint anchors its completed compaction inline, so a
    // locked marker never floats past the messages that came after its fold.
    var compaction = 0;
    for (final entry in _labelTurnEntries(entries)) {
      if (_isSummaryCheckpoint(entry)) {
        if (compaction < _turnCompactions.length) {
          slots.add(_CompactionSlot(compaction++));
        }
        continue;
      }
      slots.add(_MessageSlot(entry));
      for (final job in _takeJobsAnsweredBy(entry, pending)) {
        slots.add(_JobSlot(job));
      }
    }
    if (trailingCompactions) {
      for (; compaction < _turnCompactions.length; compaction++) {
        slots.add(_CompactionSlot(compaction));
      }
    }
    // A job whose answer the mirror has not caught up to yet trails likewise,
    // and is still filed — the work is running either way.
    for (final job in pending) {
      slots.add(_JobSlot(job));
    }
    return slots;
  }

  /// Removes from [pending] every job whose call [entry] answers, in order.
  List<JobInBackground> _takeJobsAnsweredBy(
    TranscriptEntry entry,
    List<JobInBackground> pending,
  ) {
    final answered = {
      for (final block in entry.blocks)
        if (block is TranscriptToolCallResponseBlock) block.response.callId,
    };
    if (answered.isEmpty) return const [];
    final taken = [
      for (final job in pending)
        if (answered.contains(job.callId)) job,
    ];
    pending.removeWhere((job) => answered.contains(job.callId));
    return taken;
  }

  @override
  List<TimelineItem> _liveTurnRows() {
    if (!_turnLive) return const [];
    final timestamp = _turnStartedAt!;
    final responseId = _projector.responseId;

    final live = <ConversationEntry>[
      for (final slot in _projectTurn(
        _projector.turnEntries,
        trailingCompactions: true,
      ))
        switch (slot) {
          _MessageSlot(:final entry) => MessageEntry(
            id: entry.id.value.uuid,
            timestamp: timestamp,
            entry: entry,
            responseId: responseId,
          ),
          _CompactionSlot(:final index) => _liveCompactionEntry(
            index,
            timestamp,
          ),
          _JobSlot(:final job) => _liveJobEntry(job, timestamp),
        },
    ];
    final activity = _projector.activity;
    return [
      ...foldTimeline(
        live,
        live: true,
        tailOpen: activity != TurnActivity.draftingToolCall,
      ),
      ..._frontierRow(activity, timestamp),
    ];
  }

  JobBackgroundedEntry _liveJobEntry(JobInBackground job, DateTime timestamp) =>
      JobBackgroundedEntry(
        id: job.callId,
        timestamp: timestamp,
        job: job,
      );

  CompactionEntry _liveCompactionEntry(int index, DateTime timestamp) {
    final record = _turnCompactions[index];
    return CompactionEntry(
      id: record.id,
      timestamp: timestamp,
      summary: record.summary,
      tokensBefore: record.tokensBefore,
    );
  }

  /// The single row past the last streamed block: an in-flight compaction
  /// marker while folding (summary streaming, context reprocessing), the
  /// tool call being drafted, or a neutral pending-response stub while the
  /// main prompt reprocesses.
  List<TimelineItem> _frontierRow(TurnActivity activity, DateTime timestamp) =>
      switch (activity) {
        TurnActivity.compacting => [
          CompactionMarkerTimelineItem(
            id: 'live-compaction-active',
            timestamp: timestamp,
            summary: _projector.liveSummary ?? '',
            summaryReasoning: _projector.liveSummaryReasoning ?? '',
            tokensBefore: _projector.compactionTokensBefore ?? 0,
            running: true,
            prefillFraction: _projector.prefillFraction,
          ),
        ],
        TurnActivity.draftingToolCall => [
          ToolCallDraftTimelineItem(
            id: 'live-tool-draft',
            timestamp: timestamp,
          ),
        ],
        TurnActivity.thinking when _stepHasNothingYet() => [
          ReasoningStubTimelineItem(
            id: 'live-thinking',
            timestamp: timestamp,
            text: '',
            running: true,
            prefillFraction: _projector.prefillFraction,
          ),
        ],
        TurnActivity.thinking ||
        TurnActivity.responding ||
        TurnActivity.executingTools => const [],
      };

  /// True until the step in flight streams its first block.
  bool _stepHasNothingYet() {
    TranscriptBlock? last;
    for (final te in _projector.turnEntries) {
      if (te.role == Role.user) continue;
      for (final block in te.blocks) {
        last = block;
      }
    }
    return last == null || last is TranscriptToolCallResponseBlock;
  }

  @override
  ConversationState _buildState() {
    if (_projector.active && _turnStartedAt != null) {
      return TurnInProgress(
        timelineItems: _currentTimeline(),
        conversationPhase: ConversationPhase.turnInFlight,
        activity: _projector.activity,
        reasoningSnippet: _reasoningSnippet(),
      );
    }
    return _buildIdleState();
  }
}

/// Max characters shown in the live reasoning snippet before eliding.
const _reasoningSnippetMaxChars = 120;

/// One row of a projected turn, in the order it belongs.
sealed class _TurnSlot {
  const _TurnSlot();
}

/// A transcript entry of the turn itself.
final class _MessageSlot extends _TurnSlot {
  const _MessageSlot(this.entry);

  final TranscriptEntry entry;
}

/// The compaction record at [index], anchored to its summary checkpoint.
final class _CompactionSlot extends _TurnSlot {
  const _CompactionSlot(this.index);

  final int index;
}

/// A job left running by the answer immediately above it.
final class _JobSlot extends _TurnSlot {
  const _JobSlot(this.job);

  final JobInBackground job;
}

/// One completed compaction pass this turn: its rolling summary and the
/// pre-fold token cost, captured from `AgentCompactionStarted`/`Completed`.
@immutable
class _CompactionRecord {
  const _CompactionRecord({
    required this.id,
    required this.summary,
    required this.tokensBefore,
  });

  final String id;
  final String summary;
  final int tokensBefore;
}
