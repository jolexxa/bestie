import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider, AgentRunFailureReason;
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/state/chat_data.dart';
import 'package:bestie_chat_view/src/state/chat_input.dart';
import 'package:bestie_chat_view/src/state/chat_logic.dart';
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
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:logic_blocks/logic_blocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

class _MockChatUseCase extends Mock implements ChatUseCase {}

class _MockProviderUseCase extends Mock implements ProviderUseCase {}

class _MockToolsUseCase extends Mock implements ToolsUseCase {}

class _MockSandboxUseCase extends Mock implements SandboxUseCase {}

class _MockAgentProvider extends Mock implements AgentProvider {}

class _FakeAgentProvider extends Fake implements AgentProvider {}

const _writeAsk = WriteAccessRequest(
  id: 'write-access-1',
  path: '/home/cow/.pub-cache',
  shownPath: '~/.pub-cache',
  reason: 'dart pub get',
  agentId: 'primary',
);

const _efforts = ProviderReasoningEfforts(
  efforts: ['low', 'medium', 'high'],
  canDisable: true,
  defaultEffort: 'medium',
);

ProviderStatusReady _ready({
  ProviderReasoning? reasoning,
  AgentProvider? handle,
}) => ProviderStatusReady(
  model: ResolvedModel(
    ref: _modelRef,
    name: 'GPT-4o mini',
    contextWindow: 1024,
    supportsTools: true,
    reasoning: reasoning,
  ),
  handle: handle ?? _MockAgentProvider(),
  keyInfo: const ProviderKeyInfo(label: 'key', usage: 0, isFreeTier: false),
  providerName: 'OpenRouter',
);

const _modelRef = ProviderModelRef(
  providerId: 'openrouter',
  modelId: 'openai/gpt-4o-mini',
);

const ProviderStatus _connecting = ProviderStatusConnecting(model: _modelRef);

const ProviderStatus _unconfigured = ProviderStatusUnconfigured();

const ProviderStatus _failed = ProviderStatusFailed(
  failure: ProviderFailure(kind: InferenceFailureKind.auth, message: 'boom'),
  model: _modelRef,
);

ConversationIdle _idleState({List<TimelineItem> timelineItems = const []}) =>
    ConversationIdle(
      timelineItems: timelineItems,
      conversationPhase: ConversationPhase.idle,
    );

TurnInProgress _turnInProgress({
  List<TimelineItem> timelineItems = const [],
  TurnActivity activity = TurnActivity.thinking,
}) => TurnInProgress(
  timelineItems: timelineItems,
  conversationPhase: ConversationPhase.turnInFlight,
  activity: activity,
);

TranscriptParagraphBlock _para(String text) =>
    TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text);

MessageTimelineItem _msg(String id) => MessageTimelineItem(
  id: id,
  role: Role.user,
  timestamp: DateTime.utc(2025),
  responseId: 0,
  blocks: [_para('hi')],
);

MessageTimelineItem _assistant(
  List<TranscriptBlock> blocks, {
  bool running = true,
  String id = 'a',
}) => MessageTimelineItem(
  id: id,
  role: Role.assistant,
  timestamp: DateTime.utc(2025),
  responseId: 0,
  blocks: blocks,
  running: running,
);

List<TimelineItem> _twoMessages() => [_msg('m1'), _msg('m2')];

/// Two user messages, each answered: rewind targets sit at 0 and 2.
List<TimelineItem> _twoExchanges() => [
  _msg('m1'),
  _assistant([_para('a')], running: false, id: 'a1'),
  _msg('m2'),
  _assistant([_para('b')], running: false, id: 'a2'),
];

final _epoch = DateTime.utc(2026);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAgentProvider());
  });

  group('ReadyState.phase', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('is idle while the agent at hand rests', () {
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      expect(state.phase, ChatPhase.idle);
      expect(state.generating, isFalse);
      expect(state.rewinding, isFalse);
    });

    test('offers rewind whenever the history may be swapped', () {
      when(() => useCase.canRewind).thenReturn(true);
      expect(state.canRewind, isTrue);
    });

    test('reflects an agent at hand that is still working', () {
      when(() => useCase.viewedConversationState).thenReturn(
        _turnInProgress(activity: TurnActivity.executingTools),
      );
      expect(state.phase, ChatPhase.executingTool);
      expect(state.generating, isTrue);
      expect(state.isPrimaryTurnActive, isFalse);
    });
  });

  group('ReadyState.ConversationStateChanged', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late SelectionLogic selectionLogic;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      selectionLogic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0]));
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider)
        ..set<SelectionLogic>(selectionLogic);
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
    });

    tearDown(() => selectionLogic.dispose());

    test('an unsolicited in-flight turn rides into TurnActiveState', () {
      final turn = _turnInProgress();
      when(() => useCase.conversationState).thenReturn(turn);

      final t = state.handleInput(ConversationStateChanged(turn));

      expect(t.stateType, TurnActiveState);
    });

    test('an idle change stays in ReadyState', () {
      final idle = _idleState();
      when(() => useCase.conversationState).thenReturn(idle);

      final t = state.handleInput(ConversationStateChanged(idle));

      expect(t.stateType, ReadyState);
    });
  });

  group('ReadyState.ProviderStatusChanged', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('a ready provider keeps the chat ready', () {
      final t = state.handleInput(ProviderStatusChanged(_ready()));
      expect(t.stateType, ReadyState);
    });

    test('a reconnecting provider moves to ReconnectingState', () {
      final t = state.handleInput(const ProviderStatusChanged(_connecting));
      expect(t.stateType, ReconnectingState);
    });

    test('Cancel stops background jobs instead of a turn', () {
      final tools = _MockToolsUseCase();
      when(tools.stopJobs).thenReturn(null);
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider)
        ..set<ToolsUseCase>(tools);

      final t = state.handleInput(const Cancel());

      expect(t.stateType, ReadyState);
      verify(tools.stopJobs).called(1);
    });
  });

  group('rewind entry', () {
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late _MockToolsUseCase tools;
    late _MockSandboxUseCase sandbox;
    late ChatData data;
    late SelectionLogic selectionLogic;
    late SubagentZoneLogic zoneLogic;
    late FakeContext ctx;

    FakeContext contextFor(ChatState state) => state.createFakeContext()
      ..set<ChatData>(data)
      ..set<ChatUseCase>(useCase)
      ..set<ProviderUseCase>(provider)
      ..set<ToolsUseCase>(tools)
      ..set<SelectionLogic>(selectionLogic)
      ..set<SubagentZoneLogic>(zoneLogic);

    setUp(() {
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      tools = _MockToolsUseCase();
      sandbox = _MockSandboxUseCase();
      when(() => sandbox.readiness).thenReturn(const SandboxReady());
      when(
        () => sandbox.readinessStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => sandbox.pendingWriteAccess).thenReturn(null);
      when(
        () => sandbox.pendingWriteAccessStream,
      ).thenAnswer((_) => const Stream.empty());
      data = ChatData();
      selectionLogic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0, 0, 0]));
      zoneLogic = SubagentZoneLogic()..start();
      when(
        () => useCase.viewedConversationState,
      ).thenReturn(_idleState(timelineItems: _twoExchanges()));
      when(() => useCase.viewingSubagent).thenReturn(false);
      when(() => useCase.canRewind).thenReturn(true);
      when(tools.stopJobs).thenReturn(null);
    });

    tearDown(() {
      selectionLogic.dispose();
      zoneLogic.dispose();
    });

    group('ReadyState.EscapePressed', () {
      late ReadyState state;

      setUp(() {
        state = ReadyState();
        ctx = contextFor(state);
      });

      Transition press(Duration at) => withClock(
        Clock.fixed(_epoch.add(at)),
        () => state.handleInput(const EscapePressed()),
      );

      test('one Escape arms the chord and stays put', () {
        final t = press(Duration.zero);

        expect(t.stateType, ReadyState);
        expect(data.escapeArmedAt, _epoch);
        expect(ctx.outputs, isEmpty);
      });

      test('a second Escape inside the window enters rewind', () {
        press(Duration.zero);

        final t = press(rewindChordWindow);

        expect(t.stateType, RewindingState);
        expect(data.escapeArmedAt, isNull);
      });

      test('a second Escape past the window only re-arms', () {
        press(Duration.zero);
        final late = rewindChordWindow + const Duration(milliseconds: 1);

        final t = press(late);

        expect(t.stateType, ReadyState);
        expect(data.escapeArmedAt, _epoch.add(late));
      });

      test('stops background jobs on the way', () {
        data.activeJobs = 2;

        press(Duration.zero);

        verify(tools.stopJobs).called(1);
      });

      test('leaves the tools alone without jobs', () {
        press(Duration.zero);

        verifyNever(tools.stopJobs);
      });
    });

    group('ReadyState.EnterRewind', () {
      late ReadyState state;

      setUp(() {
        state = ReadyState();
        ctx = contextFor(state);
        selectionLogic.input(const SelectItem(1));
      });

      test('lands on the latest user message and stashes the cursor', () {
        final t = state.handleInput(const EnterRewind());

        expect(t.stateType, RewindingState);
        expect(selectionLogic.value.position.itemIndex, 2);
        expect(
          data.cursorBeforeRewind,
          const SelectionPosition(itemIndex: 1, subIndex: 0),
        );
        expect(
          ctx.outputs.whereType<CursorMoved>().single.position.itemIndex,
          2,
        );
        expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      });

      test('leaves the subagent zone first', () {
        zoneLogic
          ..input(
            const ZoneRosterChanged([
              SubagentSummary(
                id: 'sub',
                title: 'Sub',
                status: SubagentStatus.running,
              ),
            ]),
          )
          ..input(const EnterZone());
        expect(zoneLogic.value.active, isTrue);

        state.handleInput(const EnterRewind());

        expect(zoneLogic.value.active, isFalse);
      });

      test('is refused while a subagent is viewed', () {
        when(() => useCase.viewingSubagent).thenReturn(true);

        final t = state.handleInput(const EnterRewind());

        expect(t.stateType, ReadyState);
        expect(ctx.outputs, isEmpty);
      });

      test('is refused while the history cannot be swapped', () {
        when(() => useCase.canRewind).thenReturn(false);

        final t = state.handleInput(const EnterRewind());

        expect(t.stateType, ReadyState);
        expect(ctx.outputs, isEmpty);
      });

      test('is refused with no user message to rewind to', () {
        when(() => useCase.viewedConversationState).thenReturn(
          _idleState(
            timelineItems: [
              _assistant([_para('a')]),
            ],
          ),
        );

        final t = state.handleInput(const EnterRewind());

        expect(t.stateType, ReadyState);
        expect(ctx.outputs, isEmpty);
      });
    });

    test('FailedState enters rewind too', () {
      final state = FailedState();
      ctx = contextFor(state);

      final t = state.handleInput(const EnterRewind());

      expect(t.stateType, RewindingState);
    });

    group('RewindingState', () {
      late RewindingState state;

      setUp(() {
        state = RewindingState();
        ctx = contextFor(state);
        selectionLogic.input(const SelectItem(2));
        when(() => useCase.rewindTo(any())).thenReturn(
          const Rewound(message: 'again'),
        );
      });

      test('reads as rewinding', () {
        expect(state.rewinding, isTrue);
        expect(state.phase, ChatPhase.rewinding);
      });

      test('RewindMoveUp hops over the answer to the previous message', () {
        final t = state.handleInput(const RewindMoveUp());

        expect(t.stateType, RewindingState);
        expect(selectionLogic.value.position.itemIndex, 0);
        expect(
          ctx.outputs.whereType<CursorMoved>().single.position.itemIndex,
          0,
        );
      });

      test('RewindMoveUp on the first message stays put', () {
        selectionLogic.input(const SelectItem(0));

        state.handleInput(const RewindMoveUp());

        expect(selectionLogic.value.position.itemIndex, 0);
        expect(ctx.outputs, isEmpty);
      });

      test('RewindMoveDown hops over the answer to the next message', () {
        selectionLogic.input(const SelectItem(0));

        state.handleInput(const RewindMoveDown());

        expect(selectionLogic.value.position.itemIndex, 2);
      });

      test('RewindMoveDown on the last message stays put', () {
        state.handleInput(const RewindMoveDown());

        expect(selectionLogic.value.position.itemIndex, 2);
        expect(ctx.outputs, isEmpty);
      });

      test('ConfirmRewind cuts back to the message under the cursor', () {
        final t = state.handleInput(const ConfirmRewind());

        expect(t.stateType, RewindingState);
        verify(() => useCase.rewindTo('m2')).called(1);
      });

      test('ConfirmRewind ignores a cursor off the user messages', () {
        selectionLogic.input(const SelectItem(1));

        state.handleInput(const ConfirmRewind());

        verifyNever(() => useCase.rewindTo(any()));
      });

      test('a click cuts back to the clicked message', () {
        state.handleInput(const SelectTimelineItem(0));

        verify(() => useCase.rewindTo('m1')).called(1);
      });

      test('a click on any other row does nothing', () {
        state.handleInput(const SelectTimelineItem(3));

        verifyNever(() => useCase.rewindTo(any()));
        expect(ctx.outputs, isEmpty);
      });

      test('the replaced conversation carries it back to ReadyState', () {
        final t = state.handleInput(
          const ConversationReplaced(RewoundToMessage(message: 'again')),
        );

        expect(t.stateType, ReadyState);
        expect(
          ctx.outputs.whereType<ConversationSwitched>().single.replacement,
          isA<RewoundToMessage>().having((r) => r.message, 'message', 'again'),
        );
      });

      test('CancelRewind puts the cursor back and returns to ReadyState', () {
        data.cursorBeforeRewind = const SelectionPosition(
          itemIndex: 1,
          subIndex: 0,
        );

        final t = state.handleInput(const CancelRewind());

        expect(t.stateType, ReadyState);
        expect(selectionLogic.value.position.itemIndex, 1);
        expect(
          ctx.outputs.whereType<CursorMoved>().single.position.itemIndex,
          1,
        );
      });

      test('CancelRewind without a stashed cursor leaves it be', () {
        final t = state.handleInput(const CancelRewind());

        expect(t.stateType, ReadyState);
        expect(selectionLogic.value.position.itemIndex, 2);
      });

      test('an unsolicited in-flight turn rides into TurnActiveState', () {
        final turn = _turnInProgress();
        when(() => useCase.conversationState).thenReturn(turn);

        final t = state.handleInput(ConversationStateChanged(turn));

        expect(t.stateType, TurnActiveState);
      });

      test('an idle change keeps rewinding', () {
        final idle = _idleState();
        when(() => useCase.conversationState).thenReturn(idle);

        final t = state.handleInput(ConversationStateChanged(idle));

        expect(t.stateType, RewindingState);
      });

      test('a ready provider keeps rewinding', () {
        final t = state.handleInput(ProviderStatusChanged(_ready()));

        expect(t.stateType, RewindingState);
      });

      test('a reconnecting provider routes away', () {
        final t = state.handleInput(const ProviderStatusChanged(_connecting));

        expect(t.stateType, ReconnectingState);
      });
    });
  });

  group('UninitializedState.Start', () {
    late UninitializedState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = UninitializedState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
      when(() => useCase.addSystemMessage(any())).thenReturn(null);
    });

    test('routes a ready provider to InitializingState', () {
      when(() => provider.status).thenReturn(_ready());
      expect(state.handleInput(const Start()).stateType, InitializingState);
    });

    test('tells the user to configure a missing provider', () {
      when(() => provider.status).thenReturn(_unconfigured);

      expect(state.handleInput(const Start()).stateType, FailedState);
      verify(
        () => useCase.addSystemMessage(ChatStrings.providerUnconfigured),
      ).called(1);
    });

    test('a later status change routes the same way', () {
      final t = state.handleInput(const ProviderStatusChanged(_failed));

      expect(t.stateType, FailedState);
      verify(() => useCase.addSystemMessage('boom')).called(1);
    });
  });

  group('InitializingState.ProviderStatusChanged', () {
    late InitializingState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late ChatData data;
    late FakeContext ctx;

    setUp(() {
      state = InitializingState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      data = ChatData();
      ctx = state.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
      when(() => useCase.addSystemMessage(any())).thenReturn(null);
      when(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      ).thenReturn(null);
    });

    test('ready status attaches the primary with its context window', () {
      final primary = _MockAgentProvider();
      final ready = _ready(handle: primary);

      final t = state.handleInput(ProviderStatusChanged(ready));

      expect(t.stateType, ReadyState);
      verify(
        () => useCase.attachSession(primary: primary, primaryContextSize: 1024),
      ).called(1);
    });

    test('connecting adds no notice of its own', () {
      state.handleInput(ProviderStatusChanged(_ready()));

      verifyNever(() => useCase.addSystemMessage(any()));
    });

    test('a fresh primary resets the reasoning mode to its default', () {
      data.reasoningMode = 'high';

      state.handleInput(ProviderStatusChanged(_ready(reasoning: _efforts)));

      expect(data.reasoningMode, reasoningAuto);
    });

    test('the same primary keeps the chosen reasoning mode', () {
      final primary = _MockAgentProvider();
      data
        ..lastPrimaryHandle = primary
        ..reasoningMode = 'high';

      state.handleInput(
        ProviderStatusChanged(_ready(reasoning: _efforts, handle: primary)),
      );

      expect(data.reasoningMode, 'high');
    });

    test('a connecting provider refreshes and holds', () {
      final t = state.handleInput(const ProviderStatusChanged(_connecting));

      expect(t.stateType, InitializingState);
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      verifyNever(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      );
    });

    test('an unconfigured provider fails with the setup notice', () {
      final t = state.handleInput(const ProviderStatusChanged(_unconfigured));

      expect(t.stateType, FailedState);
      verify(
        () => useCase.addSystemMessage(ChatStrings.providerUnconfigured),
      ).called(1);
    });

    test('a failed provider fails with its message', () {
      final t = state.handleInput(const ProviderStatusChanged(_failed));

      expect(t.stateType, FailedState);
      verify(() => useCase.addSystemMessage('boom')).called(1);
    });
  });

  group('ReconnectingState', () {
    late ReconnectingState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = ReconnectingState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('presents as reloading', () {
      expect(state.loading, isTrue);
      expect(state.phase, ChatPhase.reloading);
    });

    test('holds while the provider is still connecting', () {
      final t = state.handleInput(const ProviderStatusChanged(_connecting));
      expect(t.stateType, ReconnectingState);
    });

    test('routes once the provider settles', () {
      final t = state.handleInput(ProviderStatusChanged(_ready()));
      expect(t.stateType, InitializingState);
    });
  });

  group('TurnActiveState.phase', () {
    late TurnActiveState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = TurnActiveState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('returns idle when no turn is in progress', () {
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      expect(state.phase, ChatPhase.idle);
    });

    for (final (activity, phase) in const [
      (TurnActivity.thinking, ChatPhase.reasoning),
      (TurnActivity.responding, ChatPhase.responding),
      (TurnActivity.draftingToolCall, ChatPhase.draftingTool),
      (TurnActivity.executingTools, ChatPhase.executingTool),
      (TurnActivity.compacting, ChatPhase.compacting),
    ]) {
      test('presents ${activity.name} as ${phase.name}', () {
        when(
          () => useCase.viewedConversationState,
        ).thenReturn(_turnInProgress(activity: activity));
        expect(state.phase, phase);
      });
    }
  });

  group('TurnActiveState.ConversationStateChanged', () {
    late TurnActiveState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late SelectionLogic selectionLogic;
    late FakeContext ctx;

    setUp(() {
      state = TurnActiveState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      selectionLogic = SelectionLogic()
        ..start()
        ..input(const TimelineShapeChanged([0, 0]));
      ctx = state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider)
        ..set<SelectionLogic>(selectionLogic);
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      when(() => useCase.cancel()).thenReturn(null);
    });

    tearDown(() => selectionLogic.dispose());

    test('rides an in-flight turn', () {
      when(() => useCase.conversationState).thenReturn(_turnInProgress());

      final t = state.handleInput(ConversationStateChanged(_turnInProgress()));

      expect(t.stateType, TurnActiveState);
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      expect(state.isPrimaryTurnActive, isTrue);
    });

    test('ignores an idle that landed before the turn was seen', () {
      when(() => useCase.conversationState).thenReturn(_idleState());

      final t = state.handleInput(ConversationStateChanged(_idleState()));

      expect(t.stateType, TurnActiveState);
    });

    test('settles into ReadyState once the seen turn finishes', () {
      when(() => useCase.conversationState).thenReturn(_turnInProgress());
      state.handleInput(ConversationStateChanged(_turnInProgress()));
      when(() => useCase.conversationState).thenReturn(_idleState());

      final t = state.handleInput(ConversationStateChanged(_idleState()));

      expect(t.stateType, ReadyState);
    });

    test('a failed turn logs the failure and fails', () {
      const failed = ConversationIdle(
        timelineItems: [],
        conversationPhase: ConversationPhase.idle,
        failure: TurnFailure(
          reason: AgentRunFailureReason.loopFailed,
          message: 'nope',
        ),
      );
      when(() => useCase.conversationState).thenReturn(failed);

      final t = state.handleInput(const ConversationStateChanged(failed));

      expect(t.stateType, FailedState);
      expect(
        ctx.outputs.whereType<TurnErrorLog>().single.error,
        'loopFailed: nope',
      );
    });

    test('Cancel and Dispose both cancel the turn', () {
      state
        ..handleInput(const Cancel())
        ..handleInput(const Dispose());

      verify(() => useCase.cancel()).called(2);
    });
  });

  group('TurnActiveState.ProviderStatusChanged', () {
    late TurnActiveState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;

    setUp(() {
      state = TurnActiveState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      when(() => useCase.cancel()).thenReturn(null);
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('ready status keeps the turn active', () {
      final t = state.handleInput(ProviderStatusChanged(_ready()));
      expect(t.stateType, TurnActiveState);
      verifyNever(() => useCase.cancel());
    });

    test('a reconnecting provider abandons the turn', () {
      final t = state.handleInput(const ProviderStatusChanged(_connecting));

      expect(t.stateType, ReconnectingState);
      verify(() => useCase.cancel()).called(1);
    });

    test('failed status abandons the turn and transitions to FailedState', () {
      when(() => useCase.addSystemMessage(any())).thenReturn(null);

      final t = state.handleInput(const ProviderStatusChanged(_failed));

      expect(t.stateType, FailedState);
      verify(() => useCase.cancel()).called(1);
      verify(() => useCase.addSystemMessage('boom')).called(1);
    });
  });

  group('FailedState transitions', () {
    late FailedState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late FakeContext ctx;

    setUp(() {
      state = FailedState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      ctx = state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('ProviderStatusChanged(ready) routes to InitializingState', () {
      final t = state.handleInput(ProviderStatusChanged(_ready()));
      expect(t.stateType, InitializingState);
    });

    test('a replaced conversation lands in ReadyState', () {
      ctx.set<SelectionLogic>(SelectionLogic()..start());

      final t = state.handleInput(const ConversationReplaced(StartedFresh()));

      expect(t.stateType, ReadyState);
      expect(
        ctx.outputs.whereType<ConversationSwitched>().single.replacement,
        isA<StartedFresh>(),
      );
    });

    test('ProviderStatusChanged(connecting) routes to ReconnectingState', () {
      final t = state.handleInput(const ProviderStatusChanged(_connecting));
      expect(t.stateType, ReconnectingState);
    });

    test('ProviderStatusChanged(failed) stays and emits StateUpdated', () {
      final t = state.handleInput(const ProviderStatusChanged(_failed));
      expect(t.stateType, FailedState);
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
    });

    test('ProviderStatusChanged(unconfigured) stays without re-noticing', () {
      final t = state.handleInput(const ProviderStatusChanged(_unconfigured));
      expect(t.stateType, FailedState);
      verifyNever(() => useCase.addSystemMessage(any()));
    });

    test('Submit with a ready provider re-fires input into ReadyState', () {
      when(() => provider.status).thenReturn(_ready());
      const submit = Submit('hi');
      final t = state.handleInput(submit);
      expect(t.stateType, ReadyState);
      expect(ctx.inputs, contains(submit));
    });

    test('Submit with a non-ready provider stays in FailedState', () {
      when(() => provider.status).thenReturn(_failed);
      final t = state.handleInput(const Submit('hi'));
      expect(t.stateType, FailedState);
      expect(ctx.inputs.whereType<Submit>(), isEmpty);
    });

    test('Empty Submit stays in FailedState', () {
      final t = state.handleInput(const Submit(''));
      expect(t.stateType, FailedState);
    });

    test('reports the turn failure when there is one', () {
      const failure = TurnFailure(
        reason: AgentRunFailureReason.loopFailed,
        message: 'the model choked',
      );
      when(() => useCase.failure).thenReturn(failure);
      expect(state.error, 'loopFailed: the model choked');
      expect(state.failure, failure);
    });

    test('falls back to an unknown error', () {
      when(() => useCase.failure).thenReturn(null);
      expect(state.error, 'Unknown error');
    });
  });

  group('sandbox gate', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockSandboxUseCase sandbox;
    late ChatData data;
    late FakeContext ctx;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      sandbox = _MockSandboxUseCase();
      data = ChatData();
      ctx = state.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<SandboxUseCase>(sandbox);
      when(() => useCase.viewingSubagent).thenReturn(false);
      when(() => sandbox.initialize()).thenAnswer((_) async {});
      when(
        () => sandbox.answerWriteAccess(any(), allow: any(named: 'allow')),
      ).thenReturn(null);
    });

    test('composes once the sandbox is ready', () {
      expect(state.composer, isA<Composing>());
    });

    test('gates the composer while the sandbox is not ready', () {
      for (final readiness in const [
        SandboxAwaitingInitialization(),
        SandboxPreparingHost(),
        SandboxProvisioning(),
        SandboxInitializationFailed('no'),
      ]) {
        data.sandboxReadiness = readiness;
        expect(
          state.composer,
          isA<SandboxGate>().having((g) => g.readiness, 'readiness', readiness),
        );
      }
    });

    test('offers Enter at the gate only when there is something to do', () {
      data.sandboxReadiness = const SandboxAwaitingInitialization();
      expect((state.composer as SandboxGate).acceptsEnter, isTrue);
      data.sandboxReadiness = const SandboxInitializationFailed('no');
      expect((state.composer as SandboxGate).acceptsEnter, isTrue);
      data.sandboxReadiness = const SandboxPreparingHost();
      expect((state.composer as SandboxGate).acceptsEnter, isFalse);
      data.sandboxReadiness = const SandboxProvisioning();
      expect((state.composer as SandboxGate).acceptsEnter, isFalse);
    });

    test('a read-only agent leaves the composer empty, gate or not', () {
      when(() => useCase.viewingSubagent).thenReturn(true);
      data.sandboxReadiness = const SandboxAwaitingInitialization();

      expect(state.composer, isA<ReadOnlyComposer>());
    });

    test('rewinding takes the composer over everything else', () {
      final rewinding = RewindingState();
      rewinding.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<SandboxUseCase>(sandbox);
      data.sandboxReadiness = const SandboxAwaitingInitialization();

      expect(rewinding.composer, isA<RewindingComposer>());
    });

    test('a readiness change is kept and shown', () {
      state.handleInput(
        const SandboxReadinessChanged(SandboxAwaitingInitialization()),
      );

      expect(state.sandboxReadiness, isA<SandboxAwaitingInitialization>());
      expect(ctx.outputs.whereType<StateUpdated>(), hasLength(1));
    });

    test('answering the gate asks the sandbox to initialize', () {
      state.handleInput(const InitializeSandbox());

      verify(() => sandbox.initialize()).called(1);
      expect(ctx.outputs, isEmpty);
    });

    test('an ask for write access takes the composer over the gate', () {
      data
        ..sandboxReadiness = const SandboxProvisioning()
        ..pendingWriteAccess = _writeAsk;

      expect(
        state.composer,
        isA<WriteAccessPrompt>().having(
          (prompt) => prompt.request,
          'request',
          _writeAsk,
        ),
      );
    });

    test('an ask for write access is put even while viewing a subagent', () {
      when(() => useCase.viewingSubagent).thenReturn(true);
      data.pendingWriteAccess = _writeAsk;

      expect(state.composer, isA<WriteAccessPrompt>());
    });

    test('rewinding takes the composer over an ask for write access', () {
      final rewinding = RewindingState();
      rewinding.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<SandboxUseCase>(sandbox);
      data.pendingWriteAccess = _writeAsk;

      expect(rewinding.composer, isA<RewindingComposer>());
    });

    test('a change in the ask is kept and shown', () {
      state.handleInput(const WriteAccessRequestChanged(_writeAsk));
      expect(state.pendingWriteAccess, _writeAsk);
      expect(ctx.outputs.whereType<StateUpdated>(), hasLength(1));

      state.handleInput(const WriteAccessRequestChanged(null));
      expect(state.pendingWriteAccess, isNull);
      expect(state.composer, isA<Composing>());
    });

    test('answering the ask passes the answer to the sandbox', () {
      data.pendingWriteAccess = _writeAsk;

      state.handleInput(const AnswerWriteAccess(allow: true));
      verify(
        () => sandbox.answerWriteAccess(_writeAsk.id, allow: true),
      ).called(1);

      state.handleInput(const AnswerWriteAccess(allow: false));
      verify(
        () => sandbox.answerWriteAccess(_writeAsk.id, allow: false),
      ).called(1);
      expect(ctx.outputs, isEmpty);
    });

    test('an answer with no ask in front of the user goes nowhere', () {
      state.handleInput(const AnswerWriteAccess(allow: true));

      verifyNever(
        () => sandbox.answerWriteAccess(any(), allow: any(named: 'allow')),
      );
    });

    test('focus opens on deny and a new ask puts it back there', () {
      expect(state.writeAccessChoice, WriteAccessChoice.deny);

      state.handleInput(const ToggleWriteAccessChoice());
      expect(state.writeAccessChoice, WriteAccessChoice.allow);
      expect(ctx.outputs.whereType<StateUpdated>(), hasLength(1));

      state.handleInput(const ToggleWriteAccessChoice());
      expect(state.writeAccessChoice, WriteAccessChoice.deny);

      state
        ..handleInput(const ToggleWriteAccessChoice())
        ..handleInput(const WriteAccessRequestChanged(_writeAsk));
      expect(state.writeAccessChoice, WriteAccessChoice.deny);
    });

    test('confirming answers with whichever the focus rests on', () {
      data.pendingWriteAccess = _writeAsk;

      state.handleInput(const ConfirmWriteAccess());
      verify(
        () => sandbox.answerWriteAccess(_writeAsk.id, allow: false),
      ).called(1);

      state
        ..handleInput(const ToggleWriteAccessChoice())
        ..handleInput(const ConfirmWriteAccess());
      verify(
        () => sandbox.answerWriteAccess(_writeAsk.id, allow: true),
      ).called(1);
    });

    test('confirming with no ask in front of the user goes nowhere', () {
      state.handleInput(const ConfirmWriteAccess());

      verifyNever(
        () => sandbox.answerWriteAccess(any(), allow: any(named: 'allow')),
      );
    });
  });

  group('CycleReasoning', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late ChatData data;
    late FakeContext ctx;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      data = ChatData();
      ctx = state.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider);
    });

    test('cycles through the modes the model offers', () {
      when(() => provider.status).thenReturn(_ready(reasoning: _efforts));

      expect(state.reasoningModes, ['auto', 'off', 'low', 'medium', 'high']);
      expect(state.defaultEffortLabel, 'medium');
      expect(state.canCycleReasoning, isTrue);
      expect(state.isReasoningActive, isFalse);

      state.handleInput(const CycleReasoning());
      expect(state.reasoningMode, reasoningOff);
      expect(state.isReasoningActive, isFalse);

      state.handleInput(const CycleReasoning());
      expect(state.reasoningMode, 'low');
      expect(state.isReasoningActive, isTrue);

      state
        ..handleInput(const CycleReasoning())
        ..handleInput(const CycleReasoning())
        ..handleInput(const CycleReasoning());
      expect(state.reasoningMode, reasoningAuto);
      expect(ctx.outputs.whereType<StateUpdated>().length, 5);
    });

    test('skips off when the model must think', () {
      when(() => provider.status).thenReturn(
        _ready(
          reasoning: const ProviderReasoningEfforts(
            efforts: ['low', 'high'],
            canDisable: false,
          ),
        ),
      );

      expect(state.reasoningModes, ['auto', 'low', 'high']);
      expect(state.defaultEffortLabel, isNull);
    });

    test('is a no-op when the model cannot reason', () {
      when(() => provider.status).thenReturn(_ready());

      expect(state.canCycleReasoning, isFalse);
      state.handleInput(const CycleReasoning());

      expect(state.reasoningMode, reasoningAuto);
      expect(ctx.outputs, isEmpty);
    });

    test('offers only auto while the provider is down', () {
      when(() => provider.status).thenReturn(_unconfigured);
      expect(state.reasoningModes, [reasoningAuto]);
      expect(state.defaultEffortLabel, isNull);
      expect(state.canCycleReasoning, isFalse);
    });
  });

  group('Subagent zone inputs', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late SubagentZoneLogic zoneLogic;
    late SelectionLogic selectionLogic;

    const roster = [
      SubagentSummary(
        id: 'subagent:a',
        title: 'a',
        status: SubagentStatus.running,
      ),
    ];

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      zoneLogic = SubagentZoneLogic()
        ..start()
        ..input(const ZoneRosterChanged(roster));
      selectionLogic = SelectionLogic()..start();
      state.createFakeContext()
        ..set<ChatData>(ChatData())
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(_MockProviderUseCase())
        ..set<SelectionLogic>(selectionLogic)
        ..set<SubagentZoneLogic>(zoneLogic);
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      when(() => useCase.viewSession(any())).thenReturn(null);
      when(() => useCase.stopSubagent(any())).thenReturn(null);
    });

    tearDown(() {
      zoneLogic.dispose();
      selectionLogic.dispose();
    });

    test('EnterSubagentZone lands on the Primary row', () {
      state.handleInput(const EnterSubagentZone());

      expect(state.zoneActive, isTrue);
      expect(state.highlightedSubagentIndex, 0);
      expect(state.zoneHighlightsSubagent, isFalse);
      verify(() => useCase.viewSession(primaryAgentSessionId)).called(1);
    });

    test('MoveSubagentDown previews the first subagent', () {
      state
        ..handleInput(const EnterSubagentZone())
        ..handleInput(const MoveSubagentDown());

      expect(state.highlightedSubagentIndex, 1);
      expect(state.zoneHighlightsSubagent, isTrue);
      verify(() => useCase.viewSession('subagent:a')).called(1);
    });

    test('StopHighlightedSubagent on the Primary row stops nothing', () {
      state
        ..handleInput(const EnterSubagentZone())
        ..handleInput(const StopHighlightedSubagent());

      verifyNever(() => useCase.stopSubagent(any()));
    });

    test('StopHighlightedSubagent stops the highlighted subagent', () {
      state
        ..handleInput(const EnterSubagentZone())
        ..handleInput(const MoveSubagentDown())
        ..handleInput(const StopHighlightedSubagent());

      verify(() => useCase.stopSubagent('subagent:a')).called(1);
    });
  });

  group('Selection inputs delegate to SelectionLogic', () {
    late ReadyState state;
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late ChatData data;
    late SelectionLogic selectionLogic;
    late FakeContext ctx;

    setUp(() {
      state = ReadyState();
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      data = ChatData();
      selectionLogic = SelectionLogic()
        ..start()
        // Observed, position at the tail (1, 0).
        ..input(const TimelineShapeChanged([0, 0]));
      ctx = state.createFakeContext()
        ..set<ChatData>(data)
        ..set<ChatUseCase>(useCase)
        ..set<ProviderUseCase>(provider)
        ..set<SelectionLogic>(selectionLogic);
      when(
        () => useCase.conversationState,
      ).thenReturn(_idleState(timelineItems: _twoMessages()));
      when(
        () => useCase.viewedConversationState,
      ).thenReturn(_idleState(timelineItems: _twoMessages()));
    });

    tearDown(() {
      selectionLogic.dispose();
    });

    test('MoveSelectionUp moves the selection up', () {
      state.handleInput(const MoveSelectionUp());
      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      // Scrolling rides on the bound PositionChanged, not the handler.
      expect(ctx.outputs.whereType<CursorMoved>(), isEmpty);
    });

    // Pressing past the last slot must not scroll a tall tail message back
    // to its top.
    test('MoveSelectionDown at the tail leaves the viewport alone', () {
      state.handleInput(const MoveSelectionDown());
      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
      expect(ctx.outputs.whereType<CursorMoved>(), isEmpty);
    });

    test('MoveSelectionDown moves the selection down', () {
      selectionLogic.input(const MoveUp()); // → (0, 0)
      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );

      state.handleInput(const MoveSelectionDown());

      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 1, subIndex: 0)),
      );
    });

    test('SelectTimelineItem jumps to the item', () {
      state.handleInput(const SelectTimelineItem(0));

      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
    });

    test('SelectTimelineItem does not scroll (emits no CursorMoved)', () {
      // A click lands on an already-visible item and may start a text drag,
      // so it must not fire the keep-cursor-visible scroll signal.
      state.handleInput(const SelectTimelineItem(0));
      expect(ctx.outputs.whereType<CursorMoved>(), isEmpty);
    });

    test('RevealTimelineItem jumps to the item and scrolls to it', () {
      state.handleInput(const RevealTimelineItem(0));

      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      expect(ctx.outputs.whereType<CursorMoved>(), isNotEmpty);
    });

    test('SelectVisibleItem follows the viewport quietly', () {
      state.handleInput(const SelectVisibleItem(0));

      expect(
        selectionLogic.value.position,
        equals(const SelectionPosition(itemIndex: 0, subIndex: 0)),
      );
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
      expect(ctx.outputs.whereType<CursorMoved>(), isEmpty);
      expect(ctx.outputs.whereType<ItemSelected>(), isEmpty);
    });

    test('Clear asks the use case and waits for the replacement', () {
      when(useCase.clear).thenReturn(null);
      selectionLogic.input(const MoveUp());

      final t = state.handleInput(const Clear());

      expect(t.stateType, ReadyState);
      verify(useCase.clear).called(1);
      expect(ctx.outputs.whereType<ConversationSwitched>(), isEmpty);
      expect(selectionLogic.value, isA<Observed>());
    });

    test('ConversationReplaced resets the selection and announces why', () {
      selectionLogic.input(const MoveUp());

      final t = state.handleInput(
        const ConversationReplaced(LoadedFromDisk()),
      );

      expect(t.stateType, ReadyState);
      expect(selectionLogic.value, isA<Unobserved>());
      final switched = ctx.outputs.whereType<ConversationSwitched>().single;
      expect(switched.replacement, isA<LoadedFromDisk>());
      expect(ctx.outputs.whereType<StateUpdated>(), isNotEmpty);
    });

    group('ItemSelected marks deliberate selection only', () {
      test('MoveSelectionUp announces it', () {
        state.handleInput(const MoveSelectionUp());
        expect(ctx.outputs.whereType<ItemSelected>(), isNotEmpty);
      });

      test('MoveSelectionDown announces it', () {
        state.handleInput(const MoveSelectionDown());
        expect(ctx.outputs.whereType<ItemSelected>(), isNotEmpty);
      });

      test('SelectTimelineItem announces it', () {
        state.handleInput(const SelectTimelineItem(0));
        expect(ctx.outputs.whereType<ItemSelected>(), isNotEmpty);
      });

      test('RevealTimelineItem announces it', () {
        state.handleInput(const RevealTimelineItem(0));
        expect(ctx.outputs.whereType<ItemSelected>(), isNotEmpty);
      });

      // The cursor riding the tail onto an item the agent just appended is
      // not the user asking to read anything. Announcing it would pull the
      // details pane forward once per streamed item.
      test('a cursor riding the tail does not', () {
        state.handleInput(
          const SelectionPositionChanged(
            SelectionPosition(itemIndex: 1, subIndex: 0),
          ),
        );
        expect(ctx.outputs.whereType<CursorMoved>(), isNotEmpty);
        expect(ctx.outputs.whereType<ItemSelected>(), isEmpty);
      });
    });

    group('Submit and the anchored selection', () {
      void stubSubmit() {
        data.reasoningMode = 'low';
        when(() => useCase.canSubmit).thenReturn(true);
        when(() => useCase.clearSettledSubagents()).thenReturn(null);
        when(
          () => useCase.submit(
            message: any(named: 'message'),
            reasoningMode: any(named: 'reasoningMode'),
          ),
        ).thenAnswer((_) async => true);
      }

      test('snaps a cursor anchored on an earlier message onto the tail', () {
        stubSubmit();
        state.handleInput(const SelectTimelineItem(0)); // read an old message
        when(() => useCase.viewedConversationState).thenReturn(
          _idleState(timelineItems: [_msg('m1'), _msg('m2'), _msg('m3')]),
        );

        final t = state.handleInput(const Submit('hi'));

        expect(t.stateType, TurnActiveState);
        // Re-anchored onto the live tail so it follows the sent message.
        expect(selectionLogic.value.position.itemIndex, 2);
        expect(selectionLogic.value.followsTail, isTrue);
        expect(ctx.outputs.whereType<CursorMoved>(), isNotEmpty);
      });

      test('advances a tail-following cursor onto the sent message', () {
        stubSubmit();
        // No click — the cursor starts on the tail (1, 0), following.
        when(() => useCase.viewedConversationState).thenReturn(
          _idleState(timelineItems: [_msg('m1'), _msg('m2'), _msg('m3')]),
        );

        state.handleInput(const Submit('hi'));

        expect(selectionLogic.value.position.itemIndex, 2);
      });

      test('sends the chosen reasoning mode along', () {
        stubSubmit();
        when(() => useCase.viewedConversationState).thenReturn(
          _idleState(timelineItems: [_msg('m1')]),
        );

        state.handleInput(const Submit('hi'));

        verify(
          () => useCase.submit(message: 'hi', reasoningMode: 'low'),
        ).called(1);
      });

      test('reclaims the zone by clearing settled subagents on send', () {
        stubSubmit();
        when(() => useCase.viewedConversationState).thenReturn(
          _idleState(timelineItems: [_msg('m1')]),
        );

        state.handleInput(const Submit('hi'));

        verify(() => useCase.clearSettledSubagents()).called(1);
      });

      test('a blocked submit stays put', () {
        when(() => useCase.canSubmit).thenReturn(false);

        final t = state.handleInput(const Submit('hi'));

        expect(t.stateType, ReadyState);
      });
    });

    group('derived getters', () {
      test('starts with the newest message selected', () {
        expect(state.effectiveSelectedIndex, 1);
        expect(state.selectedTimelineItem, same(state.timelineItems.last));
      });

      test('moving the cursor drives selection and the details item', () {
        selectionLogic.input(const MoveUp()); // (1, 0) → (0, 0)

        expect(state.effectiveSelectedIndex, 0);
        expect(state.selectedTimelineItem, same(state.timelineItems.first));
      });

      test('selectedTimelineItem is null for an empty timeline', () {
        when(() => useCase.viewedConversationState).thenReturn(_idleState());
        expect(state.selectedTimelineItem, isNull);
      });
    });
  });

  group('ChatLogic', () {
    late _MockChatUseCase useCase;
    late _MockProviderUseCase provider;
    late _MockToolsUseCase tools;
    late _MockSandboxUseCase sandbox;

    setUp(() {
      useCase = _MockChatUseCase();
      provider = _MockProviderUseCase();
      tools = _MockToolsUseCase();
      sandbox = _MockSandboxUseCase();
      when(() => sandbox.readiness).thenReturn(const SandboxReady());
      when(
        () => sandbox.readinessStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => sandbox.pendingWriteAccess).thenReturn(null);
      when(
        () => sandbox.pendingWriteAccessStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => provider.statusStream).thenAnswer((_) => const Stream.empty());
      when(
        () => useCase.conversationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => useCase.subagentSummariesStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => useCase.conversationReplacements,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => useCase.rewindRequests,
      ).thenAnswer((_) => const Stream.empty());
      when(() => useCase.addSystemMessage(any())).thenReturn(null);
      when(() => tools.activeJobCount).thenReturn(0);
      when(() => tools.activeJobs).thenAnswer((_) => const Stream.empty());
    });

    test('seeds the reasoning mode from the connected model', () {
      when(() => provider.status).thenReturn(_ready(reasoning: _efforts));

      final logic = ChatLogic(
        useCase: useCase,
        providerUseCase: provider,
        toolsUseCase: tools,
        sandboxUseCase: sandbox,
      );

      expect(logic.get<ChatData>().reasoningMode, reasoningAuto);
      logic.dispose();
    });

    test('seeds and follows the sandbox readiness', () async {
      final readiness = StreamController<SandboxReadiness>.broadcast();
      addTearDown(readiness.close);
      when(() => provider.status).thenReturn(_unconfigured);
      when(
        () => sandbox.readiness,
      ).thenReturn(const SandboxAwaitingInitialization());
      when(() => sandbox.readinessStream).thenAnswer((_) => readiness.stream);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());
      expect(
        logic.value.sandboxReadiness,
        isA<SandboxAwaitingInitialization>(),
      );

      readiness.add(const SandboxReady());
      await pumpEventQueue();

      expect(logic.value.sandboxReadiness, isA<SandboxReady>());
      logic
        ..stop()
        ..dispose();
    });

    test('seeds and follows the ask for write access', () async {
      final asks = StreamController<WriteAccessRequest?>.broadcast();
      addTearDown(asks.close);
      when(() => provider.status).thenReturn(_unconfigured);
      when(() => sandbox.pendingWriteAccess).thenReturn(_writeAsk);
      when(
        () => sandbox.pendingWriteAccessStream,
      ).thenAnswer((_) => asks.stream);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());
      expect(logic.value.pendingWriteAccess, _writeAsk);

      asks.add(null);
      await pumpEventQueue();

      expect(logic.value.pendingWriteAccess, isNull);
      logic
        ..stop()
        ..dispose();
    });

    test('boots straight into the setup notice without a provider', () {
      when(() => provider.status).thenReturn(_unconfigured);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());

      expect(logic.value, isA<FailedState>());
      verify(
        () => useCase.addSystemMessage(ChatStrings.providerUnconfigured),
      ).called(1);
      logic
        ..stop()
        ..dispose();
    });

    test('follows the provider through a reconnect', () async {
      final statuses = StreamController<ProviderStatus>.broadcast();
      addTearDown(statuses.close);
      ProviderStatus current = _ready();
      when(() => provider.status).thenAnswer((_) => current);
      when(() => provider.statusStream).thenAnswer((_) => statuses.stream);
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      when(() => useCase.conversationState).thenReturn(_idleState());
      when(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      ).thenReturn(null);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());
      addTearDown(
        () => logic
          ..stop()
          ..dispose(),
      );

      expect(logic.value, isA<ReadyState>());

      current = _connecting;
      statuses.add(_connecting);
      await Future<void>.delayed(Duration.zero);
      expect(logic.value, isA<ReconnectingState>());

      current = _ready();
      statuses.add(current);
      await Future<void>.delayed(Duration.zero);
      expect(logic.value, isA<ReadyState>());
      verify(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: 1024,
        ),
      ).called(2);
    });

    test('forwards a replacement from the use case into the machine', () async {
      final replacements = StreamController<ConversationReplacement>();
      addTearDown(replacements.close);
      when(() => provider.status).thenReturn(_ready());
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      when(() => useCase.conversationState).thenReturn(_idleState());
      when(
        () => useCase.conversationReplacements,
      ).thenAnswer((_) => replacements.stream);
      when(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      ).thenReturn(null);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());
      addTearDown(
        () => logic
          ..stop()
          ..dispose(),
      );
      final switched = <ConversationSwitched>[];
      final binding = logic.bind()
        ..onOutput<ConversationSwitched>(switched.add);
      addTearDown(binding.dispose);

      replacements.add(const LoadedFromDisk());
      await Future<void>.delayed(Duration.zero);

      expect(logic.value, isA<ReadyState>());
      expect(switched.single.replacement, isA<LoadedFromDisk>());
    });

    test('a palette request from the use case enters rewind', () async {
      final requests = StreamController<void>();
      addTearDown(requests.close);
      when(() => provider.status).thenReturn(_ready());
      when(
        () => useCase.viewedConversationState,
      ).thenReturn(_idleState(timelineItems: _twoExchanges()));
      when(() => useCase.conversationState).thenReturn(_idleState());
      when(() => useCase.viewingSubagent).thenReturn(false);
      when(() => useCase.canRewind).thenReturn(true);
      when(() => useCase.rewindRequests).thenAnswer((_) => requests.stream);
      when(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      ).thenReturn(null);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start());
      addTearDown(
        () => logic
          ..stop()
          ..dispose(),
      );
      expect(logic.value, isA<ReadyState>());

      requests.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(logic.value, isA<RewindingState>());
      expect(logic.value.effectiveSelectedIndex, 2);
    });

    test('re-routes when the provider settled before reconnecting began', () {
      when(() => provider.status).thenReturn(_ready());
      when(() => useCase.viewedConversationState).thenReturn(_idleState());
      when(
        () => useCase.attachSession(
          primary: any(named: 'primary'),
          primaryContextSize: any(named: 'primaryContextSize'),
        ),
      ).thenReturn(null);

      final logic =
          ChatLogic(
              useCase: useCase,
              providerUseCase: provider,
              toolsUseCase: tools,
              sandboxUseCase: sandbox,
            )
            ..start()
            ..input(const Start())
            ..input(const ProviderStatusChanged(_connecting));
      addTearDown(
        () => logic
          ..stop()
          ..dispose(),
      );

      expect(logic.value, isA<ReadyState>());
    });
  });
}
