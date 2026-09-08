import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:agent_repository/src/conversation/agent_journal.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

import 'agent_test_support.dart';

void main() {
  setUpAll(registerFallbacks);

  late StreamController<AgentRuntimeEvent> events;

  /// The history the agent was last told to run over. The runtime mirrors it
  /// back when it announces the turn.
  Transcript? handedToRun;
  late MockAgent agent;
  late MockPendingToolCalls toolOrchestrator;
  late ToolDefinitions toolDefinitions;
  late MockConversationStore store;

  void wireAgent() {
    when(() => agent.handle).thenReturn(agentHandle);
    when(() => agent.kind).thenReturn(AgentKind.primary);
    when(() => agent.events).thenAnswer((_) => events.stream);
    when(
      () => agent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((invocation) async {
      handedToRun = invocation.positionalArguments.first as Transcript;
      return const RunAccepted();
    });
    when(
      () => agent.submitToolResults(any()),
    ).thenAnswer((_) async => const SubmitToolResultsAccepted());
    when(
      () => agent.submitCompactionPrompt(any()),
    ).thenAnswer((_) async => const SubmitCompactionPromptAccepted());
    when(() => agent.cancel()).thenAnswer((_) async => const CancelAccepted());
  }

  setUp(() {
    events = StreamController<AgentRuntimeEvent>.broadcast();
    handedToRun = null;
    agent = MockAgent();
    wireAgent();

    toolOrchestrator = MockPendingToolCalls();
    toolDefinitions = offering();
    when(
      () => toolOrchestrator.join(any(), aborted: any(named: 'aborted')),
    ).thenAnswer((_) async => const <ToolCallResponse>[]);

    store = MockConversationStore();
    when(() => store.save(any())).thenAnswer((_) async {});
    when(
      () => store.load(any(), agentId: any(named: 'agentId')),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    if (!events.isClosed) await events.close();
  });

  AgentJournal journal({List<ConversationEntry> entries = const []}) =>
      AgentJournal.fromSessionData(
        data(entries),
        store: store,
      );

  AgentSession live({AgentJournal? history}) => AgentSession.live(
    id: primaryAgentSessionId,
    agent: agent,
    options: const TurnOptions.baseline('baseline prompt'),
    compactionRatio: testCompactionRatio,
    maxOutputChars: testMaxToolCallCharacters,
    journal: history ?? journal(),
    contextSize: 2048,
    compactionPromptContentBuilder: const FixedCompactionPromptContentBuilder(
      testCompactionPromptContent,
    ),
    tools: toolOrchestrator,
    toolDefinitions: toolDefinitions,
  );

  const options = TurnOptions(
    systemPrompt: 'system prompt',
    sampling: SamplingOptions(seed: 7, temperature: 0.5),
    reasoningMode: 'auto',
    compactionReasoningMode: 'low',
  );

  Future<bool> begin(
    AgentSession session, {
    String message = 'hello',
  }) => session.beginTurn(message: message, options: options);

  AgentConfig capturedConfig() =>
      verify(
            () => agent.run(
              any(),
              config: captureAny(named: 'config'),
              goal: any(named: 'goal'),
            ),
          ).captured.single
          as AgentConfig;

  List<MessageTimelineItem> rows(AgentSession session) =>
      rowsOf(session.timelineItems);

  DeliveredJobReport deliveredReport() => DeliveredJobReport.fromJobReport(
    const JobReport(
      conversationId: 'conversation',
      agentId: primaryAgentSessionId,
      callId: 'call',
      toolName: 'subagent',
      arguments: {},
      outcome: JobSucceeded('report'),
      outstanding: 0,
    ),
  );

  group('placeholder', () {
    late AgentSession session;

    setUp(() {
      session = AgentSession.placeholder(
        id: primaryAgentSessionId,
        compactionRatio: testCompactionRatio,
        maxOutputChars: testMaxToolCallCharacters,
        journal: journal(),
        contextSize: null,
        tools: toolOrchestrator,
      );
    });

    tearDown(() => session.dispose());

    test('cannot run turns', () {
      expect(session.canRunTurns, isFalse);
      expect(session.conversationPhase, ConversationPhase.idle);
      expect(session.state, isA<ConversationIdle>());
    });

    test('beginTurn rejects without a live agent', () async {
      expect(
        await session.beginTurn(message: 'hi', options: options),
        isFalse,
      );
    });

    test('beginCompactionTurn rejects without a live agent', () async {
      expect(await session.beginCompactionTurn(options), isFalse);
    });

    test('beginDeliveryTurn rejects without a live agent', () async {
      expect(await session.beginDeliveryTurn([deliveredReport()]), isFalse);
    });

    test('accepts notices and model cards', () {
      session
        ..addNotice('welcome')
        ..setLiveModelStatus(modelSnapshot());

      expect(
        session.timelineItems.whereType<NoticeTimelineItem>(),
        hasLength(1),
      );
      expect(
        session.timelineItems.whereType<ModelCardTimelineItem>(),
        hasLength(1),
      );
    });

    test('loadTranscript swaps in fresh history', () {
      session
        ..addNotice('old')
        ..loadJournal(
          journal(entries: [msgUser('u'), msgAsst('a')]),
          MockPendingToolCalls(),
        );

      expect(rows(session), hasLength(2));
      expect(session.timelineItems.whereType<NoticeTimelineItem>(), isEmpty);
    });

    test('turn getters are inert and cancel is a no-op', () {
      expect(session.currentTurnReasoning, isEmpty);
      expect(session.cancel, returnsNormally);
    });
  });

  group('beginTurn', () {
    test('returns false when a turn is already running', () async {
      final session = live();
      addTearDown(session.dispose);
      expect(await begin(session), isTrue);
      expect(await begin(session, message: 'again'), isFalse);
    });

    test('an accepted run moves to turnInFlight', () async {
      final session = live();
      addTearDown(session.dispose);
      expect(await begin(session), isTrue);
      expect(session.conversationPhase, ConversationPhase.turnInFlight);
      expect(session.state, isA<TurnInProgress>());
    });

    test(
      'publishes the seeded user message immediately, before the agent runs',
      () async {
        // Hold the run open so beginTurn cannot complete.
        final gate = Completer<RunResult>();
        when(
          () => agent.run(
            any(),
            config: any(named: 'config'),
            goal: any(named: 'goal'),
          ),
        ).thenAnswer((_) => gate.future);

        final session = live();
        addTearDown(session.dispose);

        final emissions = <ConversationState>[];
        final sub = session.stream.listen(emissions.add);

        // Keep run pending while the turn is projected.
        final pending = begin(session, message: 'hello there');
        await pump();

        final state = emissions.last;
        expect(state, isA<TurnInProgress>());
        final user = rowsOf(
          state.timelineItems,
        ).singleWhere((m) => m.role == Role.user);
        expect(user.text, 'hello there');
        expect(
          state.timelineItems.whereType<ReasoningStubTimelineItem>().any(
            (r) => r.running,
          ),
          isTrue,
          reason: 'a pending "thinking" stub should show while prefilling',
        );

        gate.complete(const RunAccepted());
        await pending;
        await sub.cancel();
      },
    );

    test(
      'passes sampling, reasoning, and registry tools to Agent.run',
      () async {
        const tool = ToolDefinition(
          onProgress: 'Running',
          onSuccess: 'Ran',
          onError: 'Failed',
          name: 'search',
          description: 'search the web',
          parameters: {},
        );
        toolDefinitions = offering(const [tool]);

        final session = live();
        addTearDown(session.dispose);
        await begin(session);

        final config = capturedConfig();
        expect(config.systemPrompt, 'system prompt');
        expect(config.sampling.seed, 7);
        expect(config.sampling.temperature, 0.5);
        expect(config.reasoningMode, 'auto');
        expect(config.compactionReasoningMode, 'low');
        expect(config.tools, [tool]);
      },
    );

    test(
      'seeds the transcript with history plus the new user message',
      () async {
        final session = live(
          history: AgentJournal.fromSessionData(
            store: store,
            data([msgUser('earlier'), msgAsst('a')]),
          ),
        );
        addTearDown(session.dispose);

        await begin(session, message: 'new question');

        final transcript =
            verify(
                  () => agent.run(
                    captureAny(),
                    config: any(named: 'config'),
                    goal: any(named: 'goal'),
                  ),
                ).captured.single
                as Transcript;
        final lastEntry = transcript.entries.last;
        expect(lastEntry.role, Role.user);
        expect(
          lastEntry.blocks.whereType<TranscriptParagraphBlock>().first.text,
          'new question',
        );
        expect(transcript.entries, hasLength(3));
      },
    );

    test('a rejected run surfaces a failure and idles', () async {
      when(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).thenAnswer(
        (_) async =>
            const RunRejected(reason: AgentRuntimeRejectionReason.busy),
      );

      final session = live();
      addTearDown(session.dispose);

      expect(await begin(session), isFalse);
      final state = session.state as ConversationIdle;
      expect(state.failure?.reason, AgentRunFailureReason.loopFailed);
    });
  });

  group('beginDeliveryTurn', () {
    test(
      'appends reports and starts an unsolicited turn after prior replies',
      () async {
        final transcript = journal()
          ..append(msgAsst('earlier', responseId: 4))
          ..append(
            NoticeEntry(
              id: 'notice',
              timestamp: DateTime.utc(2025),
              text: 'context',
            ),
          )
          ..append(
            JobReportEntry(
              id: 'prior-report',
              timestamp: DateTime.utc(2025),
              responseId: 7,
              reports: const [],
            ),
          );
        final session = live(history: transcript);
        addTearDown(session.dispose);

        expect(await session.beginDeliveryTurn([deliveredReport()]), isTrue);
        final submitted =
            verify(
                  () => agent.run(
                    captureAny(),
                    config: any(named: 'config'),
                    goal: any(named: 'goal'),
                  ),
                ).captured.single
                as Transcript;
        expect(submitted.entries, hasLength(3));
        expect(session.transcript.entries.last, isA<JobReportEntry>());
      },
    );

    test(
      "runs under the session's initial options before any user turn",
      () async {
        final session = live();
        addTearDown(session.dispose);

        expect(await session.beginDeliveryTurn([deliveredReport()]), isTrue);

        final config = capturedConfig();
        expect(config.systemPrompt, 'baseline prompt');
        expect(config.sampling.seed, 0);
        expect(config.reasoningMode, 'auto');
        expect(config.compactionReasoningMode, 'auto');
      },
    );

    test("runs under the last user turn's options", () async {
      final session = live();
      addTearDown(session.dispose);
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: emptyTranscript(),
          ),
        );
      await pump();
      clearInteractions(agent);

      expect(await session.beginDeliveryTurn([deliveredReport()]), isTrue);

      final config = capturedConfig();
      expect(config.systemPrompt, 'system prompt');
      expect(config.sampling.seed, 7);
      expect(config.compactionReasoningMode, 'low');
    });

    test('does not append reports while another turn is active', () async {
      final session = live();
      addTearDown(session.dispose);
      await begin(session);

      expect(await session.beginDeliveryTurn([deliveredReport()]), isFalse);
      // Only the message that opened the turn; no report joined it.
      expect(session.transcript.entries, hasLength(1));
      expect(session.transcript.entries.single, isA<MessageEntry>());
    });
  });

  group('beginCompactionTurn', () {
    AgentJournal foldable() => AgentJournal.fromSessionData(
      store: store,
      data([msgUser('earlier'), msgAsst('a')]),
    );

    test('returns false while a turn is active', () async {
      final session = live(history: foldable());
      addTearDown(session.dispose);
      await begin(session);

      expect(await session.beginCompactionTurn(options), isFalse);
    });

    test('returns false when nothing could be folded', () async {
      final session = live();
      addTearDown(session.dispose);

      expect(await session.beginCompactionTurn(options), isFalse);
      verifyNever(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      );
    });

    test('runs the agent toward a compact goal under the options', () async {
      final session = live(history: foldable());
      addTearDown(session.dispose);

      expect(await session.beginCompactionTurn(options), isTrue);
      expect(session.conversationPhase, ConversationPhase.turnInFlight);

      final submitted =
          verify(
                () => agent.run(
                  captureAny(),
                  config: captureAny(named: 'config'),
                  goal: TurnGoal.compact,
                ),
              ).captured
              as List<Object?>;
      final transcript = submitted[0]! as Transcript;
      final config = submitted[1]! as AgentConfig;
      expect(transcript.entries, hasLength(2));
      expect(config.systemPrompt, 'system prompt');
      expect(config.compactionReasoningMode, 'low');
    });

    test('commits the fold as a compaction entry and idles', () async {
      final session = live(history: foldable());
      addTearDown(session.dispose);
      await session.beginCompactionTurn(options);

      final base = [userTE('earlier'), asstTE('a')];
      final folded = ts([...base, summaryTE('Summary of earlier.')]);
      events
        ..add(
          AgentStarted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: ts(base),
          ),
        )
        ..add(compactionStarted(tokensBefore: 640))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('Summary of earlier.'),
          ),
        )
        ..add(
          AgentUpdated(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: folded,
          ),
        )
        ..add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: folded,
          ),
        );
      await pump();

      expect(session.conversationPhase, ConversationPhase.idle);
      expect(session.failure, isNull);
      final entry = session.transcript.entries.last as CompactionEntry;
      expect(entry.summary, 'Summary of earlier.');
      expect(entry.tokensBefore, 640);
      expect(session.transcript.hasFoldableHistory, isFalse);
    });

    test('a rejected run surfaces a failure and idles', () async {
      when(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).thenAnswer(
        (_) async => const RunRejected(
          reason: AgentRuntimeRejectionReason.nothingToCompact,
        ),
      );
      final session = live(history: foldable());
      addTearDown(session.dispose);

      expect(await session.beginCompactionTurn(options), isFalse);
      final state = session.state as ConversationIdle;
      expect(state.failure?.message, contains('nothingToCompact'));
    });
  });

  group('loadTranscript on a live session', () {
    late AgentSession session;
    late MockPendingToolCalls next;

    setUp(() {
      session = live();
      next = MockPendingToolCalls();
      when(
        () => next.join(any(), aborted: any(named: 'aborted')),
      ).thenAnswer((_) async => const <ToolCallResponse>[]);
    });
    tearDown(() => session.dispose());

    test('retires the orchestrator it replaces', () {
      session.loadJournal(
        journal(),
        next,
      );

      verify(toolOrchestrator.dispose).called(1);
    });

    test('routes later tool work to the orchestrator it was given', () async {
      session.loadJournal(
        journal(),
        next,
      );

      await begin(session);

      verify(next.reset).called(1);
      verifyNever(toolOrchestrator.reset);
    });
  });

  group('turn projection', () {
    late AgentSession session;

    setUp(() => session = live());
    tearDown(() => session.dispose());

    bool hasRunningThinking(ConversationState state) => state.timelineItems
        .whereType<ReasoningStubTimelineItem>()
        .any((r) => r.running);

    test(
      'text and reasoning deltas accumulate into the assistant message',
      () async {
        await begin(session);
        events
          ..add(started(transcript: handedToRun))
          ..add(reasoning('hmm'))
          ..add(reasoning('mm'))
          ..add(text('the '))
          ..add(text('answer'));
        await pump();

        final state = session.state as TurnInProgress;
        final reasoningStub = state.timelineItems
            .whereType<ReasoningStubTimelineItem>()
            .single;
        expect(reasoningStub.text, 'hmmmm');
        final answer = rowsOf(state.timelineItems).last;
        expect(answer.role, Role.assistant);
        expect(answer.text, 'the answer');
      },
    );

    test(
      'shows a thinking stub eagerly while prefilling at turn start',
      () async {
        await begin(session);
        expect(hasRunningThinking(session.state), isTrue);
      },
    );

    test(
      'shows a thinking stub while prefilling after a tool result',
      () async {
        await begin(session);
        events
          ..add(started(transcript: handedToRun))
          ..add(
            resultApplied(
              const ToolCallSucceeded(
                callId: 'tc1',
                toolName: 'search',
                content: 'found',
              ),
            ),
          );
        await pump();

        expect(hasRunningThinking(session.state), isTrue);
      },
    );

    test('drops the thinking stub once output streams', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('hello'));
      await pump();

      expect(hasRunningThinking(session.state), isFalse);
    });

    test('a drafted tool call takes the tail from the thinking stub', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('which file?'))
        ..add(text('let me look'))
        ..add(
          AgentToolCallStarted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            name: 'search',
          ),
        );
      await pump();

      final state = session.state as TurnInProgress;
      expect(state.activity, TurnActivity.draftingToolCall);
      expect(hasRunningThinking(state), isFalse);
      expect(rowsOf(state.timelineItems).last.running, isFalse);
      expect(state.timelineItems.last, isA<ToolCallDraftTimelineItem>());
    });

    test('the drafted call gives way to its own row once whole', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          AgentToolCallStarted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            name: 'search',
          ),
        )
        ..add(
          AgentToolCallEmitted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            entryId: asstEntryId,
            blockId: TranscriptBlockId.v7(),
            toolCall: const ToolCallDefault(
              id: 'tc1',
              name: 'search',
              arguments: {},
            ),
          ),
        );
      await pump();

      final state = session.state as TurnInProgress;
      expect(state.activity, TurnActivity.executingTools);
      expect(
        state.timelineItems.whereType<ToolCallDraftTimelineItem>(),
        isEmpty,
      );
      final tool = state.timelineItems.whereType<ToolActivityTimelineItem>();
      expect(tool.single.running, isTrue);
      expect(hasRunningThinking(state), isFalse);
    });

    test('exposes the current turn reasoning as blocks', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('hmm'))
        ..add(reasoning('mm'));
      await pump();

      expect(session.currentTurnReasoning, ['hmmmm']);
    });

    test('a failed compaction leaves the turn untouched', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: const AgentCompactionFailed(
              reason: 'workspaceExhausted',
            ),
          ),
        );
      await pump();

      expect(
        session.state.timelineItems.whereType<CompactionMarkerTimelineItem>(),
        isEmpty,
      );
      expect(session.state, isA<TurnInProgress>());
    });

    test('answers a compaction prompt request with fresh content', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          AgentNeedsCompactionPrompt(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
          ),
        );
      await pump();

      final submitted = verify(
        () => agent.submitCompactionPrompt(captureAny()),
      ).captured.single;
      expect(submitted, same(testCompactionPromptContent));
    });

    test('starts a streamed tool eagerly, then joins and submits', () async {
      const result = ToolCallSucceeded(
        callId: 'tc1',
        toolName: 'search',
        content: 'found',
      );
      when(
        () => toolOrchestrator.join(any(), aborted: any(named: 'aborted')),
      ).thenAnswer((_) async => [result]);

      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();
      const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
      final entryId = TranscriptEntryId.v7();

      // Execution starts as soon as the call streams.
      events.add(
        AgentToolCallEmitted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          entryId: entryId,
          blockId: TranscriptBlockId.v7(),
          toolCall: call,
        ),
      );
      await pump();
      verify(
        () => toolOrchestrator.start(
          call,
          maxOutputChars: any(named: 'maxOutputChars'),
        ),
      ).called(1);

      // Generation ends: the barrier joins the started tools and submits.
      events.add(
        AgentNeedsToolResults(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          entry: TranscriptEntry(
            id: entryId,
            role: Role.assistant,
            blocks: [
              TranscriptToolCallBlock(
                id: TranscriptBlockId.v7(),
                toolCall: call,
              ),
            ],
          ),
          toolCalls: const [call],
        ),
      );
      await pump();

      verify(() => agent.submitToolResults([result])).called(1);

      final inProgress = session.state as TurnInProgress;
      final activity = inProgress.timelineItems
          .whereType<ToolActivityTimelineItem>()
          .single;
      expect(activity.toolCall.name, 'search');
      expect(activity.result, isNull);
      expect(activity.running, isTrue);
    });

    test(
      'an applied error result is not surfaced as a separate alert',
      () async {
        await begin(session);
        events
          ..add(started(transcript: handedToRun))
          ..add(
            resultApplied(
              const ToolCallFailed(
                callId: 'tc1',
                toolName: 'search',
                message: 'nope',
              ),
            ),
          );
        await pump();
        events.add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: emptyTranscript(),
          ),
        );
        await pump();

        // The failure lives on the tool result block, not as a floating notice.
        expect(session.timelineItems.whereType<NoticeTimelineItem>(), isEmpty);
      },
    );

    group('backgrounded jobs', () {
      const job = JobInBackground(callId: 'tc1', toolName: 'bash');

      test('files one behind the answer, before the model replies', () async {
        // The row has to land between the tool result and whatever the model
        // says next, or it reads as though the work started afterwards.
        final session = live();
        addTearDown(session.dispose);
        await begin(session);
        events.add(started(transcript: handedToRun));
        await pump();

        session.noteBackgrounded(job);

        events.add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: ts([
              userTE('q'),
              toolCallTE('tc1'),
              toolResultTE('tc1'),
              asstTE('I started that for you.'),
            ]),
          ),
        );
        await pump();

        final kinds = session.transcript.entries.map((e) => e.runtimeType);
        expect(kinds, [
          MessageEntry, // the question
          MessageEntry, // the call
          MessageEntry, // the result
          JobBackgroundedEntry, // the job it left running
          MessageEntry, // only then, the reply
        ]);
      });

      test('files one from a live turn after the turn it came from', () async {
        // The turn's own entries are not appended until it commits, so a job
        // filed on announcement would sit above the call that started it.
        final session = live();
        addTearDown(session.dispose);
        await begin(session);
        events.add(started(transcript: handedToRun));
        await pump();

        session.noteBackgrounded(job);

        // Visible at once all the same, without waiting for the turn to end.
        expect(
          session.timelineItems.whereType<BackgroundJobTimelineItem>(),
          hasLength(1),
        );

        events.add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: ts([userTE('q'), asstTE('a')]),
          ),
        );
        await pump();

        expect(session.transcript.entries.map((e) => e.runtimeType), [
          MessageEntry,
          MessageEntry,
          JobBackgroundedEntry,
        ]);
      });

      test('files one announced between turns straight away', () async {
        final session = live();
        addTearDown(session.dispose);

        session.noteBackgrounded(job);

        expect(session.transcript.entries.single, isA<JobBackgroundedEntry>());
        expect(session.timelineItems.single, isA<BackgroundJobTimelineItem>());
      });

      test('keeps one from a turn the runtime refuses to start', () async {
        // A rejection lands after the turn is already open, so a job could in
        // principle be announced into that window. Nothing commits on this
        // path, so the scratch flush is the only thing that would file it.
        late final AgentSession opening;
        when(
          () => agent.run(
            any(),
            config: any(named: 'config'),
            goal: any(named: 'goal'),
          ),
        ).thenAnswer((
          _,
        ) async {
          opening.noteBackgrounded(job);
          return const RunRejected(reason: AgentRuntimeRejectionReason.busy);
        });
        final session = live();
        addTearDown(session.dispose);
        opening = session;

        expect(await begin(session), isFalse);

        // The message that opened the turn stays, and the job files behind it.
        expect(session.transcript.entries.map((entry) => entry.runtimeType), [
          MessageEntry,
          JobBackgroundedEntry,
        ]);
      });

      test('keeps one from a turn that never commits', () async {
        // A rejected turn files nothing of its own, but the job it started is
        // still out there running.
        final session = live();
        addTearDown(session.dispose);
        await begin(session);
        events.add(started(transcript: handedToRun));
        await pump();
        session
          ..noteBackgrounded(job)
          ..cancel();
        await pump();

        expect(
          session.transcript.entries.whereType<JobBackgroundedEntry>(),
          hasLength(1),
        );
      });
    });

    test('summary deltas stream onto a live compaction marker', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 640))
        ..add(
          AgentSummaryDelta(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            text: 'rolling ',
          ),
        )
        ..add(
          AgentSummaryDelta(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            text: 'memory',
          ),
        );
      await pump();

      final marker = session.state.timelineItems
          .whereType<CompactionMarkerTimelineItem>()
          .single;
      expect(marker.running, isTrue);
      expect(marker.summary, 'rolling memory');
      expect(marker.tokensBefore, 640);
      expect(
        (session.state as TurnInProgress).activity,
        TurnActivity.compacting,
      );
    });

    test('a completed compaction materialises a marker at commit', () async {
      await begin(session, message: 'q');
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 512))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('the summary'),
          ),
        );
      await pump();
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('q'), asstTE('a'), summaryTE('the summary')]),
        ),
      );
      await pump();

      final markers = session.state.timelineItems
          .whereType<CompactionMarkerTimelineItem>();
      expect(markers, hasLength(1));
      expect(markers.first.summary, 'the summary');
      expect(markers.first.tokensBefore, 512);
      expect(markers.first.running, isFalse);
    });

    test('a live fold anchors its marker inline', () async {
      await begin(session, message: 'q');
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 512))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('folded'),
          ),
        );
      await pump();
      // The runtime publishes the folded transcript mid-turn: the summary
      // checkpoint sits between the retained turn and the resumed answer, so
      // the locked marker anchors at its fold boundary rather than the tail.
      events.add(
        AgentUpdated(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('q'), summaryTE('folded'), asstTE('a')]),
        ),
      );
      await pump();

      final items = session.state.timelineItems;
      final markerAt = items.indexWhere(
        (i) => i is CompactionMarkerTimelineItem,
      );
      final answerAt = items.indexWhere(
        (i) => i is MessageTimelineItem && i.role == Role.assistant,
      );
      expect(markerAt, isNonNegative);
      expect(answerAt, greaterThan(markerAt));
      final marker = items.whereType<CompactionMarkerTimelineItem>().single;
      expect(marker.running, isFalse);
      expect(marker.summary, 'folded');
      expect(marker.tokensBefore, 512);
    });

    test('each compaction keeps its own pre-fold token count', () async {
      await begin(session, message: 'q');
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 3600))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('first'),
          ),
        )
        ..add(compactionStarted(tokensBefore: 1500))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('second'),
          ),
        );
      await pump();
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([
            userTE('q'),
            summaryTE('first'),
            asstTE('a'),
            summaryTE('second'),
          ]),
        ),
      );
      await pump();

      final markers = session.state.timelineItems
          .whereType<CompactionMarkerTimelineItem>()
          .toList();
      expect(markers.map((m) => m.summary), ['first', 'second']);
      expect(markers.map((m) => m.tokensBefore), [3600, 1500]);
    });

    test('a compaction whose checkpoint folds away still persists', () async {
      await begin(session, message: 'q');
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 900))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('folded'),
          ),
        );
      await pump();
      // The final transcript carries no surviving summary checkpoint.
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('q'), asstTE('a')]),
        ),
      );
      await pump();

      final marker = session.state.timelineItems
          .whereType<CompactionMarkerTimelineItem>()
          .single;
      expect(marker.summary, 'folded');
      expect(marker.tokensBefore, 900);
    });

    test('cancel before adoption drops the un-adopted fold', () async {
      await begin(session, message: 'q');
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 700))
        ..add(
          AgentCompactionCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            outcome: compaction('unadopted'),
          ),
        );
      await pump();

      // A fold not adopted by the runtime must not leave a marker.
      session.cancel();
      await pump();

      expect(
        session.timelineItems.whereType<CompactionMarkerTimelineItem>(),
        isEmpty,
      );
    });

    test('loadTranscript on a live session clears turn state', () async {
      await begin(session, message: 'q');
      events.add(started(transcript: handedToRun));
      await pump();
      events.add(
        AgentFailed(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          reason: AgentRunFailureReason.loopFailed,
          message: 'boom',
        ),
      );
      await pump();
      expect((session.state as ConversationIdle).failure, isNotNull);

      session.loadJournal(
        journal(),
        MockPendingToolCalls(),
      );

      expect((session.state as ConversationIdle).failure, isNull);
    });

    test('completing the turn commits messages and idles', () async {
      await begin(session, message: 'question');
      events
        ..add(started(transcript: handedToRun))
        ..add(text('answer'));
      await pump();
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('question'), asstTE('answer')]),
        ),
      );
      await pump();

      expect(session.state, isA<ConversationIdle>());
      expect(session.conversationPhase, ConversationPhase.idle);
      final user = rows(session).firstWhere((m) => m.role == Role.user);
      final assistant = rows(
        session,
      ).firstWhere((m) => m.role == Role.assistant);
      expect(user.text, 'question');
      expect(assistant.text, 'answer');
      // Once for the message that opened the turn, once for what it produced.
      verify(() => store.save(any())).called(2);
    });

    test('a failed turn surfaces a typed failure and idles', () async {
      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();
      events.add(
        AgentFailed(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          reason: AgentRunFailureReason.loopFailed,
          message: 'boom',
        ),
      );
      await pump();

      final state = session.state as ConversationIdle;
      expect(state.failure?.reason, AgentRunFailureReason.loopFailed);
      expect(state.failure?.message, 'boom');
    });

    test('a failed turn commits line-split blocks', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('one\ntwo'));
      await pump();
      events.add(
        AgentFailed(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          reason: AgentRunFailureReason.loopFailed,
          message: 'boom',
        ),
      );
      await pump();

      final blocks = committedAssistant(
        session,
      ).blocks.whereType<TranscriptParagraphBlock>().toList();
      expect(blocks.map((b) => b.text), ['one\n', 'two']);
    });

    test('an unsolicited cancel commits the partial turn', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('partial'));
      await pump();
      events.add(
        AgentCancelled(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('hello'), asstTE('partial')]),
        ),
      );
      await pump();

      expect(session.state, isA<ConversationIdle>());
      expect(
        rows(session).where((m) => m.role == Role.assistant).single.text,
        'partial',
      );
    });

    test('events after the turn settles are ignored', () async {
      await begin(session);
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([userTE('hello'), asstTE('done')]),
        ),
      );
      await pump();
      final committed = session.timelineItems.length;

      events.add(text('ghost'));
      await pump();

      expect(session.timelineItems, hasLength(committed));
    });
  });

  group('live reasoning snippet + prefill', () {
    late AgentSession session;

    setUp(() => session = live());
    tearDown(() => session.dispose());

    test('surfaces the latest reasoning block as a one-line snippet', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('thinking about cows'));
      await pump();

      final state = session.state;
      expect(state, isA<TurnInProgress>());
      expect((state as TurnInProgress).reasoningSnippet, 'thinking about cows');
    });

    test('collapses runs of whitespace in the snippet', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('lots   of\t\tspace'));
      await pump();

      expect(
        (session.state as TurnInProgress).reasoningSnippet,
        'lots of space',
      );
    });

    test('elides an overlong reasoning snippet', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('x' * 200));
      await pump();

      final snippet = (session.state as TurnInProgress).reasoningSnippet!;
      expect(snippet.length, 121);
      expect(snippet.codeUnitAt(snippet.length - 1), 0x2026);
    });

    test('has no snippet before any reasoning streams', () async {
      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();

      expect((session.state as TurnInProgress).reasoningSnippet, isNull);
    });

    test(
      'surfaces prefill progress on the live pending-response row',
      () async {
        await begin(session);
        events.add(prefill(completed: 30, total: 120));
        await pump();

        expect(_prefillFraction(session), closeTo(0.25, 1e-9));
      },
    );

    test('clears the prefill fraction once the prompt is caught up', () async {
      await begin(session);
      events
        ..add(prefill(completed: 60, total: 120))
        ..add(prefill(completed: 120, total: 120));
      await pump();

      expect(_prefillFraction(session), isNull);
    });

    test('ignores an empty prefill total', () async {
      await begin(session);
      events.add(prefill(completed: 0, total: 0));
      await pump();

      expect(_prefillFraction(session), isNull);
    });

    test('drops the prefill bar the moment the model streams', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(prefill(completed: 30, total: 120))
        ..add(text('hi'));
      await pump();

      // Prefill and streaming are mutually exclusive: the first token means
      // reprocessing is done, so the bar clears even without a terminal
      // full-prefill signal.
      expect(_prefillFraction(session), isNull);
    });

    test('a streaming summary clears the compaction prefill bar', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(compactionStarted(tokensBefore: 640))
        ..add(prefill(completed: 30, total: 120))
        ..add(
          AgentSummaryDelta(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            text: 'rolling',
          ),
        );
      await pump();

      final marker = session.state.timelineItems
          .whereType<CompactionMarkerTimelineItem>()
          .single;
      expect(marker.running, isTrue);
      expect(marker.summary, 'rolling');
      expect(marker.prefillFraction, isNull);
    });

    test('does not re-emit when the prefill fraction is unchanged', () async {
      await begin(session);
      final emissions = <ConversationState>[];
      final sub = session.stream.listen(emissions.add);

      events
        ..add(prefill(completed: 30, total: 120))
        ..add(prefill(completed: 30, total: 120));
      await pump();

      expect(emissions, hasLength(1));
      await sub.cancel();
    });
  });

  // The regression this redesign exists to kill: turn N+1 must seed the agent
  // with turn N's *authoritative* entries unchanged, not a reconstruction, or
  // the prefix diverges near position 0 and the whole KV cache is thrown away.
  group('prefix-cache stability', () {
    test('turn two reuses turn one committed entries verbatim', () async {
      final session = live();
      addTearDown(session.dispose);
      final t1Asst = asstTE('a1');

      await begin(session, message: 'q1');
      final t1User = handedToRun!.entries.single;
      events.add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: ts([t1User, t1Asst]),
        ),
      );
      await pump();

      await begin(session, message: 'q2');

      final sent = verify(
        () => agent.run(
          captureAny(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).captured.cast<Transcript>();

      expect(sent, hasLength(2));
      final turnTwo = sent[1];
      expect(turnTwo.entries, hasLength(3));
      expect(turnTwo.entries[0], t1User);
      expect(turnTwo.entries[1], t1Asst);
      expect(turnTwo.entries[2].role, Role.user);
      expect(
        (turnTwo.entries[2].blocks.single as TranscriptParagraphBlock).text,
        'q2',
      );
    });
  });

  group('cancel', () {
    late AgentSession session;

    setUp(() => session = live());
    tearDown(() => session.dispose());

    test('cancels the active turn and idles immediately', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('half'));
      await pump();

      session.cancel();

      verify(() => agent.cancel()).called(1);
      expect(session.state, isA<ConversationIdle>());
      expect(session.conversationPhase, ConversationPhase.idle);
    });

    test('stops the tool work the turn had running', () async {
      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();

      session.cancel();

      verify(toolOrchestrator.abortTurn).called(1);
    });

    test('leaves tool work alone when the turn completes', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: agentHandle,
            transcript: emptyTranscript(),
          ),
        );
      await pump();

      verifyNever(toolOrchestrator.abortTurn);
    });

    test('a later AgentCancelled does not double-commit', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('half'));
      await pump();
      session.cancel();
      final committed = session.timelineItems.length;

      events.add(
        AgentCancelled(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          transcript: emptyTranscript(),
        ),
      );
      await pump();

      expect(session.timelineItems, hasLength(committed));
    });

    test('is a no-op when no turn is active', () {
      session.cancel();
      verifyNever(() => agent.cancel());
    });

    test('does not commit a tool-failure notice when cancelling', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(
          resultApplied(
            const ToolCallFailed(
              callId: 'tc1',
              toolName: 'search',
              message: 'nope',
            ),
          ),
        );
      await pump();

      session.cancel();

      // A tool failure is not turned into a committed notice.
      expect(session.timelineItems.whereType<NoticeTimelineItem>(), isEmpty);
    });

    test('commits line-split paragraph blocks with the mirror stat', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('line one\nline '))
        ..add(text('two'));
      await pump();

      session.cancel();

      final blocks = committedAssistant(
        session,
      ).blocks.whereType<TranscriptParagraphBlock>().toList();
      expect(blocks.map((b) => b.text), ['line one\n', 'line two']);
      for (final block in blocks) {
        expect(block.stat?.startedAt, DateTime.utc(2025));
        expect(block.stat?.endedAt, DateTime.utc(2025));
        expect(block.stat?.tokenCount, isNull);
      }
    });

    test('commits line-split reasoning blocks with the mirror stat', () async {
      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(reasoning('think a\nthink b'));
      await pump();

      session.cancel();

      final blocks = committedAssistant(
        session,
      ).blocks.whereType<TranscriptReasoningBlock>().toList();
      expect(blocks.map((b) => b.text), ['think a\n', 'think b']);
      for (final block in blocks) {
        expect(block.stat?.startedAt, DateTime.utc(2025));
        expect(block.stat?.endedAt, DateTime.utc(2025));
        expect(block.stat?.tokenCount, isNull);
      }
    });

    Future<void> emitToolCall(String id) async {
      events.add(
        AgentToolCallEmitted(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          entryId: TranscriptEntryId.v7(),
          blockId: TranscriptBlockId.v7(),
          toolCall: ToolCallDefault(
            id: id,
            name: 'search',
            arguments: const {},
          ),
        ),
      );
      await pump();
    }

    test(
      'pairs a tool call left in flight with an interrupted result',
      () async {
        await begin(session);
        events.add(started(transcript: handedToRun));
        await pump();
        await emitToolCall('tc1');

        session.cancel();
        await pump();

        final blocks = session.transcript.transcript.entries
            .expand((entry) => entry.blocks)
            .toList();
        final callIds = {
          for (final b in blocks)
            if (b is TranscriptToolCallBlock) b.toolCall.id,
        };
        final resultsById = {
          for (final b in blocks)
            if (b is TranscriptToolCallResponseBlock)
              b.response.callId: b.response,
        };
        expect(callIds, {'tc1'});
        expect(
          resultsById.keys,
          containsAll(callIds),
          reason: 'every committed tool_use must be answered by a tool_result',
        );
        expect(resultsById['tc1'], isA<ToolCallCanceled>());
      },
    );

    test('feeds the next turn a well-formed transcript', () async {
      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();
      await emitToolCall('tc1');

      session.cancel();
      await pump();

      await begin(session, message: 'again');

      final transcript =
          verify(
                () => agent.run(
                  captureAny(),
                  config: any(named: 'config'),
                  goal: any(named: 'goal'),
                ),
              ).captured.last
              as Transcript;
      final blocks = transcript.entries.expand((entry) => entry.blocks);
      final callIds = {
        for (final b in blocks)
          if (b is TranscriptToolCallBlock) b.toolCall.id,
      };
      final resultIds = {
        for (final b in transcript.entries.expand((entry) => entry.blocks))
          if (b is TranscriptToolCallResponseBlock) b.response.callId,
      };
      expect(resultIds, containsAll(callIds));
    });

    test('the next turn waits for cancellation to settle', () async {
      final gate = Completer<CancelResult>();
      when(() => agent.cancel()).thenAnswer((_) => gate.future);

      await begin(session);
      events
        ..add(started(transcript: handedToRun))
        ..add(text('half'));
      await pump();

      session.cancel();
      await pump();
      // First turn's run is the only one so far; drain that expectation.
      verify(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).called(1);

      // A new turn is requested while the cancellation is still in flight.
      final next = begin(session, message: 'again');
      await pump();
      verifyNever(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      );

      gate.complete(const CancelAccepted());
      await next;
      verify(
        () => agent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).called(1);
    });
  });

  group('model status + change', () {
    late AgentSession session;

    setUp(() => session = live());
    tearDown(() => session.dispose());

    test('setLiveModelStatus projects a live status row, no persist', () {
      session.setLiveModelStatus(modelSnapshot());

      final state = session.state as ConversationIdle;
      expect(
        state.timelineItems.whereType<ModelCardTimelineItem>(),
        hasLength(1),
      );
      verifyNever(() => store.save(any()));
    });

    test('setLiveModelStatus(null) clears the live status row', () {
      session
        ..setLiveModelStatus(modelSnapshot())
        ..setLiveModelStatus(null);

      expect(
        session.timelineItems.whereType<ModelCardTimelineItem>(),
        isEmpty,
      );
    });

    test(
      'recordModelChange persists a model card and clears live status',
      () async {
        session
          ..setLiveModelStatus(modelSnapshot())
          ..recordModelChange(modelSnapshot(phase: ModelCardPhase.ready));
        await pump();

        expect(
          session.timelineItems.whereType<ModelCardTimelineItem>(),
          hasLength(1),
        );
        verify(() => store.save(any())).called(1);
      },
    );

    test('recordModelChange replaces a card already at the tail', () async {
      session
        ..recordModelChange(modelSnapshot(phase: ModelCardPhase.ready))
        ..recordModelChange(modelSnapshot(phase: ModelCardPhase.ready));
      await pump();

      expect(
        session.transcript.entries.whereType<ModelChangeEntry>(),
        hasLength(1),
      );
      // Back-to-back changes settle into the one write that records them.
      verify(() => store.save(any())).called(1);
    });
  });

  group('surviving the end of a session', () {
    test(
      'the message that opens a turn is saved before the agent runs',
      () async {
        final session = live();
        addTearDown(session.dispose);

        await begin(session, message: 'will it survive');
        await pump();

        final saved =
            verify(() => store.save(captureAny())).captured.first
                as AgentSessionData;
        expect(
          saved.entries
              .whereType<MessageEntry>()
              .single
              .entry
              .blocks
              .whereType<TranscriptParagraphBlock>()
              .single
              .text,
          'will it survive',
        );
      },
    );

    test(
      'the opening message shows in the timeline while the turn runs',
      () async {
        final session = live();
        addTearDown(session.dispose);

        await begin(session, message: 'asked');

        expect(session.conversationPhase, ConversationPhase.turnInFlight);
        expect(rows(session).single.text, 'asked');
      },
    );

    test('disposing mid-turn commits what the turn produced', () async {
      final session = live();
      await begin(session, message: 'asked');
      events
        ..add(started(transcript: handedToRun))
        ..add(text('half an ans'));
      await pump();

      await session.dispose();

      final saved =
          verify(() => store.save(captureAny())).captured.last
              as AgentSessionData;
      final texts = saved.entries.whereType<MessageEntry>().map(
        (entry) => entry.entry.blocks
            .whereType<TranscriptParagraphBlock>()
            .map((block) => block.text)
            .join(),
      );
      expect(texts, ['asked', 'half an ans']);
    });

    test('disposing mid-turn stops the agent and the tools', () async {
      final session = live();
      await begin(session);
      events.add(started(transcript: handedToRun));
      await pump();

      await session.dispose();

      verify(agent.cancel).called(1);
      verify(toolOrchestrator.abortTurn).called(1);
    });

    test('dispose does not complete until the history is written', () async {
      final written = Completer<void>();
      var landed = false;
      when(() => store.save(any())).thenAnswer((_) async {
        await written.future;
        landed = true;
      });

      final session = live();
      await begin(session, message: 'asked');

      final disposed = session.dispose().then((_) => expect(landed, isTrue));
      written.complete();
      await disposed;
    });
  });

  test('a turn cut short by a quit is on disk to be loaded again', () async {
    // The whole chain for real: journal, store, filesystem. What the user
    // asked and what the model had said by then both survive.
    final fileSystem = MemoryFileSystem.test();
    final realStore = ConversationStore(
      conversationsDir: '/conversations',
      fileSystem: fileSystem,
    );
    final session = AgentSession.live(
      id: primaryAgentSessionId,
      agent: agent,
      options: const TurnOptions.baseline('baseline prompt'),
      compactionRatio: testCompactionRatio,
      maxOutputChars: testMaxToolCallCharacters,
      journal: AgentJournal.fromSessionData(data(const []), store: realStore),
      contextSize: 2048,
      compactionPromptContentBuilder: const FixedCompactionPromptContentBuilder(
        testCompactionPromptContent,
      ),
      tools: toolOrchestrator,
      toolDefinitions: toolDefinitions,
    );

    await begin(session, message: 'what happened here');
    events
      ..add(started(transcript: handedToRun))
      ..add(text('It looks like'));
    await pump();

    // The app going away takes the session with it.
    await session.dispose();

    final reloaded = await realStore.load(
      'c-1',
      agentId: primaryAgentSessionId,
    );
    final texts = reloaded!.entries.whereType<MessageEntry>().map(
      (entry) => entry.entry.blocks
          .whereType<TranscriptParagraphBlock>()
          .map((block) => block.text)
          .join(),
    );
    expect(texts, ['what happened here', 'It looks like']);
  });

  group('persistence + dispose', () {
    test(
      'a failing store save is caught and the session keeps running',
      () async {
        when(() => store.save(any())).thenThrow(StateError('disk full'));

        final session = live();
        addTearDown(session.dispose);
        session.addNotice('x');
        await pump();

        verify(() => store.save(any())).called(1);
        expect(session.state, isA<ConversationIdle>());
      },
    );

    test('dispose is idempotent', () async {
      final session = live();
      await session.dispose();
      await session.dispose();
    });
  });
}

/// The prefill fraction currently hosted on a live row, or null if none.
double? _prefillFraction(AgentSession session) => session.state.timelineItems
    .whereType<Prefillable>()
    .map((row) => row.prefillFraction)
    .firstWhere((fraction) => fraction != null, orElse: () => null);
