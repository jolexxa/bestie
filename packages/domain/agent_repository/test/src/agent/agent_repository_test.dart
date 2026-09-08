import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

import 'agent_test_support.dart';

void main() {
  setUpAll(registerFallbacks);

  late StreamController<AgentRuntimeEvent> events;
  late StreamController<ContextPoolSnapshot> pool;
  late StreamController<double> spend;
  late MockProvider provider;
  late MockAgent agent;
  late ToolDefinitions toolDefinitions;
  late MockConversationStore store;
  late AgentRepository repo;

  setUp(() {
    events = StreamController<AgentRuntimeEvent>.broadcast();
    pool = StreamController<ContextPoolSnapshot>.broadcast();
    spend = StreamController<double>.broadcast();
    provider = MockProvider();
    when(() => provider.pool).thenAnswer((_) => pool.stream);
    when(() => provider.spend).thenAnswer((_) => spend.stream);
    agent = MockAgent();
    when(() => agent.handle).thenReturn(agentHandle);
    when(() => agent.kind).thenReturn(AgentKind.primary);
    when(() => agent.events).thenAnswer((_) => events.stream);
    when(
      () => agent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(() => agent.cancel()).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startPrimary(config: any(named: 'config')),
    ).thenAnswer((_) async => StartPrimaryStarted(agent));

    toolDefinitions = offering();

    store = MockConversationStore();
    when(() => store.save(any())).thenAnswer((_) async {});
    when(() => store.delete(any())).thenAnswer((_) async {});
    when(
      () => store.load(any(), agentId: any(named: 'agentId')),
    ).thenAnswer((_) async => null);

    repo = AgentRepository(
      workingDirectory: '/work',
      configuration: testAgentConfiguration,
      toolDefinitions: toolDefinitions,
      subagentToolDefinitions: toolDefinitions,
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
    await repo.dispose();
    if (!events.isClosed) await events.close();
    if (!pool.isClosed) await pool.close();
  });

  group('construction', () {
    test('starts with a placeholder primary that cannot run turns', () {
      expect(repo.primary.canRunTurns, isFalse);
      expect(repo.primary.timelineItems, isEmpty);
      expect(repo.primary.sessionContextSize, isNull);
      expect(repo.sessionFor(primaryAgentSessionId), same(repo.primary));
    });

    test('starts a conversation in the working directory', () {
      expect(repo.primary.transcript.workingDirectory, '/work');
    });
  });

  group('bindProvider', () {
    test('spawns an agent and swaps in a live session', () async {
      await repo.bindProvider(provider, contextSize: 2048);

      expect(repo.primary.canRunTurns, isTrue);
      expect(repo.primary.sessionContextSize, 2048);
      verify(
        () => provider.startPrimary(config: any(named: 'config')),
      ).called(1);
    });

    test('mints the agent with a create-only baseline config', () async {
      await repo.bindProvider(
        provider,
        contextSize: 2048,
        systemPrompt: 'system prompt',
      );

      final config =
          verify(
                () =>
                    provider.startPrimary(config: captureAny(named: 'config')),
              ).captured.single
              as AgentConfig;
      expect(config.systemPrompt, 'system prompt');
      expect(config.sampling.seed, 0);
      expect(config.reasoningMode, 'auto');
    });

    test('publishes the live session on primaryStream', () async {
      final seen = <AgentSession>[];
      final sub = repo.primaryStream.listen(seen.add);

      await repo.bindProvider(provider, contextSize: 2048);
      await pump();

      expect(seen, isNotEmpty);
      expect(seen.last.canRunTurns, isTrue);
      await sub.cancel();
    });

    test(
      'primaryConversationStream seeds, then follows the session it swaps to',
      () async {
        final seen = <ConversationState>[];
        final sub = repo.primaryConversationStream.listen(seen.add);
        await pump();

        expect(seen.single.conversationPhase, ConversationPhase.idle);

        await repo.bindProvider(provider, contextSize: 2048);
        await pump();

        expect(seen.length, greaterThan(1));
        await sub.cancel();
      },
    );

    test('a rejected start keeps the placeholder', () async {
      when(
        () => provider.startPrimary(config: any(named: 'config')),
      ).thenAnswer(
        (_) async => const StartPrimaryRejected(
          reason: AgentRuntimeRejectionReason.busy,
        ),
      );

      await repo.bindProvider(provider, contextSize: 2048);

      expect(repo.primary.canRunTurns, isFalse);
    });

    test('rebinding the same provider does not re-spawn the agent', () async {
      await repo.bindProvider(provider, contextSize: 2048);
      await repo.bindProvider(provider, contextSize: 2048);

      expect(repo.primary.sessionContextSize, 2048);
      verify(
        () => provider.startPrimary(config: any(named: 'config')),
      ).called(1);
    });

    test('clearing the provider retires to a placeholder', () async {
      await repo.bindProvider(provider, contextSize: 2048);
      expect(repo.primary.canRunTurns, isTrue);

      await repo.bindProvider(null);

      expect(repo.primary.canRunTurns, isFalse);
    });

    test(
      'carries the conversation across the placeholder → live swap',
      () async {
        repo.primary.addNotice('welcome');

        await repo.bindProvider(provider, contextSize: 2048);

        expect(
          repo.primary.timelineItems.whereType<NoticeTimelineItem>(),
          hasLength(1),
        );
      },
    );
  });

  group('conversations', () {
    test('lists what the store has saved', () async {
      final summary = ConversationSummary.fromSessionData(
        data([msgUser('hi')], id: 'c-9'),
      );
      when(() => store.summaries()).thenAnswer((_) async => [summary]);

      expect(await repo.conversations(), [summary]);
    });
  });

  group('load', () {
    test('swaps the saved conversation into the current session', () async {
      when(
        () => store.load('c-1', agentId: primaryAgentSessionId),
      ).thenAnswer((_) async => data([msgUser('old'), msgAsst('prior')]));

      expect(await repo.load('c-1'), isA<ConversationLoaded>());

      expect(repo.primary.transcript.conversationId, 'c-1');
      expect(repo.primary.transcript.workingDirectory, '/elsewhere');
      expect(
        rowsOf(
          repo.primary.timelineItems,
        ).firstWhere((m) => m.role == Role.user).text,
        'old',
      );
    });

    test('reports a missing conversation and keeps the current one', () async {
      repo.primary.addNotice('welcome');
      final before = repo.primary.transcript.conversationId;

      expect(await repo.load('nope'), isA<ConversationNotFound>());

      expect(repo.primary.transcript.conversationId, before);
      expect(repo.primary.timelineItems, hasLength(1));
    });
  });

  group('clear', () {
    test('resets the current session to a fresh conversation', () {
      repo.primary.addNotice('welcome');
      expect(
        repo.primary.timelineItems.whereType<NoticeTimelineItem>(),
        hasLength(1),
      );

      repo.clear();

      expect(repo.primary.timelineItems, isEmpty);
    });
  });

  group('rewindTo', () {
    late MessageEntry first;
    late MessageEntry second;

    setUp(() async {
      first = msgUser('first');
      second = msgUser('second', responseId: 2);
      when(
        () => store.load('c-1', agentId: primaryAgentSessionId),
      ).thenAnswer(
        (_) async => data([first, msgAsst('reply'), second, msgAsst('more')]),
      );
      await repo.load('c-1');
      clearInteractions(store);
    });

    test('cuts the history before the message and hands its text back', () {
      final result = repo.rewindTo(second.id);

      expect(
        result,
        isA<Rewound>().having((r) => r.message, 'message', 'second'),
      );
      expect(rowsOf(repo.primary.timelineItems).map((row) => row.text), [
        'first',
        'reply',
      ]);
      expect(repo.primary.transcript.conversationId, 'c-1');
    });

    test('saves the truncated conversation', () async {
      repo.rewindTo(second.id);
      await pump();

      final saved =
          verify(() => store.save(captureAny())).captured.single
              as AgentSessionData;
      expect(saved.conversationId, 'c-1');
      expect(saved.entries, hasLength(2));
    });

    test('removes the conversation when nothing is left', () async {
      repo.rewindTo(first.id);
      await pump();

      expect(repo.primary.timelineItems, isEmpty);
      verify(() => store.delete('c-1')).called(1);
      verifyNever(() => store.save(any()));
    });

    test('survives a failed write', () async {
      when(() => store.save(any())).thenThrow(Exception('disk'));

      repo.rewindTo(second.id);
      await pump();

      expect(rowsOf(repo.primary.timelineItems), hasLength(2));
    });

    test('survives a delete that fails', () async {
      when(() => store.delete(any())).thenThrow(Exception('read only'));

      repo.rewindTo(first.id);
      await pump();

      expect(repo.primary.timelineItems, isEmpty);
    });

    test('refuses an assistant message and keeps the history', () {
      final reply = repo.primary.transcript.entries[1];

      expect(repo.rewindTo(reply.id), isA<RewindTargetNotFound>());

      expect(rowsOf(repo.primary.timelineItems), hasLength(4));
      verifyNever(() => store.save(any()));
    });

    test('refuses an unknown id', () {
      expect(repo.rewindTo('nope'), isA<RewindTargetNotFound>());
    });
  });

  test(
    'exposes empty roster, pool stream, and null stats before a pool snapshot',
    () {
      expect(repo.subagents, isEmpty);
      expect(repo.subagentsStream, isA<Stream<List<SubagentSummary>>>());
      expect(repo.poolStream, isA<Stream<ContextPoolSnapshot>>());
      expect(repo.toolRequests, isA<Stream<ToolCallRequest>>());
      expect(repo.statsFor(primaryAgentSessionId), isNull);
    },
  );

  test('delivers a settled report to the live primary', () async {
    await repo.bindProvider(provider, contextSize: 2048);
    clearInteractions(agent);

    repo.deliverReport(
      const JobReport(
        conversationId: 'conversation',
        agentId: primaryAgentSessionId,
        callId: 'call',
        toolName: 'bash',
        arguments: {},
        outcome: JobSucceeded('done'),
        outstanding: 0,
      ),
    );
    await pump();

    verify(
      () => agent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).called(1);
  });

  test('exposes the configuration it was last handed', () {
    const revised = AgentConfiguration(
      compactionRatio: 0.5,
      maxToolCallCharacters: 123,
    );

    repo.configuration = revised;

    expect(repo.configuration, revised);
  });

  test('ignores reports and stop requests for unknown subagents', () {
    repo
      ..deliverReport(
        const JobReport(
          conversationId: 'conversation',
          agentId: 'missing',
          callId: 'call',
          toolName: 'subagent',
          arguments: {},
          outcome: JobSucceeded('done'),
          outstanding: 0,
        ),
      )
      ..stopSubagent('missing');

    expect(repo.subagents, isEmpty);
  });

  group('noteBackgrounded', () {
    const bashDefinition = ToolDefinition(
      name: 'bash',
      description: 'Runs.',
      parameters: {},
      onProgress: r'Running ${command}',
      onSuccess: r'Ran ${command}',
      onError: r'Failed to run ${command}',
    );

    /// A repository offering [definitions], since the shared one offers
    /// nothing and the stamped label comes from the offering.
    AgentRepository repositoryOffering(ToolDefinitions definitions) =>
        AgentRepository(
          workingDirectory: '/work',
          configuration: testAgentConfiguration,
          toolDefinitions: definitions,
          subagentToolDefinitions: definitions,
          conversationStore: store,
          subagentSystemPromptBuilder: const FixedSubagentSystemPromptBuilder(
            'subagent prompt',
          ),
          compactionPromptContentBuilder:
              const FixedCompactionPromptContentBuilder(
                testCompactionPromptContent,
              ),
        );

    JobBackgrounded job({String agentId = primaryAgentSessionId}) =>
        JobBackgrounded(
          conversationId: 'conversation',
          agentId: agentId,
          callId: 'call-1',
          toolName: 'bash',
          arguments: const {'command': 'sleep 30'},
        );

    BackgroundJobTimelineItem? rowOn(AgentSession session) => session
        .timelineItems
        .whereType<BackgroundJobTimelineItem>()
        .singleOrNull;

    test('gives the agent a row stamped with the in-progress label', () {
      final repo = repositoryOffering(offering([bashDefinition]));
      addTearDown(repo.dispose);

      repo.noteBackgrounded(job());

      final row = rowOn(repo.primary)!;
      expect(row.job.callId, 'call-1');
      expect(row.job.labelTemplate, r'Running ${command}');
      expect(row.job.labelArguments, {'command': 'sleep 30'});
      // Still going: nothing has reported yet.
      expect(row.settled, isNull);
    });

    test('forwards every charge the bound provider reports', () async {
      final charges = <double>[];
      repo.spendStream.listen(charges.add);
      await repo.bindProvider(provider);

      spend.add(0.25);
      await pumpEventQueue();

      expect(charges, [0.25]);

      await repo.bindProvider(null);
      spend.add(0.5);
      await pumpEventQueue();

      expect(charges, [0.25]);
    });

    test('keeps the row out of what the model reads', () {
      // The model was already told in the call's own response.
      final repo = repositoryOffering(offering([bashDefinition]));
      addTearDown(repo.dispose);

      repo.noteBackgrounded(job());

      // Persisted, so the row survives a reload — but absent from the prompt.
      expect(repo.primary.transcript.entries, hasLength(1));
      expect(repo.primary.transcript.transcript.entries, isEmpty);
      expect(rowOn(repo.primary), isNotNull);
    });

    test('leaves the label empty when the tool is not offered', () {
      final repo = repositoryOffering(offering());
      addTearDown(repo.dispose);

      repo.noteBackgrounded(job());

      expect(rowOn(repo.primary)!.job.labelTemplate, isEmpty);
    });

    test('ignores a job for an agent that is gone', () {
      final repo = repositoryOffering(offering([bashDefinition]));
      addTearDown(repo.dispose);

      repo.noteBackgrounded(job(agentId: 'missing'));

      expect(rowOn(repo.primary), isNull);
    });
  });

  test('projects primary pool occupancy into context stats', () async {
    await repo.bindProvider(provider, contextSize: 100);
    pool.add(
      const ContextPoolSnapshot(
        contextSize: 100,
        reservedClaims: 7,
        leases: [
          PoolLeaseOccupancy(
            handle: agentHandle,
            residentTokens: 12,
            claimTokens: 0,
          ),
        ],
      ),
    );
    await pump();

    final stats = repo.statsFor(primaryAgentSessionId);
    expect(stats?.budgetTokens, 100);
    expect(stats?.cachedTokens, 19);
  });

  test('does not project stats for an agent absent from the pool', () async {
    await repo.bindProvider(provider, contextSize: 100);
    pool.add(
      const ContextPoolSnapshot(
        contextSize: 100,
        reservedClaims: 0,
        leases: [
          PoolLeaseOccupancy(
            handle: subagentHandle,
            residentTokens: 12,
            claimTokens: 20,
          ),
        ],
      ),
    );
    await pump();

    expect(repo.statsFor(primaryAgentSessionId), isNull);
  });

  test('projects a subagent lease without primary reserved claims', () async {
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
    await repo.bindProvider(provider, contextSize: 100);
    await repo.startSubagent(
      callId: 'call',
      prompt: 'Investigate',
      label: 'Subagent',
    );
    pool.add(
      const ContextPoolSnapshot(
        contextSize: 100,
        reservedClaims: 7,
        leases: [
          PoolLeaseOccupancy(
            handle: subagentHandle,
            residentTokens: 12,
            claimTokens: 40,
          ),
        ],
      ),
    );
    await pump();
    expect(repo.subagents.single.id, 'call');
    expect(repo.statsFor('call')?.cachedTokens, 12);
    expect(repo.sessionFor('call')?.maxOutputChars, 112);
  });

  group('tool output room', () {
    test('starts optimistic before the pool has been read', () {
      expect(repo.primary.maxOutputChars, testMaxToolCallCharacters);
    });

    test('narrows the primary as the pool fills', () async {
      await repo.bindProvider(provider, contextSize: 100);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100,
          reservedClaims: 7,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 12,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();

      expect(repo.primary.maxOutputChars, 324);
    });

    test('caps at the configured ceiling when context is plentiful', () async {
      repo.configuration = const AgentConfiguration(
        compactionRatio: testCompactionRatio,
        maxToolCallCharacters: 900,
      );
      await repo.bindProvider(provider, contextSize: 100000);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100000,
          reservedClaims: 0,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 100,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();

      expect(repo.primary.maxOutputChars, 900);
    });

    test('lowering the ceiling applies without a new pool reading', () async {
      await repo.bindProvider(provider, contextSize: 100000);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100000,
          reservedClaims: 0,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 100,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();
      expect(repo.primary.maxOutputChars, testMaxToolCallCharacters);

      repo.configuration = const AgentConfiguration(
        compactionRatio: testCompactionRatio,
        maxToolCallCharacters: 600,
      );

      expect(repo.primary.maxOutputChars, 600);
    });

    test('a ceiling above the free context does not invent room', () async {
      repo.configuration = const AgentConfiguration(
        compactionRatio: testCompactionRatio,
        maxToolCallCharacters: 32000,
      );
      await repo.bindProvider(provider, contextSize: 100);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100,
          reservedClaims: 0,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 20,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();

      expect(repo.primary.maxOutputChars, 320);
    });

    test('leaves no room once the pool is full', () async {
      await repo.bindProvider(provider, contextSize: 100);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100,
          reservedClaims: 0,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 100,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();

      expect(repo.primary.maxOutputChars, 0);
    });

    test('keeps the last reading for a session the pool omits', () async {
      await repo.bindProvider(provider, contextSize: 100);
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100,
          reservedClaims: 0,
          leases: [
            PoolLeaseOccupancy(
              handle: agentHandle,
              residentTokens: 20,
              claimTokens: 0,
            ),
          ],
        ),
      );
      await pump();
      pool.add(
        const ContextPoolSnapshot(
          contextSize: 100,
          reservedClaims: 0,
          leases: [],
        ),
      );
      await pump();

      expect(repo.primary.maxOutputChars, 320);
    });
  });

  group('surviving a provider swap', () {
    test('parking a live primary commits the turn it had in flight', () async {
      await repo.bindProvider(provider, contextSize: 2048);
      await repo.primary.beginTurn(
        message: 'asked mid-reload',
        options: const TurnOptions.baseline('p'),
      );
      events.add(
        AgentTextDelta(
          timestamp: DateTime.utc(2025),
          agent: agentHandle,
          entryId: TranscriptEntryId.v7(),
          blockId: TranscriptBlockId.v7(),
          text: 'partial answer',
        ),
      );
      await pump();

      // What a reload does: drop the provider before its handle is torn down.
      await repo.bindProvider(null);

      final saved =
          verify(() => store.save(captureAny())).captured.last
              as AgentSessionData;
      final texts = saved.entries.whereType<MessageEntry>().map(
        (entry) => entry.entry.blocks
            .whereType<TranscriptParagraphBlock>()
            .map((block) => block.text)
            .join(),
      );
      expect(texts, ['asked mid-reload', 'partial answer']);
    });

    test('the parked primary carries the committed history forward', () async {
      await repo.bindProvider(provider, contextSize: 2048);
      await repo.primary.beginTurn(
        message: 'asked mid-reload',
        options: const TurnOptions.baseline('p'),
      );
      await pump();

      await repo.bindProvider(null);

      expect(repo.primary.canRunTurns, isFalse);
      expect(
        rowsOf(repo.primary.timelineItems).single.text,
        'asked mid-reload',
      );
    });
  });

  group('dispose', () {
    test('is idempotent', () async {
      await repo.bindProvider(provider, contextSize: 2048);
      await repo.dispose();
      await repo.dispose();
    });
  });
}
