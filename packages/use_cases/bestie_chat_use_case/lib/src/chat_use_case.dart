import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider, ContextPoolSnapshot, SamplingOptions;
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/src/chat_config_keys.dart';
import 'package:bestie_chat_use_case/src/chat_strings.dart';
import 'package:bestie_chat_use_case/src/conversation_picker.dart';
import 'package:bestie_chat_use_case/src/conversation_replacement.dart';
import 'package:bestie_chat_use_case/src/subagent_tools.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show Job, ToolCallInvocation, ToolDefinitions, ToolResponder;

/// Reads the sampling every turn runs under, as configured right now.
typedef SamplingResolver = SamplingOptions Function();

/// Feature-aggregate use case for the chat surface.
@useCase
class ChatUseCase implements ToolResponder, CommandContribution {
  ChatUseCase({
    required ProviderRepository providerRepository,
    required AgentRepository agentRepository,
    required ConfigRepository config,
    required ChatConfigKeys configKeys,
    required SamplingResolver sampling,
    required String dynamicSystemPrompt,
    required String homeDirectory,
  }) : _providers = providerRepository,
       _agents = agentRepository,
       _config = config,
       _configKeys = configKeys,
       _sampling = sampling,
       _dynamicSystemPrompt = dynamicSystemPrompt,
       _homeDirectory = homeDirectory {
    _reloadsStartingSub = _providers.reloadsStarting.listen(
      _prepareForReload,
    );
    _bindPrimary(_agents.primary);
    _primarySub = _agents.primaryStream.listen(_bindPrimary);
    // Pool occupancy moves while the primary sits idle, so tick the render
    // surface on every snapshot.
    _poolSub = _agents.poolStream.listen(
      (_) => _conversationController.add(_viewed.state),
    );
    // Whether a conversation may be swapped out depends on the roster too.
    _subagentsSub = _agents.subagentsStream.listen(
      (_) => _conversationController.add(_viewed.state),
    );
    // The repository is told what to run under rather than reading it; a
    // change to one field still sends the whole composite.
    _agents.configuration = _agentConfiguration;
    _compactionSub = _config
        .watch(_configKeys.memoryCompactionRatio.global)
        .listen((_) => _agents.configuration = _agentConfiguration);
    _toolCharsSub = _config
        .watch(_configKeys.maxToolCallCharacters.global)
        .listen((_) => _agents.configuration = _agentConfiguration);
    commands = List.unmodifiable([
      Command(
        id: 'chat.stop',
        title: 'Stop generation',
        glyph: '■',
        shortcut: 'Esc',
        description: 'Cancel the turn in progress',
        group: 'Chat',
        availability: _turnInFlightAvailability(),
        invoke: _stopInvoke,
      ),
      Command(
        id: 'chat.clear',
        title: 'Clear chat',
        glyph: '⌫',
        shortcut: 'Ctrl+R',
        description: 'Start a fresh conversation',
        group: 'Chat',
        availability: _modelReadyAvailability(),
        next: _clearFlow,
        invoke: _clearInvoke,
      ),
      Command(
        id: 'chat.load',
        title: 'Load conversation',
        glyph: '⟲',
        description: 'Continue a saved conversation',
        group: 'Chat',
        availability: _historySwapAvailability(),
        next: _loadFlow,
        invoke: _loadInvoke,
      ),
      Command(
        id: 'chat.rewind',
        title: 'Rewind conversation',
        glyph: '⟲',
        shortcut: 'Esc Esc',
        description: 'Pick an earlier message of yours to edit and resend',
        group: 'Chat',
        availability: _historySwapAvailability(),
        invoke: _rewindInvoke,
      ),
      Command(
        id: 'chat.compact',
        title: 'Compact context',
        glyph: '⧉',
        description: 'Fold the conversation so far into a summary',
        group: 'Chat',
        availability: _compactAvailability(),
        invoke: _compactInvoke,
      ),
    ]);
  }

  @override
  late final List<Command> commands;

  static const _clearConfirmKey = ParamKey<bool>('clearConfirm');
  static const _conversationKey = ParamKey<String>('conversation');

  /// What the repository's agents should run under, as configured right now.
  AgentConfiguration get _agentConfiguration => AgentConfiguration(
    compactionRatio: _config.resolve(_configKeys.memoryCompactionRatio.global),
    maxToolCallCharacters: _config.resolve(
      _configKeys.maxToolCallCharacters.global,
    ),
  );

  final ProviderRepository _providers;
  final AgentRepository _agents;
  final ConfigRepository _config;

  final ChatConfigKeys _configKeys;
  final SamplingResolver _sampling;

  /// The date/cwd suffix appended to every resolved system prompt.
  final String _dynamicSystemPrompt;

  /// Shown as `~` when listing where conversations started.
  final String _homeDirectory;
  late final StreamSubscription<void> _reloadsStartingSub;
  late final StreamSubscription<AgentSession> _primarySub;
  late final StreamSubscription<ContextPoolSnapshot> _poolSub;
  late final StreamSubscription<List<SubagentSummary>> _subagentsSub;
  late final StreamSubscription<double> _compactionSub;
  late final StreamSubscription<int> _toolCharsSub;
  StreamSubscription<ConversationState>? _sessionSub;
  StreamSubscription<ConversationState>? _viewedSub;

  /// The provider whose model card the conversation already carries.
  AgentProvider? _attachedProvider;

  /// Single source of truth for which session the UI renders. Commands
  /// (submit/cancel/clear) and turn-lifecycle decisions always target the
  /// primary regardless of this — only rendering follows the view.
  AgentSessionId _viewedId = primaryAgentSessionId;

  /// Ticks whenever the primary OR the viewed subagent emits, so downstream
  /// re-evaluates. Turn logic reads [conversationState] (primary); rendering
  /// reads [viewedConversationState] (viewed). The stream itself only says
  /// "something changed".
  final _conversationController =
      StreamController<ConversationState>.broadcast();

  /// Fires after the primary's history is swapped out wholesale, so the
  /// surface can reset whatever it keyed on the old one.
  final _replacementController =
      StreamController<ConversationReplacement>.broadcast();

  /// Fires when the palette asks for a rewind, so the surface can start the
  /// pick.
  final _rewindRequestController = StreamController<void>.broadcast();

  /// The session driving turns and mutations — always the primary.
  AgentSession get _primary => _agents.primary;

  /// The session being rendered — the primary, or a selected subagent.
  AgentSession get _viewed => _agents.sessionFor(_viewedId) ?? _agents.primary;

  /// (Re)bind the primary session's stream — the turn-lifecycle source. Called
  /// on construction and each placeholder ⇄ live swap.
  void _bindPrimary(AgentSession primary) {
    unawaited(_sessionSub?.cancel());
    _sessionSub = primary.stream.listen(_conversationController.add);
    _conversationController.add(primary.state);
  }

  // ── Viewed session ────────────────────────────────────────

  /// Which session the UI is currently rendering.
  AgentSessionId get viewedSessionId => _viewedId;

  /// True while a subagent (not the primary) is being viewed.
  bool get viewingSubagent => _viewedId != primaryAgentSessionId;

  /// Switch which session feeds the render surface. A subagent's own stream is
  /// tracked only while it's viewed; the primary always ticks via [_sessionSub]
  /// so turn logic is never starved. Re-emits immediately for an instant swap.
  void viewSession(AgentSessionId id) {
    if (id == _viewedId) return;
    _viewedId = id;
    unawaited(_viewedSub?.cancel());
    _viewedSub = null;
    if (id != primaryAgentSessionId) {
      _viewedSub = _viewed.stream.listen(_conversationController.add);
    }
    _conversationController.add(_viewed.state);
  }

  /// Return to viewing the primary.
  void viewPrimary() => viewSession(primaryAgentSessionId);

  // ── Streams ───────────────────────────────────────────────

  /// Fires on any primary- or viewed-session change. A re-evaluate tick.
  Stream<ConversationState> get conversationStream =>
      _conversationController.stream;

  /// Fires once per clear, load, or rewind, after the new history is in
  /// place.
  Stream<ConversationReplacement> get conversationReplacements =>
      _replacementController.stream;

  /// Fires once per palette request to rewind; the surface takes the pick
  /// from there.
  Stream<void> get rewindRequests => _rewindRequestController.stream;

  /// The subagent roster for the zone bar. Replays the current roster to the
  /// subscriber before live updates so a late subscriber isn't left empty.
  Stream<List<SubagentSummary>> get subagentSummariesStream async* {
    yield _agents.subagents;
    yield* _agents.subagentsStream;
  }

  List<SubagentSummary> get subagents => _agents.subagents;

  // ── State ─────────────────────────────────────────────────

  /// The PRIMARY's conversation state — drives turn-lifecycle transitions.
  ConversationState get conversationState => _primary.state;

  /// The VIEWED session's conversation state — drives rendering (timeline,
  /// reasoning snippet).
  ConversationState get viewedConversationState => _viewed.state;

  /// Context stats of the VIEWED session (shown in the header), projected from
  /// the shared-pool snapshot the repository mirrors.
  ChatContextStats? get stats => _agents.statsFor(_viewedId);

  /// The PRIMARY's turn failure (drives `FailedState`).
  TurnFailure? get failure => _primary.failure;

  /// True when a turn can be started right now — a live primary agent is ready
  /// and no turn is already in flight.
  bool get canSubmit =>
      _modelReady &&
      _primary.canRunTurns &&
      _primary.conversationPhase == ConversationPhase.idle;

  /// True when the conversation can be folded right now: a turn could start
  /// and there is history since the last compaction to fold.
  bool get canCompact => canSubmit && _primary.transcript.hasFoldableHistory;

  /// True when the history may be cut back to an earlier user message right
  /// now.
  bool get canRewind => _historySwapGate() is Available;

  // ── Commands: lifecycle ──────────────────────────────────

  /// Every saved conversation, as the picker sees them.
  Future<List<ConversationSummary>> conversations() => _agents.conversations();

  /// Swap the saved conversation [id] in for the current one.
  Future<LoadConversationResult> load(String id) async {
    viewPrimary();
    final result = await _agents.load(id);
    if (result is ConversationLoaded) _announceLoaded();
    return result;
  }

  /// Re-seeds the loaded model card, says what happened, and flags a change
  /// of working directory so the history and the tools are not silently at
  /// odds.
  void _announceLoaded() {
    final card = _readyModelCard();
    if (card != null) _primary.recordModelChange(card);
    _primary.addNotice(ChatStrings.conversationLoaded);
    final from = _primary.transcript.workingDirectory;
    final to = _agents.workingDirectory;
    if (from != to) {
      _primary.addNotice(ChatStrings.workingDirectoryChanged(from, to));
    }
    _replacementController.add(const LoadedFromDisk());
  }

  /// Cut the history back to just before the user message [entryId].
  RewindResult rewindTo(String entryId) {
    viewPrimary();
    final result = _agents.rewindTo(entryId);
    if (result case Rewound(:final message)) {
      _replacementController.add(RewoundToMessage(message: message));
    }
    return result;
  }

  /// Hand the primary agent provider to the repository, which spawns the agent
  /// and swaps in a live session. Coordinated in one call so callers can't
  /// half-attach. A provider seen for the first time also stamps its model
  /// card into the conversation.
  void attachSession({
    required AgentProvider primary,
    required int primaryContextSize,
  }) => unawaited(_attach(primary, primaryContextSize));

  Future<void> _attach(AgentProvider primary, int primaryContextSize) async {
    await _agents.bindProvider(
      primary,
      contextSize: primaryContextSize,
      systemPrompt: _resolveSystemPrompt(),
    );
    if (identical(_attachedProvider, primary)) return;
    _attachedProvider = primary;
    final card = _readyModelCard();
    if (card != null) _primary.recordModelChange(card);
  }

  /// The current chat system prompt: the resolved global override plus the
  /// dynamic portion.
  String _resolveSystemPrompt() =>
      _config.resolve(_configKeys.systemPrompt.global) + _dynamicSystemPrompt;

  @override
  ToolDefinitions get definitions => subagentControlDefinitions;

  @override
  Future<Job> respond(ToolCallInvocation invocation) =>
      switch (invocation.toolName) {
        subagentReadName => _readSubagent(invocation),
        _ => _spawnSubagent(invocation),
      };

  Future<Job> _spawnSubagent(ToolCallInvocation invocation) async {
    final prompt = (invocation.arguments['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return Job.failed('$subagentName requires a non-empty "prompt".');
    }
    final title = (invocation.arguments['title'] as String?)?.trim() ?? '';
    return _agents.startSubagent(
      callId: invocation.callId,
      prompt: prompt,
      label: title.isEmpty ? 'Subagent' : title,
    );
  }

  Future<Job> _readSubagent(ToolCallInvocation invocation) async {
    final id = (invocation.arguments['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) {
      return Job.failed('$subagentReadName requires a non-empty "id".');
    }
    final after = invocation.arguments['after'] as String?;
    final read = await _agents.readSubagent(
      id: id,
      wholeTranscript:
          invocation.arguments['include'] == subagentTranscriptView,
      maxChars: invocation.maxOutputChars - _readTrailerChars,
      after: after,
    );

    return switch (read) {
      SubagentReadBusy() => Job.done(
        'Subagent is busy, wait until notified of its completion.',
      ),
      SubagentReadUnknown() => Job.failed('No subagent "$id" here.'),
      SubagentReadPage(:final text, :final next, :final remaining) => Job.done(
        next == null
            ? text
            : '$text\n\n[$remaining more — '
                  '$subagentReadName(id: "$id", after: "$next")]',
      ),
      SubagentReadEnd() when after != null => Job.done('Fully read.'),
      SubagentReadEnd() => Job.done('Subagent "$id" produced nothing.'),
      SubagentReadCursorLost() => Job.failed(
        'Unknown cursor. Read again without "after" to start over.',
      ),
      SubagentReadBlockTooWide(:final chars) => Job.failed(
        'The next block is $chars characters, over the '
        '${invocation.maxOutputChars} this call may return.',
      ),
    };
  }

  // ── Commands: conversation mutations ─────────────────────

  void addSystemMessage(String text) => _primary.addNotice(text);

  /// Stop a running subagent.
  void stopSubagent(AgentSessionId id) => _agents.stopSubagent(id);

  /// Drop settled subagents from the roster to reclaim zone-bar space, once
  /// none are still running.
  void clearSettledSubagents() => unawaited(_agents.clearSettledSubagents());

  /// Wipe the conversation and re-seed with just the loaded model card.
  void clear() {
    final card = _readyModelCard();
    if (card == null) return;
    _agents.clear();
    _primary.recordModelChange(card);
    _replacementController.add(const StartedFresh());
  }

  ModelSnapshot? _readyModelCard() {
    final status = _providers.status;
    if (status is! ProviderStatusReady) return null;
    return ModelSnapshot.remote(
      modelId: status.model.id,
      displayName: status.model.name,
      contextSize: status.contextWindow,
      provider: status.providerName,
    );
  }

  // ── Commands: turn execution ─────────────────────────────

  /// Submit a user message and start a turn.
  Future<bool> submit({
    required String message,
    required String reasoningMode,
  }) {
    final status = _providers.status;
    if (status is! ProviderStatusReady) return Future.value(false);
    if (!_primary.canRunTurns) return Future.value(false);
    if (_primary.conversationPhase != ConversationPhase.idle) {
      return Future.value(false);
    }

    return _primary.beginTurn(
      message: message,
      options: _turnOptions(status, reasoningMode: reasoningMode),
    );
  }

  /// Fold the conversation so far into a summary checkpoint, as its own turn.
  Future<bool> compact() {
    final status = _providers.status;
    if (status is! ProviderStatusReady || !canCompact) {
      return Future.value(false);
    }
    return _primary.beginCompactionTurn(
      _turnOptions(status, reasoningMode: 'auto'),
    );
  }

  /// What the next turn runs under, as configured and provided right now.
  TurnOptions _turnOptions(
    ProviderStatusReady status, {
    required String reasoningMode,
  }) => TurnOptions(
    systemPrompt: _resolveSystemPrompt(),
    sampling: _sampling(),
    reasoningMode: reasoningMode,
    compactionReasoningMode: status.compactionReasoningMode,
  );

  void cancel() => _primary.cancel();

  // ── Palette commands ─────────────────────────────────────

  bool get _turnInFlight =>
      conversationState.conversationPhase == ConversationPhase.turnInFlight;

  bool get _modelReady => _providers.status is ProviderStatusReady;

  /// Available while the primary is mid-turn; re-checked on its every tick.
  Stream<Availability> _turnInFlightAvailability() =>
      gatedAvailability<Object?>(
        () => null,
        conversationStream,
        (_) => _turnInFlight
            ? const Available()
            : const Unavailable('no turn running'),
      );

  /// Availability that follows the provider's readiness.
  Stream<Availability> _modelReadyAvailability() => gatedAvailability<Object?>(
    () => null,
    _providers.statusStream,
    (_) =>
        _modelReady ? const Available() : const Unavailable('no model loaded'),
  );

  /// Follows the primary's every tick, which also covers the provider coming
  /// and going: each swaps the primary session and re-emits.
  Stream<Availability> _compactAvailability() => gatedAvailability<Object?>(
    () => null,
    conversationStream,
    (_) => _compactGate(),
  );

  /// Follows the primary's every tick, which also covers the roster: a
  /// running subagent still belongs to the conversation being left.
  Stream<Availability> _historySwapAvailability() => gatedAvailability<Object?>(
    () => null,
    conversationStream,
    (_) => _historySwapGate(),
  );

  /// Whether the primary's history may be swapped out right now, for a saved
  /// conversation or for a prefix of itself.
  Availability _historySwapGate() {
    if (!_modelReady || !_primary.canRunTurns) {
      return const Unavailable('no model loaded');
    }
    if (_primary.conversationPhase != ConversationPhase.idle) {
      return const Unavailable('turn in progress');
    }
    if (_agents.subagents.any(
      (subagent) => subagent.status == SubagentStatus.running,
    )) {
      return const Unavailable('subagents still running');
    }
    return const Available();
  }

  Availability _compactGate() {
    if (!_modelReady || !_primary.canRunTurns) {
      return const Unavailable('no model loaded');
    }
    if (_primary.conversationPhase != ConversationPhase.idle) {
      return const Unavailable('turn in progress');
    }
    if (!_primary.transcript.hasFoldableHistory) {
      return const Unavailable('nothing to compact');
    }
    return const Available();
  }

  Future<CommandResult> _stopInvoke(Answers answers) async {
    if (!_turnInFlight) return const CommandRejected('no turn running');
    cancel();
    return const CommandRan();
  }

  Param? _clearFlow(Answers soFar) => soFar.maybe(_clearConfirmKey) == null
      ? const ConfirmParam(
          key: _clearConfirmKey,
          label: 'Clear the conversation?',
          danger: true,
        )
      : null;

  Future<CommandResult> _clearInvoke(Answers answers) async {
    if (!_modelReady) return const CommandRejected('no model loaded');
    clear();
    return const CommandRan();
  }

  Param? _loadFlow(Answers soFar) {
    if (soFar.maybe(_conversationKey) != null) return null;
    final picker = ConversationPicker(
      summaries: conversations(),
      homeDirectory: _homeDirectory,
      currentConversationId: _primary.transcript.conversationId,
    );
    return ChoiceParam<String>.searchable(
      key: _conversationKey,
      label: 'Conversation',
      search: picker.search,
    );
  }

  Future<CommandResult> _loadInvoke(Answers answers) async {
    if (_historySwapGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    return switch (await load(answers.get(_conversationKey))) {
      ConversationLoaded() => const CommandRan(),
      ConversationNotFound() => const CommandRejected(
        'conversation no longer exists',
      ),
    };
  }

  Future<CommandResult> _rewindInvoke(Answers answers) async {
    if (_historySwapGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    _rewindRequestController.add(null);
    return const CommandRan();
  }

  Future<CommandResult> _compactInvoke(Answers answers) async {
    if (_compactGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    return await compact()
        ? const CommandRan()
        : const CommandRejected('compaction did not start');
  }

  // ── Commands: reload pipeline ────────────────────────────

  /// Detaches the live provider before a reconnect tears its handle down.
  /// The fresh handle is rebound when the provider reaches ready. Snaps the
  /// view back to the primary so a reload never leaves us on a stale subagent.
  void _prepareForReload(void _) {
    viewPrimary();
    unawaited(_agents.bindProvider(null));
  }

  /// Releases resources owned by this use case. The upstream
  /// [ProviderRepository] and [AgentRepository] are owned by the
  /// bootstrap layer and are NOT disposed here.
  Future<void> dispose() async {
    await _reloadsStartingSub.cancel();
    await _primarySub.cancel();
    await _poolSub.cancel();
    await _subagentsSub.cancel();
    await _compactionSub.cancel();
    await _toolCharsSub.cancel();
    await _sessionSub?.cancel();
    await _viewedSub?.cancel();
    await _conversationController.close();
    await _replacementController.close();
    await _rewindRequestController.close();
  }
}

/// Room a read page holds back for the trailer naming its next cursor.
const int _readTrailerChars = 128;
