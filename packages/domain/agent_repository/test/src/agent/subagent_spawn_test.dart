import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

import 'agent_test_support.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockConversationStore store;
  late MockProvider provider;
  late MockAgent primary;
  late StreamController<AgentRuntimeEvent> events;
  late AgentRepository repository;

  setUp(() {
    store = MockConversationStore();
    when(() => store.save(any())).thenAnswer((_) async {});
    events = StreamController<AgentRuntimeEvent>.broadcast();
    provider = MockProvider();
    primary = MockAgent();
    when(() => provider.pool).thenAnswer((_) => const Stream.empty());
    when(() => provider.spend).thenAnswer((_) => const Stream.empty());
    when(() => primary.handle).thenReturn(agentHandle);
    when(() => primary.kind).thenReturn(AgentKind.primary);
    when(() => primary.events).thenAnswer((_) => events.stream);
    when(
      () => primary.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(
      () => primary.cancel(),
    ).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startPrimary(config: any(named: 'config')),
    ).thenAnswer((_) async => StartPrimaryStarted(primary));
    repository = AgentRepository(
      workingDirectory: '/work',
      configuration: testAgentConfiguration,
      toolDefinitions: offering(),
      subagentToolDefinitions: offering(),
      conversationStore: store,
      subagentSystemPromptBuilder: const FixedSubagentSystemPromptBuilder(
        'subagent prompt',
      ),
      compactionPromptContentBuilder: const FixedCompactionPromptContentBuilder(
        testCompactionPromptContent,
      ),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await events.close();
  });

  test('rejects a subagent request until a provider is bound', () async {
    final job = await _spawn(repository);

    switch (await job.settled) {
      case final JobFailed failure:
        expect(failure.message, contains('No model is loaded'));
      case JobSucceeded():
        fail('Expected a failed job.');
    }
  });

  test('maps a provider reservation rejection into a failed job', () async {
    await repository.bindProvider(provider, contextSize: 1024);
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer(
      (_) async => const StartSubagentRejected(
        reason: AgentRuntimeRejectionReason.agentCapacityReached,
      ),
    );

    final job = await _spawn(repository);

    switch (await job.settled) {
      case final JobFailed failure:
        expect(failure.message, contains('capacity'));
      case JobSucceeded():
        fail('Expected a failed job.');
    }
  });

  test(
    'explains compaction, context, and generic reservation rejections',
    () async {
      await repository.bindProvider(provider, contextSize: 1024);
      final cases = [
        (AgentRuntimeRejectionReason.primaryCompactionPending, 'compacting'),
        (AgentRuntimeRejectionReason.insufficientContextSpace, 'free context'),
        (AgentRuntimeRejectionReason.busy, 'busy'),
      ];
      for (final entry in cases) {
        when(
          () => provider.startSubagent(
            config: any(named: 'config'),
            label: any(named: 'label'),
          ),
        ).thenAnswer((_) async => StartSubagentRejected(reason: entry.$1));
        final outcome = await (await _spawn(repository)).settled;
        expect(
          outcome,
          isA<JobFailed>().having(
            (failure) => failure.message,
            'message',
            contains(entry.$2),
          ),
        );
      }
    },
  );

  test('holds a settled report for a subagent mid-turn', () async {
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    addTearDown(subagentEvents.close);
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    await _spawn(repository);
    await pump();
    subagentEvents.add(started(agent: subagentHandle));
    await pump();

    repository.deliverReport(
      const JobReport(
        conversationId: 'conversation',
        agentId: 'call',
        callId: 'bash-1',
        toolName: 'bash',
        arguments: {},
        outcome: JobSucceeded('done'),
        outstanding: 0,
      ),
    );
    await pump();

    expect(repository.subagents.single.status, SubagentStatus.running);
    verify(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).called(1);
  });

  test(
    'runs a detached subagent and settles its job with a pointer',
    () async {
      final subagent = MockAgent();
      final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
      Transcript? handedToSubagent;
      when(() => subagent.handle).thenReturn(subagentHandle);
      when(() => subagent.kind).thenReturn(AgentKind.subagent);
      when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
      when(
        () => subagent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).thenAnswer((invocation) async {
        handedToSubagent = invocation.positionalArguments.first as Transcript;
        return const RunAccepted();
      });
      when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
      when(
        () => provider.startSubagent(
          config: any(named: 'config'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async => StartSubagentStarted(subagent));
      when(
        () => provider.disposeAgent(subagent),
      ).thenAnswer((_) async => const DisposeAgentDisposed());

      await repository.bindProvider(provider, contextSize: 1024);
      final job = await _spawn(repository, label: 'Investigation');
      await pump();
      subagentEvents
        ..add(started(agent: subagentHandle))
        ..add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: subagentHandle,
            transcript: ts([
              ...handedToSubagent!.entries,
              asstTE('Confidential findings.'),
            ]),
          ),
        );

      final handoff = await job.inBackground;
      expect(handoff, contains('Dispatched subagent'));
      expect(repository.subagents.single.id, 'call');
      expect(
        await job.settled,
        isA<JobSucceeded>().having(
          (outcome) => outcome.content,
          'content',
          allOf(
            'Subagent call "Investigation" finished: 5 tokens.',
            isNot(contains('Confidential findings.')),
          ),
        ),
      );
      expect(job.outcome, isA<JobSucceeded>());
      expect(repository.subagents.single.status, SubagentStatus.completed);
      verify(() => provider.disposeAgent(subagent)).called(1);

      final saved = verify(
        () => store.save(captureAny()),
      ).captured.cast<AgentSessionData>();
      final filed = saved
          .where((data) => data.agentId == 'call')
          .map((data) => data.conversationId);
      expect(filed, isNotEmpty);
      expect(filed, everyElement(repository.primary.transcript.conversationId));

      await repository.clearSettledSubagents();
      expect(repository.subagents, isEmpty);
      await subagentEvents.close();
    },
  );

  test('labels a subagent job from the subagent offering', () async {
    // A subagent is offered a different set of tools than the primary, so the
    // label for work it backgrounds has to come from that set.
    const subagentBash = ToolDefinition(
      name: 'bash',
      description: 'Runs.',
      parameters: {},
      onProgress: r'Subagent running ${command}',
      onSuccess: r'Subagent ran ${command}',
      onError: '',
    );
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    addTearDown(subagentEvents.close);
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));

    final scoped = AgentRepository(
      workingDirectory: '/work',
      configuration: testAgentConfiguration,
      toolDefinitions: offering(),
      subagentToolDefinitions: offering([subagentBash]),
      conversationStore: store,
      subagentSystemPromptBuilder: const FixedSubagentSystemPromptBuilder(
        'subagent prompt',
      ),
      compactionPromptContentBuilder: const FixedCompactionPromptContentBuilder(
        testCompactionPromptContent,
      ),
    );
    addTearDown(scoped.dispose);
    await scoped.bindProvider(provider, contextSize: 1024);
    await _spawn(scoped);
    await pump();

    scoped.noteBackgrounded(
      const JobBackgrounded(
        conversationId: 'conversation',
        agentId: 'call',
        callId: 'inner-call',
        toolName: 'bash',
        arguments: {'command': 'sleep 30'},
      ),
    );

    final row = scoped
        .sessionFor('call')!
        .timelineItems
        .whereType<BackgroundJobTimelineItem>()
        .single;
    expect(row.job.labelTemplate, r'Subagent running ${command}');
  });

  test('stops a detached subagent through its job handle', () async {
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    final job = await _spawn(repository);
    await pump();
    subagentEvents.add(started(agent: subagentHandle));
    job.stop();
    subagentEvents.add(
      AgentCompleted(
        timestamp: DateTime.utc(2025),
        agent: subagentHandle,
        transcript: emptyTranscript(),
      ),
    );

    expect(await job.settled, isA<JobCanceled>());
    expect(repository.subagents.single.status, SubagentStatus.failed);
    await repository.bindProvider(null);
    expect(repository.subagents, isEmpty);
    await subagentEvents.close();
  });

  test('reads a settled subagent from the roster, not from disk', () async {
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    Transcript? handedToSubagent;
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((invocation) async {
      handedToSubagent = invocation.positionalArguments.first as Transcript;
      return const RunAccepted();
    });
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    final job = await _spawn(repository);
    await pump();
    subagentEvents
      ..add(started(agent: subagentHandle))
      ..add(
        AgentCompleted(
          timestamp: DateTime.utc(2025),
          agent: subagentHandle,
          transcript: ts([
            ...handedToSubagent!.entries,
            asstTE('What it found.'),
          ]),
        ),
      );
    await job.settled;
    clearInteractions(store);

    final read = await repository.readSubagent(
      id: 'call',
      wholeTranscript: false,
      maxChars: testMaxToolCallCharacters,
    );

    expect(
      read,
      isA<SubagentReadPage>().having(
        (page) => page.text,
        'text',
        contains('What it found.'),
      ),
    );
    verifyNever(() => store.load(any(), agentId: any(named: 'agentId')));

    await repository.clearSettledSubagents();
    await subagentEvents.close();
  });

  test(
    'settles a reportless detached subagent with an explicit outcome',
    () async {
      final subagent = MockAgent();
      final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
      when(() => subagent.handle).thenReturn(subagentHandle);
      when(() => subagent.kind).thenReturn(AgentKind.subagent);
      when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
      when(
        () => subagent.run(
          any(),
          config: any(named: 'config'),
          goal: any(named: 'goal'),
        ),
      ).thenAnswer((_) async => const RunAccepted());
      when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
      when(
        () => provider.startSubagent(
          config: any(named: 'config'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async => StartSubagentStarted(subagent));
      when(
        () => provider.disposeAgent(subagent),
      ).thenAnswer((_) async => const DisposeAgentDisposed());

      await repository.bindProvider(provider, contextSize: 1024);
      final job = await _spawn(repository);
      await pump();
      subagentEvents
        ..add(started(agent: subagentHandle))
        ..add(
          AgentCompleted(
            timestamp: DateTime.utc(2025),
            agent: subagentHandle,
            transcript: emptyTranscript(),
          ),
        );

      expect(
        await job.settled,
        isA<JobSucceeded>().having(
          (outcome) => outcome.content,
          'content',
          'Subagent call "Subagent" finished: no output.',
        ),
      );
      await subagentEvents.close();
    },
  );

  test('reports a detached subagent turn rejection to its caller', () async {
    final subagent = MockAgent();
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => const Stream.empty());
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer(
      (_) async => const RunRejected(reason: AgentRuntimeRejectionReason.busy),
    );
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    final job = await _spawn(repository);

    expect(
      await job.settled,
      isA<JobFailed>().having(
        (outcome) => outcome.message,
        'message',
        contains('could not start'),
      ),
    );
  });

  test('reports a detached subagent runtime failure to its caller', () async {
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    final job = await _spawn(repository);
    await pump();
    subagentEvents
      ..add(started(agent: subagentHandle))
      ..add(
        AgentFailed(
          timestamp: DateTime.utc(2025),
          agent: subagentHandle,
          reason: AgentRunFailureReason.loopFailed,
          message: 'runtime stopped',
        ),
      );

    expect(
      await job.settled,
      isA<JobFailed>().having(
        (outcome) => outcome.message,
        'message',
        contains('runtime stopped'),
      ),
    );
    await subagentEvents.close();
  });
}

Future<Job> _spawn(
  AgentRepository repository, {
  String prompt = 'Investigate',
  String label = 'Subagent',
}) => repository.startSubagent(
  callId: 'call',
  prompt: prompt,
  label: label,
);
