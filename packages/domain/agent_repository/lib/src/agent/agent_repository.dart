import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/agent/agent_configuration.dart';
import 'package:agent_repository/src/agent/agent_session.dart';
import 'package:agent_repository/src/agent/agent_session_id.dart';
import 'package:agent_repository/src/agent/conversation_state.dart';
import 'package:agent_repository/src/agent/subagent_read.dart';
import 'package:agent_repository/src/agent/subagent_report_delivery.dart';
import 'package:agent_repository/src/agent/subagent_summary.dart';
import 'package:agent_repository/src/conversation/agent_journal.dart';
import 'package:agent_repository/src/conversation/conversation_store.dart';
import 'package:agent_repository/src/conversation/conversation_summary.dart';
import 'package:agent_repository/src/conversation/job_in_background.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:agent_repository/src/conversation/load_conversation_result.dart';
import 'package:agent_repository/src/conversation/rewind_result.dart';
import 'package:agent_repository/src/stats/chat_context_stats.dart';
import 'package:agent_repository/src/turn/pending_tool_calls.dart';
import 'package:agent_repository/src/turn/turn_options.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:intentions/intentions.dart';
import 'package:prompt_builder/prompt_builder.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Domain-layer repository that owns the lifecycle of [AgentSession]s.
@repository
class AgentRepository implements ToolRequester {
  AgentRepository({
    required ToolDefinitions toolDefinitions,
    required ToolDefinitions subagentToolDefinitions,
    required ConversationStore conversationStore,
    required SubagentSystemPromptBuilder subagentSystemPromptBuilder,
    required CompactionPromptContentBuilder compactionPromptContentBuilder,
    required AgentConfiguration configuration,
    required this.workingDirectory,
  }) : _configuration = configuration,
       _toolDefinitions = toolDefinitions,
       _subagentToolDefinitions = subagentToolDefinitions,
       _conversationStore = conversationStore,
       _subagentSystemPromptBuilder = subagentSystemPromptBuilder,
       _compactionPromptContentBuilder = compactionPromptContentBuilder {
    final journal = _freshPrimaryJournal();
    _primarySession = AgentSession.placeholder(
      id: primaryAgentSessionId,
      compactionRatio: _configuration.compactionRatio,
      maxOutputChars: _configuration.maxToolCallCharacters,
      journal: journal,
      contextSize: _providerContextSize,
      tools: _pendingToolCallsFor(journal, _toolDefinitions),
    );
    _bindDelivery(_primarySession);
  }

  final ToolDefinitions _toolDefinitions;

  /// Where the app is running; stamped onto every conversation started here.
  final String workingDirectory;

  /// What a subagent is told it may call.
  final ToolDefinitions _subagentToolDefinitions;

  final ConversationStore _conversationStore;

  /// Mints the pending-call holder for a session offered [definitions], filing
  /// its output where [journal] lives.
  PendingToolCalls _pendingToolCallsFor(
    AgentJournal journal,
    ToolDefinitions definitions,
  ) => PendingToolCalls(
    definitions: definitions,
    requests: _requests.sink,
    conversationStore: _conversationStore,
    conversationId: journal.conversationId,
    agentId: journal.agentId,
  );

  /// Single-subscription rather than broadcast: it takes one listener, and
  /// holds anything emitted before that listener arrives instead of dropping
  /// it.
  final _requests = StreamController<ToolCallRequest>();

  /// The tool calls this repository's agents have made. Answered above, since
  /// what runs a call is a composition decision.
  @override
  Stream<ToolCallRequest> get toolRequests => _requests.stream;

  /// Supplies the generic subagent system prompt, resolved fresh per turn.
  final SubagentSystemPromptBuilder _subagentSystemPromptBuilder;

  /// Supplies the compaction summarizer's prompt content.
  final CompactionPromptContentBuilder _compactionPromptContentBuilder;

  /// The create-only baseline system prompt for minting the primary agent,
  /// pushed in with each [bindProvider].
  String _systemPrompt = '';

  late AgentSession _primarySession;
  final _primaryController = StreamController<AgentSession>.broadcast();

  /// The subagent roster, keyed by id. One entry owns everything about a
  /// subagent: its session, title, live status, and whether it was stopped.
  final Map<AgentSessionId, _Subagent> _subagents = {};
  final _subagentsController =
      StreamController<List<SubagentSummary>>.broadcast();

  /// One report buffer per addressee. Reports to a removed session are dropped.
  final Map<AgentSessionId, _SessionDelivery> _deliveries = {};

  AgentProvider? _provider;
  int? _providerContextSize;
  bool _disposed = false;

  /// The latest shared-pool occupancy snapshot, mirrored from the bound
  /// provider. The single source of truth for every session's context stats —
  /// there is one KV pool across all agents.
  ContextPoolSnapshot? _poolSnapshot;
  StreamSubscription<ContextPoolSnapshot>? _poolSub;
  final _poolController = StreamController<ContextPoolSnapshot>.broadcast();
  StreamSubscription<double>? _spendSub;
  final _spendController = StreamController<double>.broadcast();

  // ── Access ────────────────────────────────────────────

  /// The app's main session. Always present — a placeholder while no agent is
  /// live (startup, model load, reload), a live session otherwise.
  AgentSession get primary => _primarySession;

  /// Emits the primary session each time it is swapped (placeholder ⇄ live).
  Stream<AgentSession> get primaryStream => _primaryController.stream;

  /// The primary's conversation state across primary swaps, seeded with the
  /// state current at the moment of listening.
  Stream<ConversationState> get primaryConversationStream =>
      Stream<ConversationState>.multi((controller) {
        StreamSubscription<ConversationState>? sessionSub;
        void bind(AgentSession session) {
          unawaited(sessionSub?.cancel());
          sessionSub = session.stream.listen(controller.add);
          controller.add(session.state);
        }

        bind(_primarySession);
        final primarySub = _primaryController.stream.listen(bind);
        controller.onCancel = () async {
          await sessionSub?.cancel();
          await primarySub.cancel();
        };
      });

  /// The session registered under [id] — the primary or any subagent.
  AgentSession? sessionFor(AgentSessionId id) =>
      id == primaryAgentSessionId ? _primarySession : _subagents[id]?.session;

  /// Accepts word that a call's work carried on past its answer, stamping it
  /// with the label its tool gives work in progress.
  @override
  void noteBackgrounded(JobBackgrounded job) {
    final session = sessionFor(job.agentId);
    if (session == null) return;
    final definitions = job.agentId == primaryAgentSessionId
        ? _toolDefinitions
        : _subagentToolDefinitions;
    session.noteBackgrounded(
      JobInBackground.fromJobBackgrounded(
        job,
        definition: definitions.definitionFor(job.toolName),
      ),
    );
  }

  /// Accepts a settled background report from the tool system, stamping it
  /// with the label its tool gives a settled job.
  @override
  void deliverReport(JobReport report) {
    final delivery = _deliveries[report.agentId];
    if (delivery == null) return;
    final definitions = report.agentId == primaryAgentSessionId
        ? _toolDefinitions
        : _subagentToolDefinitions;
    delivery.logic.input(
      JobReportSettled(
        DeliveredJobReport.fromJobReport(
          report,
          definition: definitions.definitionFor(report.toolName),
        ),
      ),
    );
  }

  /// Emits the current subagent roster each time it changes. The zone bar
  /// binds to this; the full renderable session for a row is fetched via
  /// [sessionFor].
  Stream<List<SubagentSummary>> get subagentsStream =>
      _subagentsController.stream;

  /// Current subagent roster snapshot.
  List<SubagentSummary> get subagents => List.unmodifiable([
    for (final sub in _subagents.values)
      SubagentSummary(id: sub.id, title: sub.title, status: sub.status),
  ]);

  /// Emits each time the shared-pool occupancy snapshot changes. Consumers
  /// re-read [statsFor] on a tick.
  Stream<ContextPoolSnapshot> get poolStream => _poolController.stream;

  /// Every charge the bound provider reports for a completion, as it lands.
  Stream<double> get spendStream => _spendController.stream;

  /// Context stats for the session [id], projected from the latest pool
  /// snapshot. The primary reads its availability after full reserved claims; a
  /// subagent reads its own resident/claim ratio. Null before the first
  /// snapshot, or for a session with no live agent in the current pool.
  ChatContextStats? statsFor(AgentSessionId id) {
    final snapshot = _poolSnapshot;
    final handle = sessionFor(id)?.agentHandle;
    if (snapshot == null || handle == null) return null;
    for (final lease in snapshot.leases) {
      if (lease.handle != handle) continue;
      final isPrimary = handle.kind == AgentKind.primary;
      return ChatContextStats(
        contextSize: snapshot.contextSize,
        budgetTokens: isPrimary ? snapshot.contextSize : lease.claimTokens,
        cachedTokens: isPrimary
            ? lease.residentTokens + snapshot.reservedClaims
            : lease.residentTokens,
        maxOutputTokens: 0,
        safetyMarginTokens: 0,
      );
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────

  /// Bind (or clear) the shared [AgentProvider]. Binding a provider spawns the
  /// primary agent and swaps in a live session; clearing it (`null`, on a
  /// primary-model reload) swaps back to a placeholder.
  Future<void> bindProvider(
    AgentProvider? provider, {
    int? contextSize,
    String systemPrompt = '',
  }) async {
    if (identical(provider, _provider)) {
      _providerContextSize = contextSize ?? _providerContextSize;
      return;
    }
    _providerContextSize = provider == null ? null : contextSize;
    _systemPrompt = systemPrompt;

    await _parkPrimary();
    await _drainSubagents();

    _provider = provider;
    _bindPool(provider);
    _bindSpend(provider);
    if (provider != null) await _spawn(provider);
  }

  Future<void> _parkPrimary() => _replacePrimary(() {
    final journal = primary.journal;
    return AgentSession.placeholder(
      id: primaryAgentSessionId,
      compactionRatio: _configuration.compactionRatio,
      maxOutputChars: _configuration.maxToolCallCharacters,
      journal: journal,
      contextSize: _providerContextSize,
      tools: _pendingToolCallsFor(journal, _toolDefinitions),
    );
  });

  /// Every saved conversation, in no particular order.
  Future<List<ConversationSummary>> conversations() =>
      _conversationStore.summaries();

  /// Swaps the saved conversation [id] into the primary session.
  Future<LoadConversationResult> load(String id) async {
    final data = await _conversationStore.load(
      id,
      agentId: primaryAgentSessionId,
    );
    if (data == null) return const ConversationNotFound();
    _loadIntoPrimary(
      AgentJournal.fromSessionData(data, store: _conversationStore),
    );
    return const ConversationLoaded();
  }

  /// Reset the current session to a fresh, empty conversation.
  void clear() => _loadIntoPrimary(_freshPrimaryJournal());

  /// Cuts the primary's history back to just before the user message
  /// [entryId], handing its text back for editing.
  RewindResult rewindTo(String entryId) {
    final journal = primary.journal;
    final message = journal.userMessageText(entryId);
    if (message == null || !journal.truncateBefore(entryId)) {
      return const RewindTargetNotFound();
    }
    // A conversation rewound past its first message has no history left to
    // name, so it gives way to a fresh one and its file goes.
    if (journal.isEmpty) {
      _loadIntoPrimary(_freshPrimaryJournal());
      unawaited(_discard(journal));
    } else {
      _loadIntoPrimary(journal);
    }
    return Rewound(message: message);
  }

  /// Drops [journal]'s conversation from disk once its own writes have
  /// settled, so a queued save cannot put the file back.
  Future<void> _discard(AgentJournal journal) async {
    await journal.flush();
    try {
      await _conversationStore.delete(journal.conversationId);
    } on Object catch (error) {
      Diagnostics.log(
        'agent',
        'could not remove ${journal.conversationId}: $error',
      );
    }
  }

  AgentJournal _freshPrimaryJournal() => AgentJournal.fresh(
    agentId: primaryAgentSessionId,
    workingDirectory: workingDirectory,
    store: _conversationStore,
  );

  void _loadIntoPrimary(AgentJournal journal) => primary.loadJournal(
    journal,
    _pendingToolCallsFor(journal, _toolDefinitions),
  );

  // ── Subagents ─────────────────────────────────────────

  /// Dispatches one subagent and answers immediately with an acknowledgement,
  /// leaving it running — its report is delivered later, as its own entry.
  Future<Job> startSubagent({
    required String callId,
    required String prompt,
    required String label,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return Job.failed('No model is loaded; cannot spawn a subagent.');
    }

    final start = await provider.startSubagent(
      config: _subagentConfig(),
      label: label,
    );
    if (start is StartSubagentRejected) {
      return Job.failed(_rejectionMessage(start.reason));
    }
    final agent = (start as StartSubagentStarted).agent;

    final id = callId;
    final journal = AgentJournal.fresh(
      conversationId: primary.transcript.conversationId,
      agentId: id,
      workingDirectory: primary.transcript.workingDirectory,
      store: _conversationStore,
    );
    final session = AgentSession.live(
      id: id,
      agent: agent,
      options: _subagentOptions(),
      compactionRatio: _configuration.compactionRatio,
      maxOutputChars: _configuration.maxToolCallCharacters,
      journal: journal,
      contextSize: _providerContextSize,
      tools: _pendingToolCallsFor(journal, _subagentToolDefinitions),
      toolDefinitions: _subagentToolDefinitions,
      compactionPromptContentBuilder: _compactionPromptContentBuilder,
    );

    final sub = _Subagent(id: id, session: session, title: label);
    _subagents[id] = sub;
    _bindDelivery(session);
    _emitSubagents();

    final job = _SubagentJob(() => _stop(sub));
    sub.run = _runDetached(
      sub: sub,
      agent: agent,
      provider: provider,
      prompt: prompt,
      job: job,
    );
    unawaited(sub.run);
    job.handoff(
      'Dispatched subagent as $callId. When finished, a '
      'notification will arrive as a follow-up message.',
    );
    return job;
  }

  /// One page of subagent [id]'s output, up to [maxChars] of block text.
  Future<SubagentRead> readSubagent({
    required String id,
    required bool wholeTranscript,
    required int maxChars,
    String? after,
  }) async {
    final subagent = _subagents[id];
    if (subagent?.status == SubagentStatus.running) {
      return const SubagentReadBusy();
    }

    // A subagent still on the roster is read from what it holds; only one from
    // an earlier run has to come off disk.
    final entries =
        subagent?.session.transcript.entries ??
        (await _conversationStore.load(
          primary.transcript.conversationId,
          agentId: id,
        ))?.entries;
    if (entries == null) return const SubagentReadUnknown();

    final view = wholeTranscript
        ? SubagentReadView.transcript(entries)
        : SubagentReadView.answer(entries);
    return view.page(maxChars: maxChars, after: after);
  }

  /// Drives a dispatched subagent to settlement off the caller's turn.
  Future<void> _runDetached({
    required _Subagent sub,
    required Agent agent,
    required AgentProvider provider,
    required String prompt,
    required _SubagentJob job,
  }) async {
    final started = await _driveToSettle(sub.session, prompt);
    await provider.disposeAgent(agent);
    final outcome = _subagentOutcome(sub, started: started);
    sub.status = outcome is JobSucceeded
        ? SubagentStatus.completed
        : SubagentStatus.failed;
    _emitSubagents();
    job.complete(outcome);
  }

  /// Stops a running subagent: cancels its turn so [_runDetached]'s settle
  /// unblocks and resolves as a user-stopped failure the primary can act on.
  void stopSubagent(AgentSessionId id) => _stop(_subagents[id]);

  void _stop(_Subagent? sub) {
    if (sub == null || sub.status != SubagentStatus.running) return;
    sub.stopped = true;
    sub.session.cancel();
  }

  /// Subagents still working.
  int get _runningCount => _subagents.values
      .where((sub) => sub.status == SubagentStatus.running)
      .length;

  /// Drops every subagent from the roster once none are still running,
  /// reclaiming the zone bar's vertical space. A no-op while any subagent is
  /// in flight, so a live roster is never yanked out from under the user.
  Future<void> clearSettledSubagents() async {
    if (_subagents.isEmpty || _runningCount > 0) return;
    for (final sub in _subagents.values) {
      final delivery = _deliveries.remove(sub.id);
      await delivery?.subscription.cancel();
      delivery?.logic.dispose();
      await sub.session.dispose();
    }
    _subagents.clear();
    _emitSubagents();
  }

  /// Drives [session] through its single turn and completes when it settles
  /// back to idle (or its stream closes). Subscribes to the session's state
  /// stream before beginning the turn so no completion event can be missed.
  Future<bool> _driveToSettle(AgentSession session, String prompt) async {
    final settled = Completer<void>();
    var sawActive = false;
    final sub = session.stream.listen(
      (state) {
        switch (state.conversationPhase) {
          case ConversationPhase.turnInFlight:
            sawActive = true;
          case ConversationPhase.idle:
            if (sawActive && !settled.isCompleted) settled.complete();
        }
      },
    );

    final started = await session.beginTurn(
      message: prompt,
      options: _subagentOptions(),
    );
    if (started) await settled.future;
    await sub.cancel();
    return started;
  }

  JobOutcome _subagentOutcome(_Subagent sub, {required bool started}) {
    final label = 'Subagent ${sub.id} "${sub.title}"';
    if (sub.stopped) {
      return JobCanceled('$label stopped.');
    }
    if (!started) {
      return JobFailed('$label could not start.');
    }
    final failure = sub.session.failure;
    if (failure != null) {
      return JobFailed('$label failed: ${failure.summary}');
    }
    final tokens = SubagentReadView.answer(
      sub.session.transcript.entries,
    ).tokens;
    return JobSucceeded(
      '$label finished: ${tokens == 0 ? 'no output' : '$tokens tokens'}.',
    );
  }

  /// Connects a session's idle edge to its addressed report buffer.
  void _bindDelivery(AgentSession agent) {
    final existing = _deliveries[agent.id];
    unawaited(existing?.subscription.cancel());
    final logic = existing?.logic ?? (JobReportDeliveryLogic()..start());
    // The repository cancels this through its _SessionDelivery entry.
    // ignore: cancel_subscriptions
    final subscription = agent.stream.listen((state) {
      if (state.conversationPhase == ConversationPhase.idle) {
        logic.input(const AgentIdled());
      }
    });
    _deliveries[agent.id] = _SessionDelivery(logic, subscription);
    logic.input(AgentBound(agent));
  }

  /// Settles and disposes every subagent session, clearing the roster.
  Future<void> _drainSubagents() async {
    if (_subagents.isEmpty) return;

    _subagents.values.forEach(_stop);

    // Each cancelled turn settles its detached run, which releases the claim
    // and buffers a report; only then is it safe to drop the sessions.
    await Future.wait([for (final sub in _subagents.values) ?sub.run]);

    for (final sub in _subagents.values) {
      final delivery = _deliveries.remove(sub.id);
      await delivery?.subscription.cancel();
      delivery?.logic.dispose();
      await sub.session.dispose();
    }
    _subagents.clear();
    _emitSubagents();
  }

  void _emitSubagents() {
    if (!_disposed) _subagentsController.add(subagents);
  }

  /// Maps a rejection into a message the model can act on: transient for
  /// compaction, capacity guidance for lease exhaustion, else generic.
  String _rejectionMessage(AgentRuntimeRejectionReason reason) =>
      switch (reason) {
        AgentRuntimeRejectionReason.primaryCompactionPending =>
          'The primary agent is compacting its context; try delegating again '
              'once it finishes.',
        AgentRuntimeRejectionReason.noSequenceCapacity ||
        AgentRuntimeRejectionReason.insufficientClaimSpace ||
        AgentRuntimeRejectionReason.agentCapacityReached =>
          'At subagent capacity right now — run fewer subagents at once, or '
              'delegate them sequentially.',
        AgentRuntimeRejectionReason.insufficientContextSpace =>
          'Not enough free context to loan to a subagent.',
        _ => 'Could not start a subagent (${reason.name}).',
      };

  /// Releases resources. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final delivery in _deliveries.values) {
      await delivery.subscription.cancel();
      delivery.logic.dispose();
    }
    _deliveries.clear();
    await _poolSub?.cancel();
    await _spendSub?.cancel();
    await _primarySession.dispose();
    for (final sub in _subagents.values) {
      await sub.session.dispose();
    }
    _subagents.clear();
    await _primaryController.close();
    await _subagentsController.close();
    await _poolController.close();
    await _spendController.close();

    unawaited(_requests.close());
  }

  /// (Re)binds the pool snapshot stream to [provider]. Clearing the provider
  /// drops the last snapshot so stale stats don't linger across a reload.
  void _bindPool(AgentProvider? provider) {
    unawaited(_poolSub?.cancel());
    _poolSub = null;
    _poolSnapshot = null;
    if (provider == null) return;
    _poolSub = provider.pool.listen((snapshot) {
      _poolSnapshot = snapshot;
      _pushConfiguration();
      if (!_poolController.isClosed) _poolController.add(snapshot);
    });
  }

  void _bindSpend(AgentProvider? provider) {
    unawaited(_spendSub?.cancel());
    _spendSub = null;
    if (provider == null) return;
    _spendSub = provider.spend.listen((cost) {
      if (!_spendController.isClosed) _spendController.add(cost);
    });
  }

  /// Hands every live session the current settings, and the room for a tool
  /// answer that the newest occupancy reading leaves it. A session the pool
  /// does not describe keeps the room it last knew rather than being told it
  /// has none.
  void _pushConfiguration() {
    for (final id in [primaryAgentSessionId, ..._subagents.keys]) {
      final session = sessionFor(id);
      if (session == null) continue;
      session.compactionRatio = _configuration.compactionRatio;
      final stats = statsFor(id);
      if (stats == null) continue;
      session.maxOutputChars = maxOutputCharsFor(
        availableTokens: stats.budgetTokens - stats.cachedTokens,
        maxToolCallCharacters: _configuration.maxToolCallCharacters,
      );
    }
  }

  AgentConfiguration _configuration;

  /// What every agent here runs under, supplied from above since reading
  /// configuration is not this layer's to do.
  AgentConfiguration get configuration => _configuration;

  /// Revised whenever configuration changes. Reaches live sessions at once;
  /// a turn already running keeps what it started with.
  set configuration(AgentConfiguration configuration) {
    _configuration = configuration;
    _pushConfiguration();
  }

  /// True once the repo is disposed or [provider] is no longer the bound one —
  /// the guard for detached work that outlived its provider.
  bool _isStale(AgentProvider provider) =>
      _disposed || !identical(_provider, provider);

  // ── Swapping ──────────────────────────────────────────

  Future<void> _spawn(AgentProvider provider) async {
    final result = await provider.startPrimary(config: _spawnConfig());
    if (_isStale(provider)) return;
    switch (result) {
      case StartPrimaryStarted(:final agent):
        await _replacePrimary(() {
          final journal = primary.journal;
          return AgentSession.live(
            id: primaryAgentSessionId,
            agent: agent,
            options: _primaryOptions(),
            compactionRatio: _configuration.compactionRatio,
            maxOutputChars: _configuration.maxToolCallCharacters,
            journal: journal,
            contextSize: _providerContextSize,
            tools: _pendingToolCallsFor(journal, _toolDefinitions),
            toolDefinitions: _toolDefinitions,
            compactionPromptContentBuilder: _compactionPromptContentBuilder,
          );
        });
      case StartPrimaryRejected(:final reason):
        Diagnostics.log('agent', 'primary agent rejected: ${reason.name}');
    }
  }

  /// Swaps the primary for what [build] makes of it.
  Future<void> _replacePrimary(AgentSession Function() build) async {
    final previous = _primarySession;
    final drained = previous.dispose();
    final next = build();
    _primarySession = next;
    _bindDelivery(next);
    if (!_disposed) _primaryController.add(next);
    await drained;
  }

  /// The baseline config used to mint the primary agent. `startPrimary` is
  /// create-only, so only the system prompt + tools matter here; per-turn
  /// sampling and reasoning travel with each `Agent.run`.
  AgentConfig _spawnConfig() => _primaryOptions().toAgentConfig(
    compactionRatio: _configuration.compactionRatio,
    tools: _toolDefinitions.definitions,
  );

  /// The baseline config for a subagent: the generic worker prompt and what a
  /// subagent may call.
  AgentConfig _subagentConfig() => _subagentOptions().toAgentConfig(
    compactionRatio: _configuration.compactionRatio,
    tools: _subagentToolDefinitions.definitions,
  );

  /// What the primary's turns run under before the chat surface says
  /// otherwise: the bound system prompt.
  TurnOptions _primaryOptions() => TurnOptions.baseline(_systemPrompt);

  /// What a subagent's turns run under: the generic worker prompt.
  TurnOptions _subagentOptions() =>
      TurnOptions.baseline(_subagentSystemPromptBuilder.build());
}

/// A single subagent's roster entry.
class _Subagent {
  _Subagent({required this.id, required this.session, required this.title});

  final AgentSessionId id;
  final AgentSession session;
  final String title;
  SubagentStatus status = SubagentStatus.running;
  bool stopped = false;

  /// The detached run driving this subagent to settlement.
  Future<void>? run;
}

final class _SubagentJob implements Job {
  _SubagentJob(this._stop);

  final void Function() _stop;
  final _settled = Completer<JobOutcome>();
  final _inBackground = Completer<String>();
  JobOutcome? _outcome;

  @override
  JobOutcome? get outcome => _outcome;

  @override
  Future<JobOutcome> get settled => _settled.future;

  @override
  Future<String> get inBackground => _inBackground.future;

  void handoff(String content) => _inBackground.complete(content);

  void complete(JobOutcome outcome) {
    if (_settled.isCompleted) return;
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() => _stop();
}

final class _SessionDelivery {
  _SessionDelivery(this.logic, this.subscription);

  final JobReportDeliveryLogic logic;
  final StreamSubscription<ConversationState> subscription;
}
