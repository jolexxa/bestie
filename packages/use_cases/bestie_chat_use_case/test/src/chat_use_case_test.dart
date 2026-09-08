import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        AgentProvider,
        AgentRunFailureReason,
        ContextPoolSnapshot,
        SamplingOptions;
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockProviderRepository extends Mock implements ProviderRepository {}

class _MockAgentRepository extends Mock implements AgentRepository {}

class _MockAgentSession extends Mock implements AgentSession {}

class _MockAgentProvider extends Mock implements AgentProvider {}

class _FakeAgentProvider extends Fake implements AgentProvider {}

const _idle = ConversationIdle(
  timelineItems: [],
  conversationPhase: ConversationPhase.idle,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAgentProvider());
    registerFallbackValue(const SamplingOptions(seed: 0));
    registerFallbackValue(const TurnOptions.baseline(''));
    registerFallbackValue(
      const AgentConfiguration(
        compactionRatio: defaultCompactionRatio,
        maxToolCallCharacters: defaultMaxToolCallCharacters,
      ),
    );
    registerFallbackValue(
      const ModelSnapshot.remote(
        modelId: 'x',
        displayName: 'x',
        contextSize: 1,
        provider: 'x',
      ),
    );
  });

  group('ChatStrings', () {
    test('formats parameterized strings', () {
      expect(
        ChatStrings.workingDirectoryChanged('/a', '/b'),
        'This conversation started in /a; tools now run in /b.',
      );
      expect(ChatStrings.compactionResult(42), 'Compacted ~42 tokens');
      expect(
        ChatStrings.compactionInProgress(42),
        'Compacting ~42 tokens…',
      );
    });
  });

  group('ChatUseCase', () {
    late _MockProviderRepository providers;
    late _MockAgentRepository agents;
    late _MockAgentSession session;
    late FakeConfigRepository config;
    late ChatConfigKeys configKeys;
    late ChatUseCase useCase;
    late SamplingOptions sampling;
    late StreamController<ConversationState> convController;
    late StreamController<AgentSession> primaryController;
    late StreamController<void> reloadsStartingController;
    late StreamController<ContextPoolSnapshot> poolController;
    late StreamController<List<SubagentSummary>> subagentsController;

    ProviderStatusReady stubReadyPrimary({bool supportsReasoning = false}) {
      final ready = _ready(supportsReasoning: supportsReasoning);
      when(() => providers.status).thenReturn(ready);
      return ready;
    }

    setUp(() {
      providers = _MockProviderRepository();
      agents = _MockAgentRepository();
      session = _MockAgentSession();
      configKeys = _testConfigKeys();
      config = FakeConfigRepository();
      convController = StreamController<ConversationState>.broadcast();
      primaryController = StreamController<AgentSession>.broadcast();
      reloadsStartingController = StreamController<void>.broadcast();
      poolController = StreamController<ContextPoolSnapshot>.broadcast();
      subagentsController = StreamController<List<SubagentSummary>>.broadcast();

      when(() => agents.primary).thenReturn(session);
      when(() => agents.workingDirectory).thenReturn('/work');
      when(() => agents.subagents).thenReturn(const []);
      when(
        () => agents.subagentsStream,
      ).thenAnswer((_) => subagentsController.stream);
      when(
        () => agents.primaryStream,
      ).thenAnswer((_) => primaryController.stream);
      when(() => agents.poolStream).thenAnswer((_) => poolController.stream);
      when(() => agents.statsFor(any())).thenReturn(null);
      when(() => agents.clear()).thenReturn(null);
      when(
        () => agents.bindProvider(
          any(),
          contextSize: any(named: 'contextSize'),
          systemPrompt: any(named: 'systemPrompt'),
        ),
      ).thenAnswer((_) async {});

      when(() => session.stream).thenAnswer((_) => convController.stream);
      when(() => session.state).thenReturn(_idle);
      when(() => session.failure).thenReturn(null);
      when(() => session.conversationPhase).thenReturn(ConversationPhase.idle);
      when(() => session.canRunTurns).thenReturn(true);
      when(() => session.transcript).thenReturn(_transcript());
      when(() => session.addNotice(any())).thenReturn(null);
      when(() => session.recordModelChange(any())).thenReturn(null);
      when(() => session.cancel()).thenReturn(null);
      when(
        () => session.beginTurn(
          message: any(named: 'message'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => providers.reloadsStarting,
      ).thenAnswer((_) => reloadsStartingController.stream);
      when(
        () => providers.statusStream,
      ).thenAnswer((_) => const Stream.empty());
      stubReadyPrimary();
      sampling = const SamplingOptions(seed: 0);

      useCase = ChatUseCase(
        providerRepository: providers,
        agentRepository: agents,
        config: config,
        configKeys: configKeys,
        sampling: () => sampling,
        dynamicSystemPrompt: ' [dyn]',
        homeDirectory: '/home/j',
      );
    });

    tearDown(() async {
      await useCase.dispose();
      await convController.close();
      await primaryController.close();
      await reloadsStartingController.close();
      await poolController.close();
      await subagentsController.close();
      await config.dispose();
    });

    group('agent configuration', () {
      test('hands the repository the configured values on construction', () {
        final pushed =
            verify(
                  () => agents.configuration = captureAny(),
                ).captured.last
                as AgentConfiguration;

        expect(pushed.compactionRatio, defaultCompactionRatio);
        expect(pushed.maxToolCallCharacters, defaultMaxToolCallCharacters);
      });

      test('re-pushes whenever configuration changes', () async {
        config.setAll({
          'memory.compaction_ratio': 0.5,
          'tools.max_call_characters': 900,
        });
        await Future<void>.delayed(Duration.zero);

        final pushed =
            verify(
                  () => agents.configuration = captureAny(),
                ).captured.last
                as AgentConfiguration;

        expect(pushed.compactionRatio, 0.5);
        expect(pushed.maxToolCallCharacters, 900);
      });
    });

    // ── Forwarded getters ───────────────────────────────────

    test('forwards conversation stream', () {
      expect(useCase.conversationStream, isA<Stream<ConversationState>>());
    });

    test('a pool snapshot ticks the conversation stream', () async {
      final ticks = <ConversationState>[];
      final listener = useCase.conversationStream.listen(ticks.add);
      addTearDown(listener.cancel);

      poolController.add(
        const ContextPoolSnapshot(
          contextSize: 10,
          reservedClaims: 0,
          leases: [],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(ticks, [same(_idle)]);
    });

    test('subagent summaries replay the roster before live updates', () async {
      const seeded = SubagentSummary(
        id: 'subagent:a',
        title: 'A',
        status: SubagentStatus.running,
      );
      const later = SubagentSummary(
        id: 'subagent:b',
        title: 'B',
        status: SubagentStatus.completed,
      );
      when(() => agents.subagents).thenReturn([seeded]);
      when(
        () => agents.subagentsStream,
      ).thenAnswer((_) => Stream.value([seeded, later]));

      expect(useCase.subagents, [seeded]);
      expect(
        await useCase.subagentSummariesStream.toList(),
        [
          [seeded],
          [seeded, later],
        ],
      );
    });

    ToolCallInvocation invocation(
      String toolName, {
      Map<String, Object?> arguments = const {},
      int maxOutputChars = defaultMaxToolCallCharacters,
    }) => ToolCallInvocation(
      conversationId: 'conversation-1',
      agentId: primaryAgentSessionId,
      callId: 'c',
      toolName: toolName,
      outputPath: 'outputs/c',
      maxOutputChars: maxOutputChars,
      arguments: arguments,
    );

    Future<String> answer(ToolCallInvocation call) async =>
        switch (await (await useCase.respond(call)).settled) {
          JobSucceeded(:final content) => content,
          JobFailed(:final message) => message,
        };

    test('advertises both subagent tools', () {
      expect(useCase.definitions.definitions.map((d) => d.name), [
        subagentName,
        subagentReadName,
      ]);
    });

    test('spawns with the prompt and title the call carried', () async {
      when(
        () => agents.startSubagent(
          callId: any(named: 'callId'),
          prompt: any(named: 'prompt'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async => Job.done('dispatched'));

      final content = await answer(
        invocation(
          subagentName,
          arguments: {'prompt': ' Investigate ', 'title': ' Research '},
        ),
      );

      expect(content, 'dispatched');
      verify(
        () => agents.startSubagent(
          callId: 'c',
          prompt: 'Investigate',
          label: 'Research',
        ),
      ).called(1);
    });

    test('names an untitled subagent before the repository sees it', () async {
      when(
        () => agents.startSubagent(
          callId: any(named: 'callId'),
          prompt: any(named: 'prompt'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async => Job.done('dispatched'));

      await answer(
        invocation(subagentName, arguments: {'prompt': 'Investigate'}),
      );

      verify(
        () => agents.startSubagent(
          callId: 'c',
          prompt: 'Investigate',
          label: 'Subagent',
        ),
      ).called(1);
    });

    test('refuses an empty prompt without reaching the repository', () async {
      expect(
        await answer(
          invocation(subagentName, arguments: {'prompt': '  '}),
        ),
        contains('non-empty'),
      );
      verifyNever(
        () => agents.startSubagent(
          callId: any(named: 'callId'),
          prompt: any(named: 'prompt'),
          label: any(named: 'label'),
        ),
      );
    });

    test('refuses a read with no id without reaching the repository', () async {
      expect(
        await answer(invocation(subagentReadName, arguments: {'id': ' '})),
        contains('non-empty'),
      );
      verifyNever(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      );
    });

    test('asks for the transcript view only when told to', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer((_) async => const SubagentReadEnd());

      await answer(
        invocation(
          subagentReadName,
          arguments: {'id': 'sub-1', 'include': subagentTranscriptView},
        ),
      );
      await answer(
        invocation(subagentReadName, arguments: {'id': 'sub-1'}),
      );

      final asked = verify(
        () => agents.readSubagent(
          id: 'sub-1',
          wholeTranscript: captureAny(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).captured;
      expect(asked, [true, false]);
    });

    test('leaves the read room for the trailer it appends', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer((_) async => const SubagentReadEnd());

      await answer(
        invocation(
          subagentReadName,
          arguments: {'id': 'sub-1'},
          maxOutputChars: 1000,
        ),
      );

      final asked =
          verify(
                () => agents.readSubagent(
                  id: any(named: 'id'),
                  wholeTranscript: any(named: 'wholeTranscript'),
                  maxChars: captureAny(named: 'maxChars'),
                  after: any(named: 'after'),
                ),
              ).captured.single
              as int;
      expect(asked, lessThan(1000));
    });

    test('trails a partial page with the cursor to resume from', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer(
        (_) async => const SubagentReadPage(
          text: 'part one',
          next: 'cursor-9',
          remaining: 3,
        ),
      );

      expect(
        await answer(
          invocation(subagentReadName, arguments: {'id': 'sub-1'}),
        ),
        'part one\n\n[3 more — subagent_read(id: "sub-1", after: "cursor-9")]',
      );
    });

    test('hands back a whole page bare', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer(
        (_) async =>
            const SubagentReadPage(text: 'all of it', next: null, remaining: 0),
      );

      expect(
        await answer(
          invocation(subagentReadName, arguments: {'id': 'sub-1'}),
        ),
        'all of it',
      );
    });

    test('tells a reader of a busy subagent to wait, not retry', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer((_) async => const SubagentReadBusy());

      final job = await useCase.respond(
        invocation(subagentReadName, arguments: {'id': 'sub-1'}),
      );

      expect(await job.settled, isA<JobSucceeded>());
      expect((job.outcome! as JobSucceeded).content, contains('busy'));
    });

    test('distinguishes the end of a read from an empty one', () async {
      when(
        () => agents.readSubagent(
          id: any(named: 'id'),
          wholeTranscript: any(named: 'wholeTranscript'),
          maxChars: any(named: 'maxChars'),
          after: any(named: 'after'),
        ),
      ).thenAnswer((_) async => const SubagentReadEnd());

      expect(
        await answer(
          invocation(
            subagentReadName,
            arguments: {'id': 'sub-1', 'after': 'cursor-9'},
          ),
        ),
        contains('Fully read'),
      );
      expect(
        await answer(
          invocation(subagentReadName, arguments: {'id': 'sub-1'}),
        ),
        contains('produced nothing'),
      );
    });

    test('explains an unknown subagent, cursor, and oversized block', () async {
      final cases = <SubagentRead, String>{
        const SubagentReadUnknown(): 'No subagent "sub-1"',
        const SubagentReadCursorLost(): 'start over',
        const SubagentReadBlockTooWide(9000): '9000 characters',
      };
      for (final entry in cases.entries) {
        when(
          () => agents.readSubagent(
            id: any(named: 'id'),
            wholeTranscript: any(named: 'wholeTranscript'),
            maxChars: any(named: 'maxChars'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => entry.key);

        expect(
          await answer(
            invocation(subagentReadName, arguments: {'id': 'sub-1'}),
          ),
          contains(entry.value),
        );
      }
    });

    test('forwards conversationState, stats, and failure', () {
      const idle = ConversationIdle(
        timelineItems: [],
        conversationPhase: ConversationPhase.idle,
      );
      const failure = TurnFailure(reason: AgentRunFailureReason.loopFailed);
      when(() => session.state).thenReturn(idle);
      when(() => session.failure).thenReturn(failure);

      expect(useCase.conversationState, idle);
      expect(useCase.stats, isNull);
      expect(useCase.failure, failure);
    });

    // ── Viewed session (primary vs subagent) ────────────────

    ({_MockAgentSession session, StreamController<ConversationState> ctrl})
    stubSubagent(String id, ConversationState state) {
      final subagent = _MockAgentSession();
      final ctrl = StreamController<ConversationState>.broadcast();
      addTearDown(ctrl.close);
      when(() => subagent.stream).thenAnswer((_) => ctrl.stream);
      when(() => subagent.state).thenReturn(state);
      when(() => agents.sessionFor(id)).thenReturn(subagent);
      return (session: subagent, ctrl: ctrl);
    }

    test('defaults to viewing the primary', () {
      expect(useCase.viewedSessionId, primaryAgentSessionId);
      expect(useCase.viewingSubagent, isFalse);
      expect(useCase.viewedConversationState, same(_idle));
    });

    test('viewSession renders the subagent but turn logic stays on '
        'the primary', () {
      const subState = ConversationIdle(
        timelineItems: [],
        conversationPhase: ConversationPhase.idle,
      );
      stubSubagent('subagent:x', subState);

      useCase.viewSession('subagent:x');

      expect(useCase.viewingSubagent, isTrue);
      expect(useCase.viewedConversationState, same(subState));
      // The turn-lifecycle source must NOT follow the view.
      expect(useCase.conversationState, same(_idle));

      useCase.viewPrimary();
      expect(useCase.viewingSubagent, isFalse);
      expect(useCase.viewedConversationState, same(_idle));
    });

    test('a viewed subagent ticks the stream; unviewing detaches it', () async {
      final sub = stubSubagent('subagent:x', _idle);
      final ticks = <ConversationState>[];
      final listener = useCase.conversationStream.listen(ticks.add);

      useCase.viewSession('subagent:x'); // immediate re-emit
      await Future<void>.delayed(Duration.zero);
      final afterView = ticks.length;
      expect(afterView, greaterThan(0));

      sub.ctrl.add(_idle); // subagent update flows through
      await Future<void>.delayed(Duration.zero);
      expect(ticks.length, greaterThan(afterView));

      useCase.viewPrimary(); // detaches the subagent subscription
      await Future<void>.delayed(Duration.zero);
      final afterUnview = ticks.length;

      sub.ctrl.add(_idle); // must no longer tick
      await Future<void>.delayed(Duration.zero);
      expect(ticks.length, afterUnview);

      await listener.cancel();
    });

    test('conversations forwards to the repo', () async {
      when(() => agents.conversations()).thenAnswer((_) async => const []);
      expect(await useCase.conversations(), isEmpty);
      verify(() => agents.conversations()).called(1);
    });

    group('load', () {
      test(
        'swaps in the conversation, re-seeds the card and says so',
        () async {
          when(
            () => agents.load('abc'),
          ).thenAnswer((_) async => const ConversationLoaded());
          when(
            () => session.transcript,
          ).thenReturn(_transcript());
          final replacements = <ConversationReplacement>[];
          final sub = useCase.conversationReplacements.listen(replacements.add);
          addTearDown(sub.cancel);

          expect(await useCase.load('abc'), isA<ConversationLoaded>());

          verifyInOrder([
            () => agents.load('abc'),
            () => session.recordModelChange(any()),
            () => session.addNotice(ChatStrings.conversationLoaded),
          ]);
          verifyNever(() => session.addNotice(any(that: startsWith('This'))));
          await Future<void>.delayed(Duration.zero);
          expect(replacements.single, isA<LoadedFromDisk>());
        },
      );

      test('flags a conversation that started elsewhere', () async {
        when(
          () => agents.load('abc'),
        ).thenAnswer((_) async => const ConversationLoaded());
        when(
          () => session.transcript,
        ).thenReturn(_transcript(workingDirectory: '/elsewhere'));

        await useCase.load('abc');

        verify(
          () => session.addNotice(
            ChatStrings.workingDirectoryChanged('/elsewhere', '/work'),
          ),
        ).called(1);
      });

      test('snaps the view back to the primary first', () async {
        when(
          () => agents.load('abc'),
        ).thenAnswer((_) async => const ConversationLoaded());
        final sub = _MockAgentSession();
        when(() => sub.stream).thenAnswer((_) => const Stream.empty());
        when(() => sub.state).thenReturn(_idle);
        when(() => agents.sessionFor('sub')).thenReturn(sub);
        useCase.viewSession('sub');
        expect(useCase.viewingSubagent, isTrue);

        await useCase.load('abc');

        expect(useCase.viewingSubagent, isFalse);
      });

      test('a missing conversation changes nothing', () async {
        when(
          () => agents.load('abc'),
        ).thenAnswer((_) async => const ConversationNotFound());
        final replacements = <ConversationReplacement>[];
        final sub = useCase.conversationReplacements.listen(replacements.add);
        addTearDown(sub.cancel);

        expect(await useCase.load('abc'), isA<ConversationNotFound>());

        verifyNever(() => session.addNotice(any()));
        verifyNever(() => session.recordModelChange(any()));
        await Future<void>.delayed(Duration.zero);
        expect(replacements, isEmpty);
      });
    });

    group('rewindTo', () {
      test('cuts the history and hands the message back to edit', () async {
        when(
          () => agents.rewindTo('entry'),
        ).thenReturn(const Rewound(message: 'again'));
        final replacements = <ConversationReplacement>[];
        final sub = useCase.conversationReplacements.listen(replacements.add);
        addTearDown(sub.cancel);

        final result = useCase.rewindTo('entry');

        expect(result, isA<Rewound>());
        await Future<void>.delayed(Duration.zero);
        expect(
          replacements.single,
          isA<RewoundToMessage>().having((r) => r.message, 'message', 'again'),
        );
      });

      test('snaps the view back to the primary first', () {
        when(
          () => agents.rewindTo('entry'),
        ).thenReturn(const Rewound(message: 'again'));
        final sub = _MockAgentSession();
        when(() => sub.stream).thenAnswer((_) => const Stream.empty());
        when(() => sub.state).thenReturn(_idle);
        when(() => agents.sessionFor('sub')).thenReturn(sub);

        useCase
          ..viewSession('sub')
          ..rewindTo('entry');

        expect(useCase.viewingSubagent, isFalse);
      });

      test('a missing target changes nothing', () async {
        when(
          () => agents.rewindTo('entry'),
        ).thenReturn(const RewindTargetNotFound());
        final replacements = <ConversationReplacement>[];
        final sub = useCase.conversationReplacements.listen(replacements.add);
        addTearDown(sub.cancel);

        expect(useCase.rewindTo('entry'), isA<RewindTargetNotFound>());

        await Future<void>.delayed(Duration.zero);
        expect(replacements, isEmpty);
      });
    });

    group('canRewind', () {
      test('is true when idle with a live primary', () {
        expect(useCase.canRewind, isTrue);
      });

      test('is false without a model', () {
        when(
          () => providers.status,
        ).thenReturn(const ProviderStatusUnconfigured());

        expect(useCase.canRewind, isFalse);
      });

      test('is false mid-turn', () {
        when(
          () => session.conversationPhase,
        ).thenReturn(ConversationPhase.turnInFlight);

        expect(useCase.canRewind, isFalse);
      });

      test('is false while a subagent runs', () {
        when(() => agents.subagents).thenReturn(const [
          SubagentSummary(
            id: 'sub',
            title: 'Sub',
            status: SubagentStatus.running,
          ),
        ]);

        expect(useCase.canRewind, isFalse);
      });
    });

    test('reload-start always detaches the primary', () async {
      reloadsStartingController.add(null);
      await Future<void>.delayed(Duration.zero);

      verify(() => agents.bindProvider(null)).called(1);
    });

    test('canSubmit is true when primary is ready and idle', () {
      expect(useCase.canSubmit, isTrue);
    });

    test('canSubmit is false when a turn is in flight', () {
      when(
        () => session.conversationPhase,
      ).thenReturn(ConversationPhase.turnInFlight);
      expect(useCase.canSubmit, isFalse);
    });

    test('canSubmit is false when the provider is not ready', () {
      when(
        () => providers.status,
      ).thenReturn(const ProviderStatusUnconfigured());
      expect(useCase.canSubmit, isFalse);
    });

    // ── submit ──────────────────────────────────────────────

    test('submit returns false when conversationPhase != idle', () async {
      when(
        () => session.conversationPhase,
      ).thenReturn(ConversationPhase.turnInFlight);

      final result = await useCase.submit(
        message: 'hi',
        reasoningMode: 'off',
      );

      expect(result, isFalse);
      verifyNever(
        () => session.beginTurn(
          message: any(named: 'message'),
          options: any(named: 'options'),
        ),
      );
    });

    test(
      'submit returns false when the provider is still connecting',
      () async {
        when(() => providers.status).thenReturn(
          const ProviderStatusConnecting(
            model: ProviderModelRef(
              providerId: 'openrouter',
              modelId: 'openai/gpt-4o-mini',
            ),
          ),
        );

        final result = await useCase.submit(
          message: 'hi',
          reasoningMode: 'off',
        );

        expect(result, isFalse);
        verifyNever(
          () => session.beginTurn(
            message: any(named: 'message'),
            options: any(named: 'options'),
          ),
        );
      },
    );

    test('submit forwards to beginTurn and returns the repo result', () async {
      final result = await useCase.submit(
        message: 'hi',
        reasoningMode: 'medium',
      );

      expect(result, isTrue);
      final options = _capturedOptions(session);
      expect(options.systemPrompt, 'prompt [dyn]');
      expect(options.reasoningMode, 'medium');
      expect(options.compactionReasoningMode, 'auto');
    });

    test('submit runs under the sampling resolved at that moment', () async {
      sampling = const SamplingOptions(seed: 11, temperature: 0.7);

      await useCase.submit(message: 'hi', reasoningMode: 'off');

      final captured = _capturedOptions(session).sampling;
      expect(captured.seed, 11);
      expect(captured.temperature, 0.7);
    });

    test('submit runs compaction at the cheapest thinking mode', () async {
      stubReadyPrimary(supportsReasoning: true);

      await useCase.submit(message: 'hi', reasoningMode: 'high');

      expect(_capturedOptions(session).compactionReasoningMode, 'low');
    });

    // ── compact ─────────────────────────────────────────────

    group('compact', () {
      setUp(() {
        when(() => session.transcript).thenReturn(_foldableTranscript());
        when(
          () => session.beginCompactionTurn(any()),
        ).thenAnswer((_) async => true);
      });

      test('is possible when idle with foldable history', () {
        expect(useCase.canCompact, isTrue);
      });

      test('returns false when the provider is not ready', () async {
        when(
          () => providers.status,
        ).thenReturn(const ProviderStatusUnconfigured());

        expect(useCase.canCompact, isFalse);
        expect(await useCase.compact(), isFalse);
        verifyNever(() => session.beginCompactionTurn(any()));
      });

      test('returns false without a live agent', () async {
        when(() => session.canRunTurns).thenReturn(false);

        expect(await useCase.compact(), isFalse);
        verifyNever(() => session.beginCompactionTurn(any()));
      });

      test('returns false while a turn is in flight', () async {
        when(
          () => session.conversationPhase,
        ).thenReturn(ConversationPhase.turnInFlight);

        expect(await useCase.compact(), isFalse);
        verifyNever(() => session.beginCompactionTurn(any()));
      });

      test('returns false with nothing to fold', () async {
        when(
          () => session.transcript,
        ).thenReturn(_transcript());

        expect(useCase.canCompact, isFalse);
        expect(await useCase.compact(), isFalse);
        verifyNever(() => session.beginCompactionTurn(any()));
      });

      test('starts a compaction turn under the current options', () async {
        stubReadyPrimary(supportsReasoning: true);
        sampling = const SamplingOptions(seed: 5, temperature: 0.1);

        expect(await useCase.compact(), isTrue);

        final options =
            verify(
                  () => session.beginCompactionTurn(captureAny()),
                ).captured.single
                as TurnOptions;
        expect(options.systemPrompt, 'prompt [dyn]');
        expect(options.sampling.seed, 5);
        expect(options.reasoningMode, 'auto');
        expect(options.compactionReasoningMode, 'low');
      });
    });

    // ── cancel ──────────────────────────────────────────────

    test('cancel forwards to repo', () {
      when(() => session.cancel()).thenReturn(null);
      useCase.cancel();
      verify(() => session.cancel()).called(1);
    });

    // ── attachSession ───────────────────────────────────────

    test(
      'attachSession binds the provider, then stamps its model card',
      () async {
        final ready = stubReadyPrimary();

        useCase.attachSession(primary: ready.handle, primaryContextSize: 2048);
        await Future<void>.delayed(Duration.zero);

        verifyInOrder([
          () => agents.bindProvider(
            ready.handle,
            contextSize: 2048,
            systemPrompt: 'prompt [dyn]',
          ),
          () => session.recordModelChange(
            const ModelSnapshot.remote(
              modelId: 'openai/gpt-4o-mini',
              displayName: 'GPT-4o mini',
              contextSize: 1024,
              provider: 'OpenRouter',
            ),
          ),
        ]);
      },
    );

    test('attaching the same provider again leaves the card alone', () async {
      final ready = stubReadyPrimary();

      useCase
        ..attachSession(primary: ready.handle, primaryContextSize: 2048)
        ..attachSession(primary: ready.handle, primaryContextSize: 2048);
      await Future<void>.delayed(Duration.zero);

      verify(() => session.recordModelChange(any())).called(1);
    });

    test(
      'attachSession skips the card when the provider is not ready',
      () async {
        when(
          () => providers.status,
        ).thenReturn(const ProviderStatusUnconfigured());

        useCase.attachSession(
          primary: _MockAgentProvider(),
          primaryContextSize: 2048,
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => session.recordModelChange(any()));
      },
    );

    // ── clear ───────────────────────────────────────────────

    test('clear re-seeds only the loaded model card', () {
      useCase.clear();

      final ordered = verifyInOrder([
        agents.clear,
        () => session.recordModelChange(captureAny()),
      ]);
      verifyNever(() => session.addNotice(any()));

      final card = ordered[1].captured.single as ModelSnapshot;
      expect(card.modelId, 'openai/gpt-4o-mini');
      expect(card.provider, 'OpenRouter');
      expect(card.phase, ModelCardPhase.ready);
    });

    test('clear announces a fresh conversation', () async {
      final replacements = <ConversationReplacement>[];
      final sub = useCase.conversationReplacements.listen(replacements.add);
      addTearDown(sub.cancel);

      useCase.clear();

      await Future<void>.delayed(Duration.zero);
      expect(replacements.single, isA<StartedFresh>());
    });

    test('clear no-ops when the provider is not ready', () {
      when(
        () => providers.status,
      ).thenReturn(const ProviderStatusUnconfigured());

      useCase.clear();

      verifyNever(agents.clear);
    });

    // ── addSystemMessage ────────────────────────────────────

    test('addSystemMessage forwards a notice to the repo', () {
      useCase.addSystemMessage('hello');
      verify(() => session.addNotice('hello')).called(1);
    });

    // ── subagents ───────────────────────────────────────────

    test('stopSubagent forwards to the repo', () {
      when(() => agents.stopSubagent(any())).thenReturn(null);
      useCase.stopSubagent('subagent:0');
      verify(() => agents.stopSubagent('subagent:0')).called(1);
    });

    test('clearSettledSubagents forwards to the repo', () {
      when(() => agents.clearSettledSubagents()).thenAnswer((_) async {});
      useCase.clearSettledSubagents();
      verify(() => agents.clearSettledSubagents()).called(1);
    });

    // ── palette commands ────────────────────────────────────

    group('palette commands', () {
      Command commandById(String id) =>
          useCase.commands.firstWhere((command) => command.id == id);

      Future<Availability> firstGate(Command command) async {
        final gates = <Availability>[];
        final sub = command.availability.listen(gates.add);
        addTearDown(sub.cancel);
        await Future<void>.delayed(Duration.zero);
        return gates.first;
      }

      const turnInFlight = TurnInProgress(
        timelineItems: [],
        conversationPhase: ConversationPhase.turnInFlight,
        activity: TurnActivity.thinking,
      );

      test('contributes the chat commands', () {
        expect(
          useCase.commands.map((command) => command.id),
          containsAll([
            'chat.stop',
            'chat.clear',
            'chat.load',
            'chat.rewind',
            'chat.compact',
          ]),
        );
      });

      group('rewind', () {
        test('asks the surface to start the pick', () async {
          final requests = <void>[];
          final sub = useCase.rewindRequests.listen(requests.add);
          addTearDown(sub.cancel);
          final command = commandById('chat.rewind');
          expect(await firstGate(command), isA<Available>());

          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRan>(),
          );

          await Future<void>.delayed(Duration.zero);
          expect(requests, hasLength(1));
        });

        test('is unavailable mid-turn', () async {
          when(() => session.state).thenReturn(turnInFlight);
          when(
            () => session.conversationPhase,
          ).thenReturn(ConversationPhase.turnInFlight);
          final requests = <void>[];
          final sub = useCase.rewindRequests.listen(requests.add);
          addTearDown(sub.cancel);
          final command = commandById('chat.rewind');

          final gate = await firstGate(command);
          expect((gate as Unavailable).reason, 'turn in progress');
          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRejected>(),
          );
          await Future<void>.delayed(Duration.zero);
          expect(requests, isEmpty);
        });
      });

      group('load', () {
        const conversationKey = ParamKey<String>('conversation');

        test('lists saved conversations other than the current one', () async {
          when(() => session.transcript).thenReturn(_transcript(id: 'now'));
          when(() => agents.conversations()).thenAnswer(
            (_) async => [
              _summary('now', firstUserMessage: 'this one'),
              _summary('then', firstUserMessage: 'that one'),
            ],
          );
          final command = commandById('chat.load');
          expect(await firstGate(command), isA<Available>());

          final param = command.next(const Answers.empty())!;
          expect(param, isA<ChoiceParam<String>>());
          final choice = param as ChoiceParam<String>;
          expect(choice.filter, isA<SearchFilter<String>>());
          final options = await choice.options.first;
          expect(options.single.value, 'then');
          expect(options.single.detail, 'that one');
          expect(options.single.label, startsWith('~/proj · '));

          final answers = const Answers.empty().put(conversationKey, 'then');
          expect(command.next(answers), isNull);
        });

        test('loads the pick', () async {
          when(
            () => agents.load('then'),
          ).thenAnswer((_) async => const ConversationLoaded());
          final answers = const Answers.empty().put(conversationKey, 'then');

          expect(
            await commandById('chat.load').invoke(answers),
            isA<CommandRan>(),
          );
          verify(() => agents.load('then')).called(1);
        });

        test('rejects a pick that has since vanished', () async {
          when(
            () => agents.load('gone'),
          ).thenAnswer((_) async => const ConversationNotFound());
          final answers = const Answers.empty().put(conversationKey, 'gone');

          final result = await commandById('chat.load').invoke(answers);
          expect(result, isA<CommandRejected>());
          expect(
            (result as CommandRejected).reason,
            'conversation no longer exists',
          );
        });

        test('is unavailable without a model', () async {
          when(
            () => providers.status,
          ).thenReturn(const ProviderStatusUnconfigured());
          final command = commandById('chat.load');

          final gate = await firstGate(command);
          expect((gate as Unavailable).reason, 'no model loaded');
          final answers = const Answers.empty().put(conversationKey, 'x');
          expect(await command.invoke(answers), isA<CommandRejected>());
          verifyNever(() => agents.load(any()));
        });

        test('is unavailable mid-turn', () async {
          when(() => session.state).thenReturn(turnInFlight);
          when(
            () => session.conversationPhase,
          ).thenReturn(ConversationPhase.turnInFlight);

          final gate = await firstGate(commandById('chat.load'));
          expect((gate as Unavailable).reason, 'turn in progress');
        });

        test(
          'is unavailable while a subagent runs, until it settles',
          () async {
            when(() => agents.subagents).thenReturn(const [
              SubagentSummary(
                id: 'sub',
                title: 'Sub',
                status: SubagentStatus.running,
              ),
            ]);
            final gates = <Availability>[];
            final sub = commandById('chat.load').availability.listen(gates.add);
            addTearDown(sub.cancel);
            await Future<void>.delayed(Duration.zero);
            expect(
              (gates.single as Unavailable).reason,
              'subagents still running',
            );

            when(() => agents.subagents).thenReturn(const [
              SubagentSummary(
                id: 'sub',
                title: 'Sub',
                status: SubagentStatus.completed,
              ),
            ]);
            subagentsController.add(const []);
            await Future<void>.delayed(Duration.zero);
            expect(gates.last, isA<Available>());
          },
        );
      });

      group('compact', () {
        setUp(() {
          when(() => session.transcript).thenReturn(_foldableTranscript());
          when(
            () => session.beginCompactionTurn(any()),
          ).thenAnswer((_) async => true);
        });

        test('runs when idle with foldable history', () async {
          final command = commandById('chat.compact');
          expect(command.next(const Answers.empty()), isNull);
          expect(await firstGate(command), isA<Available>());

          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRan>(),
          );
          verify(() => session.beginCompactionTurn(any())).called(1);
        });

        test('is gated on a loaded model', () async {
          when(
            () => providers.status,
          ).thenReturn(const ProviderStatusUnconfigured());
          final command = commandById('chat.compact');

          final gate = await firstGate(command);
          expect(gate, isA<Unavailable>());
          expect((gate as Unavailable).reason, 'no model loaded');
          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRejected>().having(
              (rejected) => rejected.reason,
              'reason',
              'no model loaded',
            ),
          );
          verifyNever(() => session.beginCompactionTurn(any()));
        });

        test('is gated on the primary being idle', () async {
          when(() => session.state).thenReturn(turnInFlight);
          when(
            () => session.conversationPhase,
          ).thenReturn(ConversationPhase.turnInFlight);
          final command = commandById('chat.compact');

          final gate = await firstGate(command);
          expect(gate, isA<Unavailable>());
          expect((gate as Unavailable).reason, 'turn in progress');
          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRejected>(),
          );
        });

        test('is gated on there being history to fold', () async {
          when(() => session.transcript).thenReturn(
            _transcript(),
          );
          final command = commandById('chat.compact');

          final gate = await firstGate(command);
          expect(gate, isA<Unavailable>());
          expect((gate as Unavailable).reason, 'nothing to compact');
          expect(
            await command.invoke(const Answers.empty()),
            isA<CommandRejected>(),
          );
        });

        test('re-evaluates on every conversation tick', () async {
          final command = commandById('chat.compact');
          final gates = <Availability>[];
          final sub = command.availability.listen(gates.add);
          addTearDown(sub.cancel);
          await Future<void>.delayed(Duration.zero);

          when(() => session.transcript).thenReturn(
            _transcript(),
          );
          convController.add(_idle);
          await Future<void>.delayed(Duration.zero);

          expect(gates, [isA<Available>(), isA<Unavailable>()]);
        });
      });

      test('stop is gated on a turn being in flight', () async {
        final command = commandById('chat.stop');
        final idleGate = await firstGate(command);
        expect(idleGate, isA<Unavailable>());
        expect((idleGate as Unavailable).reason, 'no turn running');
        expect(
          await command.invoke(const Answers.empty()),
          isA<CommandRejected>(),
        );

        when(() => session.state).thenReturn(turnInFlight);
        expect(await firstGate(command), isA<Available>());
        expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
        verify(() => session.cancel()).called(1);
      });

      test('clear confirms then clears when ready', () async {
        final command = commandById('chat.clear');
        expect(await firstGate(command), isA<Available>());

        final confirm = command.next(const Answers.empty())!;
        expect(confirm, isA<ConfirmParam>());
        expect((confirm as ConfirmParam).danger, isTrue);

        final answers = const Answers.empty().put(confirm.key, true);
        expect(command.next(answers), isNull);
        expect(await command.invoke(answers), isA<CommandRan>());
        verify(agents.clear).called(1);
      });

      test(
        'clear is unavailable and rejects when no model is loaded',
        () async {
          when(
            () => providers.status,
          ).thenReturn(const ProviderStatusUnconfigured());
          final command = commandById('chat.clear');
          final gate = await firstGate(command);
          expect(gate, isA<Unavailable>());
          expect((gate as Unavailable).reason, 'no model loaded');

          final answers = const Answers.empty().put(
            const ParamKey<bool>('clearConfirm'),
            true,
          );
          expect(await command.invoke(answers), isA<CommandRejected>());
          verifyNever(agents.clear);
        },
      );
    });
  });
}

TurnOptions _capturedOptions(_MockAgentSession session) =>
    verify(
          () => session.beginTurn(
            message: any(named: 'message'),
            options: captureAny(named: 'options'),
          ),
        ).captured.single
        as TurnOptions;

/// A stand-in for the primary's history. The use case reads where the
/// conversation lives and whether it could be folded; the rest of the surface
/// belongs to the repository and never reaches here.
final class _Transcript implements AgentTranscript {
  _Transcript({
    this.conversationId = 'c-1',
    this.workingDirectory = '/work',
    this.hasFoldableHistory = false,
  });

  @override
  final String conversationId;

  @override
  final String workingDirectory;

  @override
  final bool hasFoldableHistory;

  @override
  String get agentId => primaryAgentSessionId;

  @override
  DateTime get createdAt => DateTime.utc(2025);

  @override
  DateTime get updatedAt => DateTime.utc(2025);

  @override
  List<ConversationEntry> get entries => const [];

  @override
  bool get isEmpty => !hasFoldableHistory;

  @override
  Transcript get transcript =>
      throw UnimplementedError('the use case reads the session, not this');

  @override
  List<TimelineItem> get timeline =>
      throw UnimplementedError('the use case reads the session, not this');

  @override
  String? userMessageText(String entryId) => null;
}

/// An empty primary transcript.
AgentTranscript _transcript({
  String id = 'c-1',
  String workingDirectory = '/work',
}) => _Transcript(conversationId: id, workingDirectory: workingDirectory);

ConversationSummary _summary(String id, {required String firstUserMessage}) =>
    ConversationSummary(
      id: id,
      workingDirectory: '/home/j/proj',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      firstUserMessage: firstUserMessage,
      searchText: firstUserMessage.toLowerCase(),
    );

/// A transcript with a user message since its last compaction.
AgentTranscript _foldableTranscript() => _Transcript(hasFoldableHistory: true);

ProviderStatusReady _ready({required bool supportsReasoning}) =>
    ProviderStatusReady(
      model: ResolvedModel(
        ref: const ProviderModelRef(
          providerId: 'openrouter',
          modelId: 'openai/gpt-4o-mini',
        ),
        name: 'GPT-4o mini',
        contextWindow: 1024,
        supportsTools: true,
        reasoning: supportsReasoning
            ? const ProviderReasoningEfforts(
                efforts: ['low', 'medium', 'high'],
                canDisable: true,
              )
            : null,
      ),
      handle: _MockAgentProvider(),
      keyInfo: const ProviderKeyInfo(label: 'key', usage: 0, isFreeTier: false),
      providerName: 'OpenRouter',
    );

ChatConfigKeys _testConfigKeys() {
  return ChatConfigKeys(
    systemPrompt: _globalString('prompt.system'),
    memoryCompactionRatio: _globalDouble('memory.compaction_ratio'),
    maxToolCallCharacters: _globalInt('tools.max_call_characters'),
  );
}

ConfigKey<int> _globalInt(String id) => ConfigKey<int>(
  id: id,
  path: [id],
  codec: ConfigCodecs.integers,
  defaultValue: () => defaultMaxToolCallCharacters,
);

ConfigKey<String> _globalString(String id) => ConfigKey<String>(
  id: id,
  path: [id],
  codec: ConfigCodecs.strings,
  defaultValue: () => 'prompt',
);

ConfigKey<double> _globalDouble(String id) => ConfigKey<double>(
  id: id,
  path: [id],
  codec: ConfigCodecs.doubles,
  defaultValue: () => defaultCompactionRatio,
);
