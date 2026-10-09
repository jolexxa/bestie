import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/agent_provider_remote.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers.dart';

final class _MockInferenceClient extends Mock implements InferenceClient {}

final class _MockAgentSessions extends Mock implements AgentSessions {}

const _primaryIdentity = AgentIdentity(
  id: 'primary:1',
  kind: AgentIdentityKind.primary,
);

const _helperIdentity = AgentIdentity(
  id: 'subagent:2',
  kind: AgentIdentityKind.subagent,
);

const _usage = InferenceUsageReported(promptTokens: 40, completionTokens: 20);

const _finished = InferenceCompletionFinished(InferenceStopReason.stop);

const _toolCall = InferenceToolCall(
  id: 'call_a',
  name: 'echo',
  arguments: {'text': 'hi'},
  rawArguments: '{"text":"hi"}',
);

List<InferenceEvent> _textReply(String text) => [
  InferenceTextDelta(text),
  _usage,
  _finished,
];

const List<InferenceEvent> _toolReply = [
  InferenceToolCallEmitted(_toolCall),
  _usage,
  InferenceCompletionFinished(InferenceStopReason.toolCalls),
];

/// An endpoint that opens every session and reports each one, claiming
/// [_claimFor] tokens, whenever the set of open sessions changes.
final class _Harness {
  _Harness({
    int maxAgents = 4,
    int contextWindow = 1000,
    this.reservesSubagentClaims = false,
  }) : _contextWindow = contextWindow {
    registerFallbackValue(const CompletionRequest(model: '', messages: []));
    registerFallbackValue(_primaryIdentity);
    when(client.close).thenAnswer((_) async {});
    when(sessions.dispose).thenAnswer((_) async {});
    when(() => sessions.pool).thenAnswer((_) => reports.stream);
    when(() => sessions.open(any())).thenAnswer((invocation) async {
      final agent = invocation.positionalArguments.single as AgentIdentity;
      openSessions.add(agent);
      reportOpenSessions();
      return AgentSessionOpened(claimedTokens: _claimFor(agent));
    });
    when(() => sessions.close(any())).thenAnswer((invocation) async {
      openSessions.remove(invocation.positionalArguments.single);
      reportOpenSessions();
    });
    provider = RemoteAgentProvider(
      client: client,
      sessions: sessions,
      options: RemoteProviderOptions(
        modelId: 'test/model',
        contextWindow: contextWindow,
        maxAgents: maxAgents,
      ),
    );
    provider.pool.listen(snapshots.add);
  }

  final int _contextWindow;

  /// Whether reports reserve each subagent's claim out of the primary's
  /// share, the way a shared local context does.
  final bool reservesSubagentClaims;
  final client = _MockInferenceClient();
  final sessions = _MockAgentSessions();
  final reports = StreamController<AgentPoolReport>.broadcast();
  final List<AgentIdentity> openSessions = [];
  late final RemoteAgentProvider provider;
  final List<ContextPoolSnapshot> snapshots = [];
  final List<CompletionRequest> requests = [];
  final List<Future<void>?> abortTriggers = [];

  /// Serves the given streams to successive completions, in order.
  void serve(List<Stream<InferenceEvent>> streams) {
    final queue = List.of(streams);
    when(
      () => client.complete(any(), abortTrigger: any(named: 'abortTrigger')),
    ).thenAnswer((invocation) {
      requests.add(invocation.positionalArguments.single as CompletionRequest);
      abortTriggers.add(
        invocation.namedArguments[#abortTrigger] as Future<void>?,
      );
      return queue.removeAt(0);
    });
  }

  int _claimFor(AgentIdentity agent) =>
      agent.kind == AgentIdentityKind.primary ? 0 : _contextWindow;

  void reportOpenSessions() => reports.add(
    AgentPoolReport(
      contextSize: _contextWindow,
      reservedTokens: reservesSubagentClaims
          ? openSessions
                .where((agent) => agent.kind == AgentIdentityKind.subagent)
                .fold(0, (total, agent) => total + _claimFor(agent))
          : 0,
      agents: [
        for (final agent in openSessions)
          AgentPoolEntry(agent: agent, claimedTokens: _claimFor(agent)),
      ],
    ),
  );

  void serveReplies(List<List<InferenceEvent>> replies) =>
      serve([for (final reply in replies) Stream.fromIterable(reply)]);

  Future<_Started> startPrimary({AgentConfig? agentConfig}) async {
    final result = await provider.startPrimary(
      config: agentConfig ?? config(),
    );
    return _Started((result as StartPrimaryStarted).agent);
  }

  Future<_Started> startSubagent({String? label}) async {
    final result = await provider.startSubagent(
      config: config(),
      label: label,
    );
    return _Started((result as StartSubagentStarted).agent);
  }
}

final class _Started {
  _Started(this.agent) {
    agent.events.listen(events.add);
  }

  final Agent agent;
  final List<AgentRuntimeEvent> events = [];

  List<Type> get eventTypes =>
      events.map((event) => event.runtimeType).toList();

  bool get completed => events.any((event) => event is AgentCompleted);
}

Matcher _rejected<TResult extends Object>(AgentRuntimeRejectionReason reason) =>
    isA<TResult>().having(_reasonOf, 'reason', reason);

AgentRuntimeRejectionReason? _reasonOf(Object result) => switch (result) {
  StartPrimaryRejected(:final reason) ||
  StartSubagentRejected(:final reason) ||
  RunRejected(:final reason) ||
  SubmitToolResultsRejected(:final reason) ||
  SubmitCompactionPromptRejected(:final reason) ||
  CancelRejected(:final reason) ||
  DisposeAgentRejected(:final reason) => reason,
  _ => null,
};

void main() {
  group('RemoteAgentProvider', () {
    group('starting agents', () {
      test(
        'registers a primary and then subagents with numbered ids',
        () async {
          final harness = _Harness();

          final primary = await harness.startPrimary();
          final helper = await harness.startSubagent(label: 'helper');

          expect(primary.agent.handle.id, 'primary:1');
          expect(primary.agent.kind, AgentKind.primary);
          expect(primary.agent.label, isNull);
          expect(helper.agent.handle.id, 'subagent:2');
          expect(helper.agent.kind, AgentKind.subagent);
          expect(helper.agent.label, 'helper');
          expect(harness.provider.maxAgents, 4);
          expect(harness.provider.contextWindow, 1000);
        },
      );

      test('opens a session per agent, naming it to the endpoint', () async {
        final harness = _Harness();

        await harness.startPrimary();
        await harness.startSubagent(label: 'helper');

        verifyInOrder([
          () => harness.sessions.open(_primaryIdentity),
          () => harness.sessions.open(_helperIdentity),
        ]);
      });

      test('emits nothing until the endpoint reports its pool', () async {
        final harness = _Harness();
        when(
          () => harness.sessions.open(any()),
        ).thenAnswer((_) async => const AgentSessionOpened(claimedTokens: 0));

        await harness.startPrimary();
        await pumpEventQueue();

        expect(harness.snapshots, isEmpty);
      });

      test('leaves out agents the endpoint has not reported yet', () async {
        final harness = _Harness();
        when(
          () => harness.sessions.open(any()),
        ).thenAnswer((_) async => const AgentSessionOpened(claimedTokens: 0));
        harness.reports.add(
          const AgentPoolReport(
            contextSize: 4096,
            reservedTokens: 0,
            agents: [],
          ),
        );
        await pumpEventQueue();

        await harness.startPrimary();
        await pumpEventQueue();

        expect(harness.snapshots.single.leases, isEmpty);
      });

      test('reads context, reservations and claims from the report', () async {
        final harness = _Harness();
        final primary = await harness.startPrimary();
        final helper = await harness.startSubagent();

        harness.reports.add(
          const AgentPoolReport(
            contextSize: 8192,
            reservedTokens: 2048,
            agents: [
              AgentPoolEntry(agent: _primaryIdentity, claimedTokens: 6144),
              AgentPoolEntry(agent: _helperIdentity, claimedTokens: 2048),
            ],
          ),
        );
        await pumpEventQueue();

        expect(
          harness.snapshots.last,
          ContextPoolSnapshot(
            contextSize: 8192,
            reservedClaims: 2048,
            leases: [
              PoolLeaseOccupancy(
                handle: primary.agent.handle,
                residentTokens: 0,
                claimTokens: 6144,
              ),
              PoolLeaseOccupancy(
                handle: helper.agent.handle,
                residentTokens: 0,
                claimTokens: 2048,
              ),
            ],
          ),
        );
      });

      test('rejects an agent the endpoint has no session for', () async {
        final harness = _Harness();
        await harness.startPrimary();
        when(
          () => harness.sessions.open(any()),
        ).thenAnswer((_) async => const AgentSessionNoCapacity());

        final result = await harness.provider.startSubagent(config: config());

        expect(
          result,
          _rejected<StartSubagentRejected>(
            AgentRuntimeRejectionReason.noSequenceCapacity,
          ),
        );
      });

      test('rejects an agent the endpoint could not be asked about', () async {
        final harness = _Harness();
        when(() => harness.sessions.open(any())).thenAnswer(
          (_) async => const AgentSessionFailed(message: 'unreachable'),
        );

        final result = await harness.provider.startPrimary(config: config());

        expect(
          result,
          _rejected<StartPrimaryRejected>(
            AgentRuntimeRejectionReason.schedulerFailure,
          ),
        );
        verifyNever(() => harness.sessions.close(any()));
      });

      test('rejects an agent the endpoint has no context for', () async {
        final harness = _Harness();
        when(
          () => harness.sessions.open(any()),
        ).thenAnswer((_) async => const AgentSessionInsufficientClaim());

        final result = await harness.provider.startPrimary(config: config());

        expect(
          result,
          _rejected<StartPrimaryRejected>(
            AgentRuntimeRejectionReason.insufficientClaimSpace,
          ),
        );
        verifyNever(() => harness.sessions.close(any()));
        expect(
          await harness.provider.startSubagent(config: config()),
          _rejected<StartSubagentRejected>(
            AgentRuntimeRejectionReason.primaryAgentRequired,
          ),
        );
      });

      test(
        'releases a session opened while the provider was disposed',
        () async {
          final harness = _Harness();
          final opened = Completer<AgentSessionResult>();
          when(
            () => harness.sessions.open(any()),
          ).thenAnswer((_) => opened.future);

          final pending = harness.provider.startPrimary(config: config());
          await harness.provider.dispose();
          opened.complete(const AgentSessionOpened(claimedTokens: 0));

          expect(
            await pending,
            _rejected<StartPrimaryRejected>(
              AgentRuntimeRejectionReason.disposed,
            ),
          );
          verify(() => harness.sessions.close(_primaryIdentity)).called(1);
        },
      );

      test('admits one primary when two race for a session', () async {
        final harness = _Harness();

        final results = await Future.wait([
          harness.provider.startPrimary(config: config()),
          harness.provider.startPrimary(config: config()),
        ]);

        expect(results.first, isA<StartPrimaryStarted>());
        expect(
          results.last,
          _rejected<StartPrimaryRejected>(
            AgentRuntimeRejectionReason.primaryAgentAlreadyCreated,
          ),
        );
        verify(
          () => harness.sessions.close(
            const AgentIdentity(
              id: 'primary:2',
              kind: AgentIdentityKind.primary,
            ),
          ),
        ).called(1);
      });

      test('emits a pool snapshot each time the pool changes', () async {
        final harness = _Harness();

        final primary = await harness.startPrimary();
        final helper = await harness.startSubagent();
        await pumpEventQueue();

        expect(
          harness.snapshots.map((snapshot) => snapshot.leases.length),
          [0, 1, 2],
        );
        final snapshot = harness.snapshots.last;
        expect(snapshot.contextSize, 1000);
        expect(snapshot.reservedClaims, 0);
        expect(snapshot.leases, [
          PoolLeaseOccupancy(
            handle: primary.agent.handle,
            residentTokens: 0,
            claimTokens: 0,
          ),
          PoolLeaseOccupancy(
            handle: helper.agent.handle,
            residentTokens: 0,
            claimTokens: 1000,
          ),
        ]);
      });

      test('rejects a second primary', () async {
        final harness = _Harness();
        await harness.startPrimary();

        final result = await harness.provider.startPrimary(config: config());

        expect(
          result,
          _rejected<StartPrimaryRejected>(
            AgentRuntimeRejectionReason.primaryAgentAlreadyCreated,
          ),
        );
      });

      test('rejects a subagent without a primary', () async {
        final harness = _Harness();

        final result = await harness.provider.startSubagent(config: config());

        expect(
          result,
          _rejected<StartSubagentRejected>(
            AgentRuntimeRejectionReason.primaryAgentRequired,
          ),
        );
      });

      test('rejects invalid configs', () async {
        final harness = _Harness();

        final result = await harness.provider.startPrimary(
          config: config(reasoningMode: ''),
        );

        expect(
          result,
          _rejected<StartPrimaryRejected>(
            AgentRuntimeRejectionReason.invalidConfig,
          ),
        );
      });

      test('rejects agents beyond the cap', () async {
        final harness = _Harness(maxAgents: 2);
        await harness.startPrimary();
        await harness.startSubagent();

        final result = await harness.provider.startSubagent(config: config());

        expect(
          result,
          _rejected<StartSubagentRejected>(
            AgentRuntimeRejectionReason.agentCapacityReached,
          ),
        );
      });

      test('rejects everything once disposed', () async {
        final harness = _Harness();
        await harness.provider.dispose();

        expect(
          await harness.provider.startPrimary(config: config()),
          _rejected<StartPrimaryRejected>(AgentRuntimeRejectionReason.disposed),
        );
        expect(
          await harness.provider.startSubagent(config: config()),
          _rejected<StartSubagentRejected>(
            AgentRuntimeRejectionReason.disposed,
          ),
        );
        expect(
          await harness.provider.run(
            primaryHandle,
            transcriptOf([]),
            null,
            TurnGoal.respond,
          ),
          _rejected<RunRejected>(AgentRuntimeRejectionReason.disposed),
        );
        expect(
          await harness.provider.submitToolResults(primaryHandle, []),
          _rejected<SubmitToolResultsRejected>(
            AgentRuntimeRejectionReason.disposed,
          ),
        );
        expect(
          await harness.provider.submitCompactionPrompt(
            primaryHandle,
            compactionContent,
          ),
          _rejected<SubmitCompactionPromptRejected>(
            AgentRuntimeRejectionReason.disposed,
          ),
        );
        expect(
          await harness.provider.cancel(primaryHandle),
          _rejected<CancelRejected>(AgentRuntimeRejectionReason.disposed),
        );
        expect(
          await harness.provider.disposeAgent(
            RemoteAgent(
              handle: primaryHandle,
              events: const Stream.empty(),
              host: harness.provider,
            ),
          ),
          _rejected<DisposeAgentRejected>(AgentRuntimeRejectionReason.disposed),
        );
      });
    });

    group('running', () {
      test('streams a completion and reports events in order', () async {
        final harness = _Harness()..serveReplies([_textReply('hello')]);
        final started = await harness.startPrimary();

        final result = await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();

        expect(result, const RunAccepted());
        expect(started.eventTypes, [
          AgentStarted,
          AgentStepStarted,
          AgentTextDelta,
          AgentTelemetryUpdated,
          AgentCompleted,
        ]);
        final request = harness.requests.single;
        expect(request.model, 'test/model');
        expect(request.messages, hasLength(2));
        expect(harness.abortTriggers.single, isNotNull);
        expect(harness.snapshots.last.leases.single.residentTokens, 60);
      });

      test('publishes what each completion cost', () async {
        final harness = _Harness()
          ..serveReplies([
            [
              const InferenceTextDelta('hi'),
              const InferenceUsageReported(
                promptTokens: 40,
                completionTokens: 20,
                cost: 0.03,
              ),
              _finished,
            ],
          ]);
        final charges = <double>[];
        harness.provider.spend.listen(charges.add);
        final started = await harness.startPrimary();

        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();

        expect(charges, [0.03]);
      });

      test('accepts a new run after the previous turn completed', () async {
        final harness = _Harness()
          ..serveReplies([_textReply('one'), _textReply('two')]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();

        final result = await started.agent.run(
          transcriptOf([userEntry('again')]),
        );
        await pumpEventQueue();

        expect(result, const RunAccepted());
        expect(harness.requests, hasLength(2));
        expect(started.events.whereType<AgentCompleted>(), hasLength(2));
      });

      test('keeps a turn started before the previous teardown ran', () async {
        final harness = _Harness()
          ..serve([
            Stream.fromIterable(_textReply('one')),
            StreamController<InferenceEvent>().stream,
          ]);
        final started = await harness.startPrimary();
        started.agent.events.listen((event) {
          if (event is AgentCompleted) {
            unawaited(started.agent.run(transcriptOf([userEntry('again')])));
          }
        });

        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();

        expect(harness.requests, hasLength(2));
        expect(await started.agent.cancel(), const CancelAccepted());
      });

      test('applies a valid config override for the run', () async {
        final harness = _Harness()..serveReplies([_textReply('one')]);
        final started = await harness.startPrimary();

        await started.agent.run(
          transcriptOf([userEntry('hi')]),
          config: config(systemPrompt: 'Be loud.'),
        );
        await pumpEventQueue();

        final system = harness.requests.single.messages.first;
        expect((system as InferenceSystemMessage).text, 'Be loud.');
      });

      test('rejects an invalid config override', () async {
        final harness = _Harness();
        final started = await harness.startPrimary();

        final result = await started.agent.run(
          transcriptOf([]),
          config: config(reasoningMode: ''),
        );

        expect(
          result,
          _rejected<RunRejected>(AgentRuntimeRejectionReason.invalidConfig),
        );
      });

      test('rejects unknown agents', () async {
        final harness = _Harness();

        final result = await harness.provider.run(
          subagentHandle,
          transcriptOf([]),
          null,
          TurnGoal.respond,
        );

        expect(
          result,
          _rejected<RunRejected>(AgentRuntimeRejectionReason.unknownAgent),
        );
      });

      test('rejects a run while a turn is live', () async {
        final harness = _Harness()
          ..serve([StreamController<InferenceEvent>().stream]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([]));

        final result = await started.agent.run(transcriptOf([]));

        expect(
          result,
          _rejected<RunRejected>(AgentRuntimeRejectionReason.busy),
        );
      });

      test('surfaces stream errors as loop failures', () async {
        final harness = _Harness()..serve([Stream.error(StateError('boom'))]);
        final started = await harness.startPrimary();

        await started.agent.run(transcriptOf([]));
        await pumpEventQueue();

        final failed = started.events.whereType<AgentFailed>().single;
        expect(failed.reason, AgentRunFailureReason.loopFailed);
        expect(failed.message, 'Bad state: boom');
      });
    });

    group('tool results', () {
      test('applies responses and continues the loop', () async {
        final harness = _Harness()
          ..serveReplies([_toolReply, _textReply('done')]);
        final started = await harness.startPrimary(
          agentConfig: config(tools: [tool('echo')]),
        );
        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();
        expect(started.events.last, isA<AgentNeedsToolResults>());

        final result = await started.agent.submitToolResults(const [
          ToolCallSucceeded(callId: 'call_a', toolName: 'echo', content: 'ok'),
        ]);
        await pumpEventQueue();

        expect(result, const SubmitToolResultsAccepted());
        expect(started.eventTypes, [
          AgentStarted,
          AgentStepStarted,
          AgentToolCallEmitted,
          AgentTelemetryUpdated,
          AgentNeedsToolResults,
          AgentToolResponseApplied,
          AgentUpdated,
          AgentStepStarted,
          AgentTextDelta,
          AgentTelemetryUpdated,
          AgentCompleted,
        ]);
        final applied = started.events
            .whereType<AgentToolResponseApplied>()
            .single;
        final updated = started.events.whereType<AgentUpdated>().single;
        final toolEntry = updated.transcript.entries.last;
        expect(toolEntry.id, applied.entryId);
        expect(toolEntry.role, Role.tool);
        expect(toolEntry.name, 'echo');
        expect(toolEntry.blocks.single.id, applied.blockId);
        final followUp = harness.requests.last.messages.last;
        expect((followUp as InferenceToolResultMessage).content, 'ok');
        expect(harness.requests.last.tools.single.name, 'echo');
      });

      test('rejects submissions when no turn is waiting', () async {
        final harness = _Harness()
          ..serve([StreamController<InferenceEvent>().stream]);
        final started = await harness.startPrimary();

        expect(
          await started.agent.submitToolResults(const []),
          _rejected<SubmitToolResultsRejected>(
            AgentRuntimeRejectionReason.agentNotRunning,
          ),
        );
        expect(
          await harness.provider.submitToolResults(subagentHandle, const []),
          _rejected<SubmitToolResultsRejected>(
            AgentRuntimeRejectionReason.unknownAgent,
          ),
        );

        await started.agent.run(transcriptOf([]));

        expect(
          await started.agent.submitToolResults(const []),
          _rejected<SubmitToolResultsRejected>(
            AgentRuntimeRejectionReason.busy,
          ),
        );
      });
    });

    group('compaction', () {
      test('asks for a prompt, folds, and continues', () async {
        final harness = _Harness(contextWindow: 100)
          ..serveReplies([
            _textReply('first'),
            [
              const InferenceTextDelta(' folded'),
              const InferenceUsageReported(
                promptTokens: 30,
                completionTokens: 8,
              ),
              _finished,
            ],
            _textReply('second'),
          ]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();
        final completed = started.events.whereType<AgentCompleted>().single;
        started.events.clear();

        await started.agent.run(
          transcriptOf([...completed.transcript.entries, userEntry('more')]),
        );
        await pumpEventQueue();
        expect(started.eventTypes, [
          AgentStarted,
          AgentCompactionStarted,
          AgentNeedsCompactionPrompt,
        ]);

        final result = await started.agent.submitCompactionPrompt(
          compactionContent,
        );
        await pumpEventQueue();

        expect(result, const SubmitCompactionPromptAccepted());
        expect(started.eventTypes, [
          AgentStarted,
          AgentCompactionStarted,
          AgentNeedsCompactionPrompt,
          AgentSummaryDelta,
          AgentSummaryDelta,
          AgentCompactionCompleted,
          AgentUpdated,
          AgentStepStarted,
          AgentTextDelta,
          AgentTelemetryUpdated,
          AgentCompleted,
        ]);
        expect(harness.requests, hasLength(3));
        expect(harness.requests[1].tools, isEmpty);
        expect(harness.snapshots.last.leases.single.residentTokens, 60);
      });

      test('rejects a prompt when no turn is waiting for one', () async {
        final harness = _Harness()
          ..serve([StreamController<InferenceEvent>().stream]);
        final started = await harness.startPrimary();

        expect(
          await started.agent.submitCompactionPrompt(compactionContent),
          _rejected<SubmitCompactionPromptRejected>(
            AgentRuntimeRejectionReason.agentNotRunning,
          ),
        );

        await started.agent.run(transcriptOf([]));

        expect(
          await started.agent.submitCompactionPrompt(compactionContent),
          _rejected<SubmitCompactionPromptRejected>(
            AgentRuntimeRejectionReason.busy,
          ),
        );
      });

      test('a compact goal folds once and completes without a step', () async {
        final harness = _Harness(contextWindow: 100)
          ..serveReplies([
            [
              const InferenceTextDelta(' folded'),
              const InferenceUsageReported(
                promptTokens: 30,
                completionTokens: 8,
              ),
              _finished,
            ],
          ]);
        final started = await harness.startPrimary();

        final result = await started.agent.run(
          transcriptOf([userEntry('hi'), assistantEntry(text: 'yo')]),
          goal: TurnGoal.compact,
        );
        await pumpEventQueue();

        expect(result, const RunAccepted());
        expect(started.eventTypes, [
          AgentStarted,
          AgentCompactionStarted,
          AgentNeedsCompactionPrompt,
        ]);

        await started.agent.submitCompactionPrompt(compactionContent);
        await pumpEventQueue();

        expect(started.eventTypes, [
          AgentStarted,
          AgentCompactionStarted,
          AgentNeedsCompactionPrompt,
          AgentSummaryDelta,
          AgentSummaryDelta,
          AgentCompactionCompleted,
          AgentUpdated,
          AgentCompleted,
        ]);
        expect(harness.requests, hasLength(1));
        expect(harness.requests.single.tools, isEmpty);
        expect(harness.snapshots.last.leases.single.residentTokens, 8);
        expect(
          await started.agent.run(transcriptOf([userEntry('again')])),
          const RunAccepted(),
        );
      });

      test('rejects a compact goal with nothing to fold', () async {
        final harness = _Harness();
        final started = await harness.startPrimary();

        expect(
          await started.agent.run(
            transcriptOf([summaryEntry('Earlier.')]),
            goal: TurnGoal.compact,
          ),
          _rejected<RunRejected>(AgentRuntimeRejectionReason.nothingToCompact),
        );
        expect(started.events, isEmpty);
      });

      test('cancels cleanly while waiting for a prompt', () async {
        final harness = _Harness(contextWindow: 100)
          ..serveReplies([_textReply('first')]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([userEntry('hi')]));
        await pumpEventQueue();
        final completed = started.events.whereType<AgentCompleted>().single;
        await started.agent.run(transcriptOf(completed.transcript.entries));
        await pumpEventQueue();

        expect(await started.agent.cancel(), const CancelAccepted());
        await pumpEventQueue();

        expect(started.events.last, isA<AgentCancelled>());
      });
    });

    group('cancel', () {
      test('aborts the stream and ignores late events', () async {
        final controller = StreamController<InferenceEvent>();
        final harness = _Harness()..serve([controller.stream]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([userEntry('hi')]));
        controller.add(const InferenceTextDelta('part'));
        await pumpEventQueue();

        final result = await started.agent.cancel();
        controller.add(const InferenceTextDelta('late'));
        await controller.close();
        await pumpEventQueue();

        expect(result, const CancelAccepted());
        expect(harness.abortTriggers.single, completes);
        expect(started.eventTypes, [
          AgentStarted,
          AgentStepStarted,
          AgentTextDelta,
          AgentCancelled,
        ]);
        final cancelled = started.events.last as AgentCancelled;
        expect(cancelled.transcript.entries, hasLength(2));
        expect(
          await started.agent.run(transcriptOf([])),
          const RunAccepted(),
          reason: 'the cancelled turn is torn down',
        );
      });

      test('rejects when nothing is running', () async {
        final harness = _Harness();
        final started = await harness.startPrimary();

        expect(
          await started.agent.cancel(),
          _rejected<CancelRejected>(
            AgentRuntimeRejectionReason.agentNotRunning,
          ),
        );
        expect(
          await harness.provider.cancel(subagentHandle),
          _rejected<CancelRejected>(AgentRuntimeRejectionReason.unknownAgent),
        );
      });
    });

    group('disposeAgent', () {
      test('ends the agent and updates the pool', () async {
        final harness = _Harness();
        final started = await harness.startPrimary();

        final result = await harness.provider.disposeAgent(started.agent);
        await pumpEventQueue();

        expect(result, const DisposeAgentDisposed());
        expect(started.eventTypes, [AgentEnded]);
        expect(harness.snapshots.last.leases, isEmpty);
        verify(() => harness.sessions.close(_primaryIdentity)).called(1);
        expect(
          await harness.provider.disposeAgent(started.agent),
          _rejected<DisposeAgentRejected>(
            AgentRuntimeRejectionReason.unknownAgent,
          ),
        );
      });

      test('emits one snapshot for the closed session', () async {
        final harness = _Harness(reservesSubagentClaims: true);
        await harness.startPrimary();
        final helper = await harness.startSubagent();
        await pumpEventQueue();
        final before = harness.snapshots.length;

        await harness.provider.disposeAgent(helper.agent);
        await pumpEventQueue();

        expect(harness.snapshots, hasLength(before + 1));
        expect(harness.snapshots.last.leases, hasLength(1));
        expect(harness.snapshots.last.reservedClaims, 0);
      });

      test('rejects while a turn is live', () async {
        final harness = _Harness()
          ..serve([StreamController<InferenceEvent>().stream]);
        final started = await harness.startPrimary();
        await started.agent.run(transcriptOf([]));

        final result = await harness.provider.disposeAgent(started.agent);

        expect(
          result,
          _rejected<DisposeAgentRejected>(AgentRuntimeRejectionReason.busy),
        );
      });
    });

    group('dispose', () {
      test('cancels live turns, ends agents, and closes the client', () async {
        final harness = _Harness()
          ..serve([StreamController<InferenceEvent>().stream]);
        final running = await harness.startPrimary();
        final idle = await harness.startSubagent();
        await running.agent.run(transcriptOf([userEntry('hi')]));

        final result = await harness.provider.dispose();
        await pumpEventQueue();

        expect(result, const DisposeProviderSucceeded());
        expect(harness.abortTriggers.single, completes);
        expect(running.eventTypes, [
          AgentStarted,
          AgentStepStarted,
          AgentCancelled,
          AgentEnded,
        ]);
        expect(idle.eventTypes, [AgentEnded]);
        verify(harness.client.close).called(1);
        verify(() => harness.sessions.close(_primaryIdentity)).called(1);
        verify(() => harness.sessions.close(_helperIdentity)).called(1);
        verify(harness.sessions.dispose).called(1);
        expect(harness.reports.hasListener, isFalse);
        expect(
          await harness.provider.dispose(),
          const DisposeProviderSucceeded(),
        );
        verifyNever(harness.client.close);
      });
    });
  });
}
