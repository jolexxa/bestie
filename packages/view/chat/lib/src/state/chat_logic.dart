import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/state/chat_cubit.dart';
import 'package:bestie_chat_view/src/state/chat_data.dart';
import 'package:bestie_chat_view/src/state/chat_input.dart';
import 'package:bestie_chat_view/src/state/chat_output.dart';
import 'package:bestie_chat_view/src/state/composer_mode.dart';
import 'package:bestie_chat_view/src/state/models/chat_phase.dart';
import 'package:bestie_chat_view/src/state/models/write_access_choice.dart';
import 'package:bestie_chat_view/src/state/selection/selection.dart';
import 'package:bestie_chat_view/src/state/subagent_zone/subagent_zone.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart' hide useCase;
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

/// How quickly a second Escape has to follow the first to enter rewind.
const Duration rewindChordWindow = Duration(milliseconds: 500);

/// Base state for the chat logic block.
///
/// Exposes blackboard data via getters so the UI can consume these states
/// directly. Provider state is delegated to [ProviderUseCase], conversation
/// state is delegated to the current [AgentSession].
@model
sealed class ChatState extends StateLogic<ChatState> {
  ChatState() {
    on<CycleReasoning>(_onCycleReasoning);
    on<MoveSelectionUp>(_onMoveSelectionUp);
    on<MoveSelectionDown>(_onMoveSelectionDown);
    on<SelectTimelineItem>(_onSelectTimelineItem);
    on<RevealTimelineItem>(_onRevealTimelineItem);
    on<SelectVisibleItem>(_onSelectVisibleItem);
    on<SelectionPositionChanged>(_onSelectionPositionChanged);
    on<EnterSubagentZone>(_onEnterSubagentZone);
    on<ExitSubagentZone>(_onExitSubagentZone);
    on<MoveSubagentUp>(_onMoveSubagentUp);
    on<MoveSubagentDown>(_onMoveSubagentDown);
    on<StopHighlightedSubagent>(_onStopHighlightedSubagent);
    on<SelectSubagentRow>(_onSelectSubagentRow);
    on<SubagentsChanged>(_onSubagentsChanged);
    on<ActiveJobsChanged>(_onActiveJobsChanged);
    on<SandboxReadinessChanged>(_onSandboxReadinessChanged);
    on<InitializeSandbox>(_onInitializeSandbox);
    on<WriteAccessRequestChanged>(_onWriteAccessRequestChanged);
    on<AnswerWriteAccess>(_onAnswerWriteAccess);
    on<ToggleWriteAccessChoice>(_onToggleWriteAccessChoice);
    on<ConfirmWriteAccess>(_onConfirmWriteAccess);
  }

  ChatData get data => get<ChatData>();
  ChatUseCase get useCase => get<ChatUseCase>();
  ProviderUseCase get provider => get<ProviderUseCase>();
  ToolsUseCase get tools => get<ToolsUseCase>();
  SandboxUseCase get sandboxUseCase => get<SandboxUseCase>();

  // ── Delegation to use case (provider side) ────────────

  ProviderStatusReady? get _readyProvider => switch (provider.status) {
    final ProviderStatusReady ready => ready,
    _ => null,
  };

  /// Reasoning modes the connected model offers, `auto` first.
  List<String> get reasoningModes =>
      _readyProvider?.reasoningModes ?? const [reasoningAuto];

  /// The effort the provider applies under `auto`, when it says.
  String? get defaultEffortLabel => _readyProvider?.defaultEffortLabel;

  // ── Delegation to use case (conversation side) ────────

  /// Rendering follows the VIEWED session (primary or a selected subagent);
  /// turn-lifecycle logic reads `useCase.conversationState` (always primary).
  List<TimelineItem> get timelineItems =>
      useCase.viewedConversationState.timelineItems;

  /// One-line snippet of the in-flight turn's latest reasoning block, if any.
  String? get reasoningSnippet => switch (useCase.viewedConversationState) {
    TurnInProgress(:final reasoningSnippet) => reasoningSnippet,
    ConversationIdle() => null,
  };

  ChatContextStats? get stats => useCase.stats;

  // ── Subagent zone (pseudo-focus) ──────────────────────

  SubagentZoneLogic get _zone => get<SubagentZoneLogic>();

  /// The subagent roster shown in the zone bar.
  List<SubagentSummary> get subagents => _zone.value.subagents;

  /// True while pseudo-focus is in the subagent zone.
  bool get zoneActive => _zone.value.active;

  /// Highlighted zone row: `0` is Primary, `1..N` address `subagents[i-1]`.
  int get highlightedSubagentIndex => _zone.value.highlightedIndex;

  /// True while the zone highlight sits on a subagent rather than Primary.
  bool get zoneHighlightsSubagent => _zone.value.selectedSubagentId != null;

  /// True while the agent at hand is read-only — any agent but the primary.
  /// The input is hidden/disabled as a read-only cue.
  bool get readonly => useCase.viewingSubagent;

  /// Where the sandbox stands.
  SandboxReadiness get sandboxReadiness => data.sandboxReadiness;

  /// The agent's ask for write access awaiting the user.
  WriteAccessRequest? get pendingWriteAccess => data.pendingWriteAccess;

  /// Which answer to [pendingWriteAccess] keyboard focus rests on.
  WriteAccessChoice get writeAccessChoice => data.writeAccessChoice;

  /// What the composer slot shows.
  ComposerMode get composer {
    if (rewinding) return const RewindingComposer();
    final asked = pendingWriteAccess;
    if (asked != null) return WriteAccessPrompt(asked);
    if (readonly) return const ReadOnlyComposer();
    if (sandboxReadiness is! SandboxReady) return SandboxGate(sandboxReadiness);
    return const Composing();
  }

  // ── Rewind ────────────────────────────────────────────

  /// True while the user is picking an earlier message to cut back to.
  bool get rewinding => false;

  /// True when the history could be cut back right now.
  bool get canRewind => useCase.canRewind;

  /// Timeline indices of the user's own messages — the rewind targets.
  List<int> get userMessageIndices => [
    for (final (index, item) in timelineItems.indexed)
      if (item is MessageTimelineItem && item.role == Role.user) index,
  ];

  // ── Local state ───────────────────────────────────────

  String get reasoningMode => data.reasoningMode;

  bool get isReasoningActive =>
      data.reasoningMode != reasoningAuto && data.reasoningMode != reasoningOff;
  bool get canCycleReasoning => reasoningModes.length > 1;

  /// Unsettled tool jobs — drives the idle-state stop affordance.
  int get activeJobs => data.activeJobs;

  bool get loading => false;
  String? get error => null;

  /// True while the agent at hand is mid-turn.
  bool get generating => useCase.viewedConversationState is TurnInProgress;

  /// True while the primary's turn lifecycle is active.
  bool get isPrimaryTurnActive => false;

  /// The phase the agent at hand presents as.
  ChatPhase get phase => _phaseOf(useCase.viewedConversationState);

  SelectionLogic get _selection => get<SelectionLogic>();

  /// Concrete position of the selection cursor. Always real, never a
  /// sentinel — `SelectionLogic`'s state machine guarantees it via
  /// `TimelineShapeChanged` initialization in the `Unobserved` state.
  SelectionPosition get selectionPosition => _selection.value.position;

  /// Item-level index of the selected slot.
  int get effectiveSelectedIndex => selectionPosition.itemIndex;

  List<int> get _childCounts => [
    for (final i in timelineItems) i.childSelectionCount,
  ];

  /// The currently-selected timeline item (message row OR compaction
  /// marker). Null when the timeline is empty.
  TimelineItem? get selectedTimelineItem {
    final items = timelineItems;
    if (items.isEmpty) return null;
    return items[effectiveSelectedIndex];
  }

  // ── Shared handlers ───────────────────────────────────

  Transition _onSandboxReadinessChanged(SandboxReadinessChanged input) {
    data.sandboxReadiness = input.readiness;
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onInitializeSandbox(InitializeSandbox _) {
    unawaited(sandboxUseCase.initialize());
    return toSelf();
  }

  Transition _onWriteAccessRequestChanged(WriteAccessRequestChanged input) {
    data
      ..pendingWriteAccess = input.request
      ..writeAccessChoice = WriteAccessChoice.deny;
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onAnswerWriteAccess(AnswerWriteAccess input) {
    _answerWriteAccess(allow: input.allow);
    return toSelf();
  }

  Transition _onToggleWriteAccessChoice(ToggleWriteAccessChoice _) {
    data.writeAccessChoice = data.writeAccessChoice.other;
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onConfirmWriteAccess(ConfirmWriteAccess _) {
    _answerWriteAccess(allow: writeAccessChoice.allows);
    return toSelf();
  }

  void _answerWriteAccess({required bool allow}) {
    final asked = pendingWriteAccess;
    if (asked != null) {
      sandboxUseCase.answerWriteAccess(asked.id, allow: allow);
    }
  }

  Transition _onCycleReasoning(CycleReasoning _) {
    final modes = reasoningModes;
    if (modes.length <= 1) return toSelf();
    final currentIndex = modes.indexOf(data.reasoningMode);
    data.reasoningMode = modes[(currentIndex + 1) % modes.length];
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onMoveSelectionUp(MoveSelectionUp _) {
    _selection.input(const MoveUp());
    output(const ItemSelected());
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onMoveSelectionDown(MoveSelectionDown _) {
    _selection.input(const MoveDown());
    output(const ItemSelected());
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onSelectTimelineItem(SelectTimelineItem input) {
    _selection.input(SelectItem(input.itemIndex));
    output(const ItemSelected());
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onRevealTimelineItem(RevealTimelineItem input) {
    _selection.input(SelectItem(input.itemIndex));
    output(CursorMoved(_selection.value.position));
    output(const ItemSelected());
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onSelectVisibleItem(SelectVisibleItem input) {
    _selection.input(SelectItem(input.itemIndex));
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onSelectionPositionChanged(SelectionPositionChanged input) {
    output(CursorMoved(input.position));
    output(const StateUpdated());
    return toSelf();
  }

  // ── Subagent zone handlers ────────────────────────────

  /// Point the render surface at [id], re-clamp the timeline cursor to the new
  /// shape, and repaint.
  Transition _switchViewTo(AgentSessionId id) {
    useCase.viewSession(id);
    _observeTimelineShape();
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onEnterSubagentZone(EnterSubagentZone _) {
    if (subagents.isEmpty) return toSelf();
    _zone.input(const EnterZone());
    return _switchViewTo(_zone.value.selectedSessionId);
  }

  Transition _onExitSubagentZone(ExitSubagentZone _) {
    _zone.input(const ExitZone());
    return _switchViewTo(primaryAgentSessionId);
  }

  Transition _onMoveSubagentUp(MoveSubagentUp _) {
    if (!zoneActive) return toSelf();
    _zone.input(const ZoneMoveUp());
    return _switchViewTo(_zone.value.selectedSessionId);
  }

  Transition _onMoveSubagentDown(MoveSubagentDown _) {
    if (!zoneActive) return toSelf();
    _zone.input(const ZoneMoveDown());
    return _switchViewTo(_zone.value.selectedSessionId);
  }

  Transition _onStopHighlightedSubagent(StopHighlightedSubagent _) {
    final id = _zone.value.selectedSubagentId;
    if (id != null) useCase.stopSubagent(id);
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onSelectSubagentRow(SelectSubagentRow input) {
    _zone.input(ZoneSelectRow(input.index));
    return _switchViewTo(_zone.value.selectedSessionId);
  }

  Transition _onSubagentsChanged(SubagentsChanged input) {
    _zone.input(ZoneRosterChanged(input.subagents));
    return _switchViewTo(_zone.value.selectedSessionId);
  }

  Transition _onActiveJobsChanged(ActiveJobsChanged input) {
    data.activeJobs = input.count;
    output(const StateUpdated());
    return toSelf();
  }

  /// A ready provider changes nothing; anything else routes away.
  Transition _stayWhileProviderReady(ProviderStatusChanged input) {
    final status = input.status;
    if (status is ProviderStatusReady) return toSelf();
    return _routeStatus(status);
  }

  /// A turn can start unsolicited — a subagent report delivered back to the
  /// primary. Ride it to completion like a submitted turn.
  Transition _followUnsolicitedTurn(ConversationStateChanged _) {
    _observeTimelineShape();
    output(const StateUpdated());
    if (useCase.conversationState is TurnInProgress) {
      return to<TurnActiveState>();
    }
    return toSelf();
  }

  /// Notify the selection that the timeline shape changed.
  void _observeTimelineShape() {
    _selection.input(TimelineShapeChanged(_childCounts));
  }

  /// Snap the selection cursor back onto the live tail.
  void _followTail() {
    _selection.input(const FollowTail());
  }

  // ── Shared provider status routing ────────────────────

  /// Common routing applied by chat states that don't specially handle the
  /// ready phase. `InitializingState` overrides this in its handler to call
  /// `_onReady` and attach the primary.
  Transition _routeStatus(ProviderStatus status) {
    return switch (status) {
      ProviderStatusReady() => to<InitializingState>(),
      ProviderStatusConnecting() => to<ReconnectingState>(),
      ProviderStatusUnconfigured() => _fail(ChatStrings.providerUnconfigured),
      ProviderStatusFailed(:final failure) => _fail(failure.message),
    };
  }

  /// Routes failure to the chat-level `FailedState`. Adds a system
  /// message so the user sees what went wrong.
  Transition _fail(String error) {
    useCase.addSystemMessage(error);
    return to<FailedState>();
  }
}

// ── States ────────────────────────────────────────────────

/// Initial state — waits for the provider to come up.
@model
final class UninitializedState extends ChatState {
  UninitializedState() {
    on<Start>((_) => _routeStatus(provider.status));

    on<ProviderStatusChanged>((input) => _routeStatus(input.status));
  }

  @override
  ChatPhase get phase => ChatPhase.idle;
}

@model
final class InitializingState extends ChatState {
  InitializingState() {
    // If the provider is already ready when we enter, re-inject its status so
    // the handler below attaches immediately.
    onEnter(() {
      final status = provider.status;
      if (status is ProviderStatusReady) {
        input(ProviderStatusChanged(status));
      }
    });

    on<ProviderStatusChanged>((input) {
      return switch (input.status) {
        final ProviderStatusReady ready => _onReady(ready),
        ProviderStatusConnecting() => _refreshAndStay(),
        ProviderStatusUnconfigured() => _fail(
          ChatStrings.providerUnconfigured,
        ),
        ProviderStatusFailed(:final failure) => _fail(failure.message),
      };
    });
  }

  Transition _refreshAndStay() {
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onReady(ProviderStatusReady status) {
    final primaryHandle = status.handle;
    final isFreshPrimary = !identical(data.lastPrimaryHandle, primaryHandle);
    data.lastPrimaryHandle = primaryHandle;

    if (isFreshPrimary) {
      data.reasoningMode = status.defaultReasoningMode;
    }

    useCase.attachSession(
      primary: primaryHandle,
      primaryContextSize: status.contextWindow,
    );

    return to<ReadyState>();
  }

  @override
  bool get loading => true;

  @override
  ChatPhase get phase => ChatPhase.loading;
}

/// Shared handling for states that let the whole conversation be swapped
/// out. Asking for a clear only reaches the use case; the view-side reset
/// waits for the use case to announce the replacement, so a swap started
/// elsewhere (the palette, say) resets the surface the same way.
base mixin ConversationSwitching on ChatState {
  Transition onClear(Clear _) {
    useCase.clear();
    return toSelf();
  }

  Transition onConversationReplaced(ConversationReplaced input) {
    _selection.input(const ResetSelection());
    output(const StateUpdated());
    output(ConversationSwitched(input.replacement));
    return to<ReadyState>();
  }

  /// A bare Escape stops background jobs, if any, and arms the rewind chord;
  /// a second one inside [rewindChordWindow] completes it.
  Transition onEscapePressed(EscapePressed _) {
    if (activeJobs > 0) tools.stopJobs();
    final now = clock.now();
    final armedAt = data.escapeArmedAt;
    data.escapeArmedAt = now;
    if (armedAt == null || now.difference(armedAt) > rewindChordWindow) {
      return toSelf();
    }
    data.escapeArmedAt = null;
    return onEnterRewind(const EnterRewind());
  }

  /// Enter rewind on the primary with the cursor on the latest user message.
  /// Refused while a subagent is viewed, while the history can't be swapped,
  /// or with nothing to rewind to.
  Transition onEnterRewind(EnterRewind _) {
    if (useCase.viewingSubagent || !useCase.canRewind) return toSelf();
    final targets = userMessageIndices;
    if (targets.isEmpty) return toSelf();
    if (zoneActive) _zone.input(const ExitZone());
    data.cursorBeforeRewind = selectionPosition;
    _selection.input(SelectItem(targets.last));
    output(CursorMoved(_selection.value.position));
    output(const StateUpdated());
    return to<RewindingState>();
  }
}

/// Intermediate base for states where the primary session is guaranteed
/// attached.
@model
sealed class InitializedChatState extends ChatState {}

@model
final class ReadyState extends InitializedChatState with ConversationSwitching {
  ReadyState() {
    on<Clear>(onClear);
    on<ConversationReplaced>(onConversationReplaced);
    on<EscapePressed>(onEscapePressed);
    on<EnterRewind>(onEnterRewind);

    // No turn to cancel — a stop request here escalates to the tool
    // system's jobs, wherever they run.
    on<Cancel>((_) {
      tools.stopJobs();
      return toSelf();
    });

    onEnter(() {
      // First time chat becomes interactive — observe the current
      // timeline so the cursor lands on the tail (latest message)
      // instead of staying at the (0, 0) origin.
      _observeTimelineShape();
      output(const StateUpdated());
    });

    on<Submit>((submitInput) {
      if (submitInput.message.isEmpty) return toSelf();
      // Gate synchronously so we don't transition to an active turn that
      // never starts. The repo also rejects internally as a backstop.
      if (!useCase.canSubmit) return toSelf();

      async(
        useCase.submit(
          message: submitInput.message,
          reasoningMode: reasoningMode,
        ),
      );

      // Sending is the natural moment to reclaim the zone bar: if every
      // subagent has settled, drop them (their reports live on as chat stubs).
      useCase.clearSettledSubagents();

      output(const MessageAccepted());
      _observeTimelineShape();
      _followTail();
      output(CursorMoved(_selection.value.position));
      return to<TurnActiveState>();
    });

    on<ProviderStatusChanged>(_stayWhileProviderReady);
    on<ConversationStateChanged>(_followUnsolicitedTurn);
  }
}

/// The user is picking an earlier message of their own to cut the history
/// back to. The cut itself lands as a replaced conversation, which is what
/// carries this state back to [ReadyState].
@model
final class RewindingState extends InitializedChatState
    with ConversationSwitching {
  RewindingState() {
    on<Clear>(onClear);
    on<ConversationReplaced>(onConversationReplaced);
    on<RewindMoveUp>((_) => _step(toward: -1));
    on<RewindMoveDown>((_) => _step(toward: 1));
    on<ConfirmRewind>((_) => _confirm(effectiveSelectedIndex));
    on<CancelRewind>(_onCancel);
    on<ProviderStatusChanged>(_stayWhileProviderReady);
    on<ConversationStateChanged>(_followUnsolicitedTurn);
    onExit(() => data.cursorBeforeRewind = null);
  }

  @override
  bool get rewinding => true;

  @override
  ChatPhase get phase => ChatPhase.rewinding;

  /// A click confirms the clicked message instead of merely selecting it.
  @override
  Transition _onSelectTimelineItem(SelectTimelineItem input) =>
      _confirm(input.itemIndex);

  /// Hop to the nearest user message above (`-1`) or below (`1`) the cursor.
  Transition _step({required int toward}) {
    final current = effectiveSelectedIndex;
    final targets = userMessageIndices;
    final next = toward < 0
        ? targets.where((index) => index < current).lastOrNull
        : targets.where((index) => index > current).firstOrNull;
    if (next == null) return toSelf();
    _selection.input(SelectItem(next));
    output(CursorMoved(_selection.value.position));
    output(const StateUpdated());
    return toSelf();
  }

  Transition _confirm(int index) {
    final items = timelineItems;
    if (index < 0 || index >= items.length) return toSelf();
    final item = items[index];
    if (item is! MessageTimelineItem || item.role != Role.user) {
      return toSelf();
    }
    useCase.rewindTo(item.id);
    return toSelf();
  }

  Transition _onCancel(CancelRewind _) {
    final previous = data.cursorBeforeRewind;
    if (previous != null) _selection.input(SelectItem(previous.itemIndex));
    output(CursorMoved(_selection.value.position));
    output(const StateUpdated());
    return to<ReadyState>();
  }
}

/// The provider is reconnecting after its configuration changed.
@model
final class ReconnectingState extends ChatState {
  ReconnectingState() {
    // If the provider already advanced past connecting before this state was
    // entered, route immediately.
    onEnter(() {
      final status = provider.status;
      if (status is! ProviderStatusConnecting) {
        input(ProviderStatusChanged(status));
      }
    });

    on<ProviderStatusChanged>((input) {
      final status = input.status;
      if (status is ProviderStatusConnecting) return toSelf();
      return _routeStatus(status);
    });
  }

  @override
  bool get loading => true;

  @override
  ChatPhase get phase => ChatPhase.reloading;
}

@model
final class TurnActiveState extends InitializedChatState {
  TurnActiveState() {
    onEnter(() => _sawTurn = false);

    on<ConversationStateChanged>((input) {
      _observeTimelineShape();
      // The conversation stream delivers asynchronously — an Idle emitted
      // before the turn began can land after this state is entered. Judge
      // by the repository's current state, and never settle before the
      // turn has actually been observed in flight.
      final state = useCase.conversationState;
      if (state is TurnInProgress) {
        _sawTurn = true;
        return _updateAndStay();
      }
      if (state case ConversationIdle(failure: final f?)) {
        return _onError(f);
      }
      if (!_sawTurn) return _updateAndStay();
      return _onComplete();
    });

    on<Cancel>((_) {
      useCase.cancel();
      return toSelf();
    });

    on<Dispose>((_) {
      useCase.cancel();
      return toSelf();
    });

    on<ProviderStatusChanged>((input) {
      final status = input.status;
      if (status is ProviderStatusReady) return toSelf();
      useCase.cancel();
      return _routeStatus(status);
    });
  }

  var _sawTurn = false;

  Transition _updateAndStay() {
    output(const StateUpdated());
    return toSelf();
  }

  Transition _onComplete() {
    output(const StateUpdated());
    return to<ReadyState>();
  }

  Transition _onError(TurnFailure failure) {
    output(TurnErrorLog(failure.summary));
    return to<FailedState>();
  }

  @override
  bool get isPrimaryTurnActive => true;
}

/// The phase a session's conversation state presents as.
ChatPhase _phaseOf(ConversationState state) => switch (state) {
  ConversationIdle() => ChatPhase.idle,
  TurnInProgress(:final activity) => switch (activity) {
    TurnActivity.thinking => ChatPhase.reasoning,
    TurnActivity.responding => ChatPhase.responding,
    TurnActivity.draftingToolCall => ChatPhase.draftingTool,
    TurnActivity.executingTools => ChatPhase.executingTool,
    TurnActivity.compacting => ChatPhase.compacting,
  },
};

@model
final class FailedState extends ChatState with ConversationSwitching {
  FailedState() {
    on<Clear>(onClear);
    on<ConversationReplaced>(onConversationReplaced);
    on<EscapePressed>(onEscapePressed);
    on<EnterRewind>(onEnterRewind);

    on<ProviderStatusChanged>((input) {
      final status = input.status;
      if (status is ProviderStatusFailed ||
          status is ProviderStatusUnconfigured) {
        output(const StateUpdated());
        return toSelf();
      }
      return _routeStatus(status);
    });

    on<Submit>((submitInput) {
      if (submitInput.message.isEmpty) return toSelf();
      if (provider.status is! ProviderStatusReady) return toSelf();
      // The provider is healthy — this was a turn-level error. Re-fire
      // Submit into ReadyState so the user can retry without losing
      // history.
      input(submitInput);
      return to<ReadyState>();
    });
  }

  @override
  String get error => useCase.failure?.summary ?? 'Unknown error';

  /// Typed turn failure.
  TurnFailure? get failure => useCase.failure;

  @override
  ChatPhase get phase => ChatPhase.error;
}

// ── Logic block ─────────────────────────────────────────

@PartOf(ChatCubit)
final class ChatLogic extends LogicBlock<ChatState> {
  /// [chatData] is injectable for tests. Whichever instance is used, its
  /// reasoning mode is seeded here from the connected model's default.
  ChatLogic({
    required ChatUseCase useCase,
    required ProviderUseCase providerUseCase,
    required ToolsUseCase toolsUseCase,
    required SandboxUseCase sandboxUseCase,
    ChatData? chatData,
  }) {
    set(
      (chatData ??
            (ChatData()..reasoningMode = _seedReasoningMode(providerUseCase)))
        ..sandboxReadiness = sandboxUseCase.readiness
        ..pendingWriteAccess = sandboxUseCase.pendingWriteAccess,
    );
    set(useCase);
    set(providerUseCase);
    set(toolsUseCase);
    set(sandboxUseCase);
    set(UninitializedState());
    set(InitializingState());
    set(ReadyState());
    set(ReconnectingState());
    set(TurnActiveState());
    set(RewindingState());
    set(FailedState());
    set(SelectionLogic());
    set(SubagentZoneLogic());
  }

  static String _seedReasoningMode(ProviderUseCase providerUseCase) =>
      switch (providerUseCase.status) {
        ProviderStatusReady(:final defaultReasoningMode) =>
          defaultReasoningMode,
        _ => reasoningAuto,
      };

  StreamSubscription<ProviderStatus>? _providerSub;
  StreamSubscription<ConversationState>? _conversationSub;
  StreamSubscription<ConversationReplacement>? _replacementSub;
  StreamSubscription<void>? _rewindRequestSub;
  StreamSubscription<List<SubagentSummary>>? _subagentsSub;
  StreamSubscription<int>? _activeJobsSub;
  StreamSubscription<SandboxReadiness>? _sandboxSub;
  StreamSubscription<WriteAccessRequest?>? _writeAccessSub;
  LogicBlockBinding<SelectionState>? _selectionBinding;
  LogicBlockBinding<SubagentZoneState>? _zoneBinding;

  @override
  void onStart() {
    final selectionLogic = get<SelectionLogic>();
    _selectionBinding = selectionLogic.bind()
      ..onOutput<PositionChanged>(
        (output) => input(SelectionPositionChanged(output.position)),
      );
    selectionLogic.start();

    final zoneLogic = get<SubagentZoneLogic>();
    _zoneBinding = zoneLogic.bind();
    zoneLogic.start();

    final providerUseCase = get<ProviderUseCase>();
    _providerSub = providerUseCase.statusStream.listen(
      (status) => input(ProviderStatusChanged(status)),
    );
    final useCase = get<ChatUseCase>();
    _conversationSub = useCase.conversationStream.listen(
      (state) => input(ConversationStateChanged(state)),
    );
    _replacementSub = useCase.conversationReplacements.listen(
      (replacement) => input(ConversationReplaced(replacement)),
    );
    _rewindRequestSub = useCase.rewindRequests.listen(
      (_) => input(const EnterRewind()),
    );
    _subagentsSub = useCase.subagentSummariesStream.listen(
      (roster) => input(SubagentsChanged(roster)),
    );
    final toolsUseCase = get<ToolsUseCase>();
    get<ChatData>().activeJobs = toolsUseCase.activeJobCount;
    _activeJobsSub = toolsUseCase.activeJobs.listen(
      (count) => input(ActiveJobsChanged(count)),
    );
    final sandboxUseCase = get<SandboxUseCase>();
    _sandboxSub = sandboxUseCase.readinessStream.listen(
      (readiness) => input(SandboxReadinessChanged(readiness)),
    );
    _writeAccessSub = sandboxUseCase.pendingWriteAccessStream.listen(
      (request) => input(WriteAccessRequestChanged(request)),
    );
  }

  @override
  void onStop() {
    unawaited(_sandboxSub?.cancel());
    _sandboxSub = null;
    unawaited(_writeAccessSub?.cancel());
    _writeAccessSub = null;
    unawaited(_providerSub?.cancel());
    unawaited(_conversationSub?.cancel());
    unawaited(_replacementSub?.cancel());
    unawaited(_rewindRequestSub?.cancel());
    unawaited(_subagentsSub?.cancel());
    unawaited(_activeJobsSub?.cancel());
    _activeJobsSub = null;
    _providerSub = null;
    _conversationSub = null;
    _replacementSub = null;
    _rewindRequestSub = null;
    _subagentsSub = null;
    _selectionBinding?.dispose();
    _selectionBinding = null;
    _zoneBinding?.dispose();
    _zoneBinding = null;
    get<SelectionLogic>().stop();
    get<SubagentZoneLogic>().stop();
  }

  @override
  Transition getInitialState() => to<UninitializedState>();
}
