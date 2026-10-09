import 'dart:async';

import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference/inference.dart';
import 'package:inference_server/inference_server.dart';
import 'package:inference_server/src/engine/engine_host.dart';
import 'package:inference_server/src/engine/engine_messages.dart';
import 'package:inference_server/src/engine/remote_model_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/index.dart';
import '../../helpers/mocks.dart';

const _request = ModelEngineRequest(entry: qwenEntry, maxAgents: 2);

const _completion = CompletionRequest(
  messages: [],
  reasoningMode: 'off',
  sampling: EngineSampling(),
);

const _usage = CompletionUsage(
  promptTokens: 1,
  completionTokens: 1,
  cachedTokens: 0,
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
  late RemoteModelEngine engine;
  late bool terminated;
  late MockLoadedModel innerModel;
  late MockCompletionRuntime innerRuntime;
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
    final host = EngineHost(engine: inner, send: replies.add);
    engine = RemoteModelEngine(
      send: (command) {
        sent.add(command);
        scheduleMicrotask(() => host.handle(command));
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
    innerRuntime = innerModel.runtime as MockCompletionRuntime;
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
        const ModelHosted(
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
    late CompletionRuntime runtime;

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
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.engineFailed,
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
        (_) async => const CompletionRejected(
          reason: CompletionRejection.agentBusy,
          message: 'busy',
        ),
      );

      expect(
        await runtime.complete(_completion),
        isA<CompletionRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          CompletionRejection.agentBusy,
        ),
      );
    });

    group('completions', () {
      late StreamController<CompletionEvent> turn;
      var turnCancelled = false;

      setUp(() {
        turnCancelled = false;
        turn = StreamController<CompletionEvent>(
          onCancel: () => turnCancelled = true,
        );
        when(() => innerRuntime.complete(any())).thenAnswer(
          (_) async => CompletionStarted(turn.stream),
        );
      });

      Future<Stream<CompletionEvent>> started() async =>
          (await runtime.complete(_completion) as CompletionStarted).events;

      test('relay every event in order', () async {
        final events = await started();
        final collected = events.toList();

        turn
          ..add(const CompletionTextDelta('Hi'))
          ..add(
            const CompletionFinished(
              reason: CompletionStopReason.stop,
              usage: _usage,
            ),
          );
        await turn.close();

        expect(await collected, [
          isA<CompletionTextDelta>().having(
            (delta) => delta.text,
            'text',
            'Hi',
          ),
          isA<CompletionFinished>(),
        ]);
      });

      test('merge deltas that pile up before the server pulls', () async {
        final events = await started();
        turn
          ..add(const CompletionTextDelta('a'))
          ..add(const CompletionTextDelta('b'))
          ..add(const CompletionReasoningDelta('x'))
          ..add(const CompletionReasoningDelta('y'))
          ..add(
            const CompletionToolCalled(
              id: 'call_1',
              name: 'read',
              argumentsJson: '{}',
            ),
          )
          ..add(const CompletionTextDelta('c'));
        await turn.close();
        await pumpEventQueue();

        expect(await events.toList(), [
          isA<CompletionTextDelta>().having(
            (delta) => delta.text,
            'text',
            'ab',
          ),
          isA<CompletionReasoningDelta>().having(
            (delta) => delta.text,
            'text',
            'xy',
          ),
          isA<CompletionToolCalled>(),
          isA<CompletionTextDelta>().having((delta) => delta.text, 'text', 'c'),
        ]);
        expect(sent.whereType<PullTurnCommand>(), hasLength(1));
      });

      test('hold one batch at most while the server is paused', () async {
        final events = await started();
        final received = <CompletionEvent>[];
        final subscription = events.listen(received.add);
        turn.add(const CompletionTextDelta('a'));
        await pumpEventQueue();
        subscription.pause();
        turn
          ..add(const CompletionTextDelta('b'))
          ..add(const CompletionTextDelta('c'));
        await pumpEventQueue();
        final pullsWhilePaused = sent.whereType<PullTurnCommand>().length;
        final receivedWhilePaused = [...received];

        subscription.resume();
        await pumpEventQueue();

        expect(pullsWhilePaused, 2);
        expect(receivedWhilePaused, hasLength(1));
        expect(sent.whereType<PullTurnCommand>(), hasLength(4));
        expect(
          [for (final event in received) (event as CompletionTextDelta).text],
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
          isA<CompletionFailed>().having(
            (failed) => failed.failure,
            'failure',
            CompletionFailure.engineFailed,
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
      final silent = RemoteModelEngine(
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
        (_) async =>
            CompletionStarted(StreamController<CompletionEvent>().stream),
      );
      final live = (await runtime.complete(_completion) as CompletionStarted)
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
        isA<CompletionFailed>().having(
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
