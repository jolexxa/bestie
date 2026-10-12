import 'dart:async';

import 'package:engine_completions/engine_completions.dart';
import 'package:engine_protocol/engine_protocol.dart';
import 'package:local_server/local_server.dart';
import 'package:local_server/src/engine/engine_dispatcher.dart';
import 'package:local_server/src/engine/engine_messages.dart';
import 'package:local_server/src/engine/isolated_model_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/index.dart';
import '../../helpers/mocks.dart';

const _request = ModelEngineRequest(entry: qwenEntry, maxAgents: 2);

const _completion = EngineCompletionRequest(
  messages: [],
  reasoningMode: 'off',
  sampling: EngineSampling(),
);

const _usage = EngineCompletionUsage(
  promptTokens: 1,
  completionTokens: 1,
  cachedTokens: 0,
  promptTime: Duration.zero,
  generationTime: Duration.zero,
);

const _pool = PoolSnapshot(
  contextSize: 4096,
  maxAgents: 2,
  agents: [PrimaryPoolLease(id: 'primary:1', usedTokens: 3)],
  borrowedTokens: 7,
);

void main() {
  late MockModelEngine inner;
  late StreamController<EngineReply> replies;
  late List<EngineCommand> sent;
  late IsolatedModelEngine engine;
  late bool terminated;
  late MockLoadedModel innerModel;
  late MockEngineCompletionRuntime innerRuntime;
  late StreamController<PoolSnapshot> innerPool;

  setUpAll(() {
    registerFallbackValue(_request);
    registerFallbackValue(_completion);
  });

  setUp(() {
    inner = MockModelEngine();
    when(inner.close).thenAnswer((_) async {});
    replies = StreamController<EngineReply>();
    sent = [];
    terminated = false;
    final dispatcher = EngineDispatcher(engine: inner, send: replies.add);
    engine = IsolatedModelEngine(
      send: (command) {
        sent.add(command);
        scheduleMicrotask(() => dispatcher.handle(command));
      },
      replies: replies.stream,
      terminate: () async => terminated = true,
    );
    innerPool = StreamController<PoolSnapshot>.broadcast();
    innerModel = MockLoadedModel.serving(
      contextSize: 4096,
      maxAgents: 2,
      poolChanges: innerPool,
    );
    innerRuntime = innerModel.runtime as MockEngineCompletionRuntime;
    when(() => innerRuntime.pool).thenReturn(_pool);
  });

  tearDown(() async {
    await innerPool.close();
    await replies.close();
  });

  Future<LoadedModel> loaded() async {
    when(() => inner.load(any())).thenAnswer(
      (_) => Stream.value(ModelEngineLoaded(model: innerModel)),
    );
    final events = await engine.load(_request).toList();
    return (events.single as ModelEngineLoaded).model;
  }

  group('loads', () {
    test('relay each step and hand back a proxy of the model', () async {
      when(() => inner.load(_request)).thenAnswer(
        (_) => Stream.fromIterable([
          const ModelEngineFitted(contextSize: 4096),
          const ModelEngineProgressed(progress: 0.5),
          ModelEngineLoaded(model: innerModel),
        ]),
      );

      final events = await engine.load(_request).toList();

      expect(events, [
        isA<ModelEngineFitted>().having(
          (fitted) => fitted.contextSize,
          'context size',
          4096,
        ),
        isA<ModelEngineProgressed>().having(
          (progressed) => progressed.progress,
          'progress',
          0.5,
        ),
        isA<ModelEngineLoaded>(),
      ]);
      final model = (events.last as ModelEngineLoaded).model;
      expect(model.deviceBytes, 1234);
      expect(model.runtime.contextSize, 4096);
      expect(model.runtime.maxAgents, 2);
      expect(model.runtime.pool, same(_pool));
    });

    test('relay a failure', () async {
      when(() => inner.load(any())).thenAnswer(
        (_) => Stream.value(const ModelEngineFailed(reason: 'too big')),
      );

      expect(await engine.load(_request).toList(), [
        isA<ModelEngineFailed>().having(
          (failed) => failed.reason,
          'reason',
          'too big',
        ),
      ]);
    });

    test('report an engine that breaks as a failure', () async {
      when(() => inner.load(any())).thenAnswer(
        (_) => Stream.error(StateError('segfault-ish')),
      );

      expect(await engine.load(_request).toList(), [
        isA<ModelEngineFailed>().having(
          (failed) => failed.reason,
          'reason',
          contains('segfault-ish'),
        ),
      ]);
    });

    test('abandon the load when no longer wanted', () async {
      final abandoned = Completer<void>();
      final loading = StreamController<ModelEngineEvent>(
        onCancel: abandoned.complete,
      );
      when(() => inner.load(any())).thenAnswer((_) => loading.stream);
      final subscription = engine.load(_request).listen((_) {});
      await pumpEventQueue();

      await subscription.cancel();

      await abandoned.future;
      expect(sent.last, isA<AbandonLoadCommand>());
    });

    test('a load that settled is not abandoned', () async {
      when(() => inner.load(any())).thenAnswer(
        (_) => Stream.value(ModelEngineLoaded(model: innerModel)),
      );
      final model = Completer<void>();
      late final StreamSubscription<ModelEngineEvent> subscription;
      subscription = engine.load(_request).listen((_) {
        unawaited(subscription.cancel());
        model.complete();
      });

      await model.future;
      await pumpEventQueue();

      expect(sent.whereType<AbandonLoadCommand>(), isEmpty);
    });

    test('unload a model whose load was abandoned on the way', () async {
      final model = await loaded();
      final unloaded = Completer<void>();
      when(innerModel.unload).thenAnswer((_) async => unloaded.complete());

      replies.add(
        const ModelProduced(
          modelId: 0,
          contextSize: 4096,
          maxAgents: 2,
          deviceBytes: 1,
          pool: _pool,
        ),
      );

      await unloaded.future;
      verify(innerRuntime.dispose).called(1);
      expect(model.runtime.contextSize, 4096);
    });
  });

  group('runtime', () {
    late EngineCompletionRuntime runtime;

    setUp(() async => runtime = (await loaded()).runtime);

    test('opens and closes leases on the engine', () async {
      when(() => innerRuntime.openPrimary('primary:1')).thenAnswer(
        (_) async => const AgentLeaseOpened(claimedTokens: 0),
      );
      when(() => innerRuntime.openSubagent('sub:1')).thenAnswer(
        (_) async => const AgentLeaseOpened(claimedTokens: 512),
      );
      when(() => innerRuntime.close('sub:1')).thenAnswer(
        (_) async => const AgentLeaseClosed(),
      );

      expect(
        await runtime.openPrimary('primary:1'),
        isA<AgentLeaseOpened>().having(
          (opened) => opened.claimedTokens,
          'claimed',
          0,
        ),
      );
      expect(
        await runtime.openSubagent('sub:1'),
        isA<AgentLeaseOpened>().having(
          (opened) => opened.claimedTokens,
          'claimed',
          512,
        ),
      );
      expect(await runtime.close('sub:1'), isA<AgentLeaseClosed>());
      await runtime.closeAll();
      verify(innerRuntime.closeAll).called(1);
    });

    test('answers calls the engine broke on with typed failures', () async {
      when(() => innerRuntime.openPrimary(any())).thenThrow(StateError('a'));
      when(() => innerRuntime.openSubagent(any())).thenThrow(StateError('b'));
      when(() => innerRuntime.close(any())).thenThrow(StateError('c'));
      when(() => innerRuntime.complete(any())).thenThrow(StateError('d'));
      when(innerRuntime.closeAll).thenThrow(StateError('e'));

      expect(
        await runtime.openPrimary('x'),
        isA<AgentLeaseFailed>().having(
          (failed) => failed.message,
          'message',
          contains('a'),
        ),
      );
      expect(await runtime.openSubagent('x'), isA<AgentLeaseFailed>());
      expect(
        await runtime.close('x'),
        isA<AgentCloseFailed>().having(
          (failed) => failed.message,
          'message',
          contains('c'),
        ),
      );
      expect(
        await runtime.complete(_completion),
        isA<EngineCompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          EngineCompletionRejection.engineFailed,
        ),
      );
      await runtime.closeAll();
    });

    test('mirrors the pool as the engine publishes it', () async {
      const next = PoolSnapshot(contextSize: 4096, maxAgents: 2, agents: []);
      final published = runtime.poolChanges.first;

      innerPool.add(next);

      expect(await published, same(next));
      expect(runtime.pool, same(next));
    });

    test('passes a refused completion through', () async {
      when(() => innerRuntime.complete(any())).thenAnswer(
        (_) async => const EngineCompletionRejected(
          reason: EngineCompletionRejection.agentBusy,
          message: 'busy',
        ),
      );

      expect(
        await runtime.complete(_completion),
        isA<EngineCompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          EngineCompletionRejection.agentBusy,
        ),
      );
    });

    group('completions', () {
      late StreamController<EngineCompletionEvent> turn;
      var turnCancelled = false;

      setUp(() {
        turnCancelled = false;
        turn = StreamController<EngineCompletionEvent>(
          onCancel: () => turnCancelled = true,
        );
        when(() => innerRuntime.complete(any())).thenAnswer(
          (_) async => EngineCompletionStarted(turn.stream),
        );
      });

      Future<Stream<EngineCompletionEvent>> started() async =>
          (await runtime.complete(_completion) as EngineCompletionStarted)
              .events;

      test('relay every event in order', () async {
        final events = await started();
        final collected = events.toList();

        turn
          ..add(const EngineCompletionTextDelta('Hi', tokens: 1))
          ..add(
            const EngineCompletionFinished(
              reason: EngineCompletionStopReason.stop,
              usage: _usage,
            ),
          );
        await turn.close();

        expect(await collected, [
          isA<EngineCompletionTextDelta>().having(
            (delta) => delta.text,
            'text',
            'Hi',
          ),
          isA<EngineCompletionFinished>(),
        ]);
      });

      test('merge deltas that pile up before the server pulls', () async {
        final events = await started();
        turn
          ..add(const EngineCompletionTextDelta('a', tokens: 1))
          ..add(const EngineCompletionTextDelta('b', tokens: 1))
          ..add(const EngineCompletionReasoningDelta('x', tokens: 1))
          ..add(const EngineCompletionReasoningDelta('y', tokens: 1))
          ..add(
            const EngineCompletionToolCalled(
              id: 'call_1',
              name: 'read',
              argumentsJson: '{}',
              tokens: 1,
            ),
          )
          ..add(const EngineCompletionTextDelta('c', tokens: 1));
        await turn.close();
        await pumpEventQueue();

        expect(await events.toList(), [
          isA<EngineCompletionTextDelta>()
              .having((delta) => delta.text, 'text', 'ab')
              .having((delta) => delta.tokens, 'tokens', 2),
          isA<EngineCompletionReasoningDelta>()
              .having((delta) => delta.text, 'text', 'xy')
              .having((delta) => delta.tokens, 'tokens', 2),
          isA<EngineCompletionToolCalled>(),
          isA<EngineCompletionTextDelta>().having(
            (delta) => delta.text,
            'text',
            'c',
          ),
        ]);
        expect(sent.whereType<PullTurnCommand>(), hasLength(1));
      });

      test('keep only the newest prefill progress that piles up', () async {
        final events = await started();
        turn
          ..add(
            const EngineCompletionPrefillProgressed(
              total: 8,
              cached: 0,
              processed: 2,
              elapsed: Duration.zero,
            ),
          )
          ..add(
            const EngineCompletionPrefillProgressed(
              total: 8,
              cached: 0,
              processed: 8,
              elapsed: Duration.zero,
            ),
          )
          ..add(const EngineCompletionTextDelta('a', tokens: 1));
        await turn.close();
        await pumpEventQueue();

        expect(await events.toList(), [
          isA<EngineCompletionPrefillProgressed>().having(
            (progress) => progress.processed,
            'processed',
            8,
          ),
          isA<EngineCompletionTextDelta>(),
        ]);
      });

      test('hold one batch at most while the server is paused', () async {
        final events = await started();
        final received = <EngineCompletionEvent>[];
        final subscription = events.listen(received.add);
        turn.add(const EngineCompletionTextDelta('a', tokens: 1));
        await pumpEventQueue();
        subscription.pause();
        turn
          ..add(const EngineCompletionTextDelta('b', tokens: 1))
          ..add(const EngineCompletionTextDelta('c', tokens: 1));
        await pumpEventQueue();
        final pullsWhilePaused = sent.whereType<PullTurnCommand>().length;
        final receivedWhilePaused = [...received];

        subscription.resume();
        await pumpEventQueue();

        expect(pullsWhilePaused, 2);
        expect(receivedWhilePaused, hasLength(1));
        expect(sent.whereType<PullTurnCommand>(), hasLength(4));
        expect(
          [
            for (final event in received)
              (event as EngineCompletionTextDelta).text,
          ],
          ['a', 'b', 'c'],
        );
        await subscription.cancel();
      });

      test('cancelling stops the completion', () async {
        final events = await started();
        final subscription = events.listen((_) {});
        await pumpEventQueue();

        await subscription.cancel();
        await pumpEventQueue();

        expect(turnCancelled, isTrue);
        expect(sent.last, isA<CancelTurnCommand>());
      });

      test('a completion that breaks fails', () async {
        final events = await started();
        final collected = events.toList();

        turn.addError(StateError('torn'));
        await turn.close();

        expect(await collected, [
          isA<EngineCompletionFailed>().having(
            (failed) => failed.failure,
            'failure',
            EngineCompletionFailure.engineFailed,
          ),
        ]);
      });
    });

    test('disposes the runtime, then unloads the model', () async {
      final model = await loaded();
      final poolEnded = model.runtime.poolChanges.toList();

      await model.runtime.dispose();
      await model.unload();

      verify(innerRuntime.dispose).called(1);
      verify(innerModel.unload).called(1);
      expect(await poolEnded, isEmpty);
      expect(
        await model.runtime.openPrimary('late'),
        isA<AgentLeaseFailed>().having(
          (failed) => failed.message,
          'message',
          contains('not loaded'),
        ),
      );
    });
  });

  group('lifetime', () {
    test('close closes the engine, then stops it', () async {
      await engine.close();

      verify(inner.close).called(1);
      expect(terminated, isTrue);
    });

    test('close abandons loads still running', () async {
      final abandoned = Completer<void>();
      final loading = StreamController<ModelEngineEvent>(
        onCancel: abandoned.complete,
      );
      when(() => inner.load(any())).thenAnswer((_) => loading.stream);
      final events = engine.load(_request).toList();
      await pumpEventQueue();

      await engine.close();

      await abandoned.future;
      expect(await events, [isA<ModelEngineFailed>()]);
    });

    test('close stops an engine that never answers', () async {
      final silent = IsolatedModelEngine(
        send: (_) {},
        replies: const Stream.empty(),
        terminate: () async => terminated = true,
        closeTimeout: const Duration(milliseconds: 10),
      );

      await silent.close();

      expect(terminated, isTrue);
    });

    test('losing the engine fails everything waiting on it', () async {
      final model = await loaded();
      final runtime = model.runtime;
      when(() => innerRuntime.complete(any())).thenAnswer(
        (_) async => EngineCompletionStarted(
          StreamController<EngineCompletionEvent>().stream,
        ),
      );
      final live =
          (await runtime.complete(_completion) as EngineCompletionStarted)
              .events
              .toList();
      final waiting = Completer<AgentOpenOutcome>();
      when(() => innerRuntime.openPrimary(any())).thenAnswer(
        (_) => waiting.future,
      );
      final pending = runtime.openPrimary('primary:1');
      when(() => inner.load(any())).thenAnswer(
        (_) => StreamController<ModelEngineEvent>().stream,
      );
      final loading = engine.load(_request).toList();
      await pumpEventQueue();

      engine.lose('crashed');

      expect(
        await pending,
        isA<AgentLeaseFailed>().having(
          (failed) => failed.message,
          'message',
          'crashed',
        ),
      );
      expect(await live, [
        isA<EngineCompletionFailed>().having(
          (failed) => failed.message,
          'message',
          'crashed',
        ),
      ]);
      expect(await loading, [
        isA<ModelEngineFailed>().having(
          (failed) => failed.reason,
          'reason',
          'crashed',
        ),
      ]);
      expect(await runtime.close('x'), isA<AgentCloseFailed>());
      await runtime.closeAll();
      await runtime.dispose();
      await model.unload();
      verifyNever(innerModel.unload);
      expect(await engine.load(_request).toList(), [
        isA<ModelEngineFailed>(),
      ]);
    });
  });
}
