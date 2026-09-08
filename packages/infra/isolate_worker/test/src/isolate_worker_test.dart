// Not required for test files
// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:isolate';

import 'package:isolate_worker/isolate_worker.dart';
import 'package:isolate_worker/src/isolate/isolate_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateWorker', () {
    test('spawns a worker and handles requests', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request.toUpperCase(),
        debugName: 'uppercase-worker',
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      addTearDown(worker.close);

      final response = await worker.send('cow');

      expect(response, isA<IsolateSucceeded<String>>());
      expect((response as IsolateSucceeded<String>).value, equals('COW'));
    });

    test('handles multiple active requests before closing', () async {
      final result = await IsolateWorker.spawn<int, int>(
        commandHandler: (request, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return request + 1;
        },
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      final first = worker.send(1);
      final second = worker.send(2);

      unawaited(worker.close());

      await expectLater(
        first,
        completion(
          isA<IsolateSucceeded<int>>().having((r) => r.value, 'value', 2),
        ),
      );
      await expectLater(
        second,
        completion(
          isA<IsolateSucceeded<int>>().having((r) => r.value, 'value', 3),
        ),
      );
    });

    test('reports remote failures', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (_, _) => throw StateError('boom'),
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      addTearDown(worker.close);

      final response = await worker.send('cow');

      expect(response, isA<IsolateRemoteFailed<String>>());
      final failure = response as IsolateRemoteFailed<String>;
      expect(failure.message, contains('boom'));
      expect(failure.stackTrace, isNotEmpty);
    });

    test('reports closed workers and only closes once', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      for (var i = 0; i < 2; i += 1) {
        unawaited(worker.close());
      }

      final response = await worker.send('cow');

      expect(response, isA<IsolateWorkerClosed<String>>());
      final failure = response as IsolateWorkerClosed<String>;
      expect(failure.message, equals('IsolateWorker is closed.'));
      expect(failure.stackTrace, isEmpty);
    });

    test('cancellable sends after close return closed runs', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      unawaited(worker.close());
      final run = worker.sendCancellable('cow')..cancel();
      final response = await run.result;

      expect(response, isA<IsolateWorkerClosed<String>>());
    });

    test('cancellation tokens expose cancellation state', () async {
      const never = NeverCancelledIsolateCancellationToken();
      var neverCompleted = false;
      unawaited(never.cancelled.then((_) => neverCompleted = true));

      expect(IsolateRequestContext.none.cancellationToken, same(never));
      expect(never.isCancellationRequested, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(neverCompleted, isFalse);

      final source = IsolateCancellationTokenSource();
      var completed = false;
      unawaited(source.token.cancelled.then((_) => completed = true));

      expect(source.token.isCancellationRequested, isFalse);
      source
        ..cancel()
        ..cancel();
      await source.token.cancelled;
      expect(source.token.isCancellationRequested, isTrue);
      expect(completed, isTrue);
    });

    test('ignores responses for inactive requests', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
        isolateSpawner: UnmatchedResponseIsolateSpawner(),
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };

      addTearDown(worker.close);

      await Future<void>.delayed(Duration.zero);
      unawaited(worker.close());

      final response = await worker.send('cow');

      expect(response, isA<IsolateWorkerClosed<String>>());
    });

    test('reports spawn failures', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
        isolateSpawner: ThrowingIsolateSpawner(),
      );

      expect(result, isA<IsolateSpawnFailed<String, String>>());
      final failure = result as IsolateSpawnFailed<String, String>;
      expect(failure.message, contains('spawn failed'));
      expect(failure.stackTrace, isNotEmpty);
    });

    test('force-kills a wedged isolate on close timeout', () async {
      final spawner = WedgedIsolateSpawner();
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
        isolateSpawner: spawner,
      );
      final worker = (result as IsolateSpawnSucceeded<String, String>).worker;

      await worker.close(timeout: const Duration(milliseconds: 20));

      expect(spawner.killed, isTrue);
    });

    test('closed worker resolves pending sends after a force-kill', () async {
      final spawner = WedgedIsolateSpawner();
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, _) => request,
        isolateSpawner: spawner,
      );
      final worker = (result as IsolateSpawnSucceeded<String, String>).worker;

      final pending = worker.send('cow');
      await worker.close(timeout: const Duration(milliseconds: 20));

      expect(await pending, isA<IsolateWorkerClosed<String>>());
    });

    test('delivers events pushed from the remote isolate', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, context) {
          context.events
            ..emit('event:$request')
            ..emit('event2:$request');
          return request.toUpperCase();
        },
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };
      addTearDown(worker.close);

      final events = <Object?>[];
      worker.events.listen(events.add);

      final response = await worker.send('cow');
      expect((response as IsolateSucceeded<String>).value, equals('COW'));

      await Future<void>.delayed(Duration.zero);
      expect(events, equals(<Object?>['event:cow', 'event2:cow']));
    });

    test('sends and receives objects', () async {
      final result = await IsolateWorker.spawn<int, int>(
        commandHandler: (request, _) => request * 2,
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };
      addTearDown(worker.close);

      final response = await worker.send(21);

      expect((response as IsolateSucceeded<int>).value, equals(42));
    });

    test('cancels active requests through the request context', () async {
      final result = await IsolateWorker.spawn<String, String>(
        commandHandler: (request, context) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return context.cancellationToken.isCancellationRequested
              ? 'cancelled:$request'
              : 'completed:$request';
        },
      );

      final worker = switch (result) {
        IsolateSpawnSucceeded(:final worker) => worker,
        IsolateSpawnFailed(:final message) => fail(message),
      };
      addTearDown(worker.close);

      final run = worker.sendCancellable('cow')..cancel();

      await expectLater(
        run.result,
        completion(
          isA<IsolateSucceeded<String>>().having(
            (result) => result.value,
            'value',
            'cancelled:cow',
          ),
        ),
      );
    });
  });
}

final class UnmatchedResponseIsolateSpawner implements IsolateSpawner {
  const UnmatchedResponseIsolateSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) async {
    final responses = (message as dynamic).$1 as SendPort;
    final commands = ReceivePort();

    commands.listen((_) {
      commands.close();
    });
    responses.send(commands.sendPort);
    scheduleMicrotask(() {
      // A response correlated to an id the host never issued must be dropped.
      responses.send(IsolateResponseSuccess(id: 7, payload: 'ignored'));
    });

    return _FakeSpawnedIsolate();
  }
}

final class ThrowingIsolateSpawner implements IsolateSpawner {
  const ThrowingIsolateSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) {
    throw StateError('spawn failed');
  }
}

final class WedgedIsolateSpawner implements IsolateSpawner {
  WedgedIsolateSpawner();

  _FakeSpawnedIsolate? _isolate;

  bool get killed => _isolate?.killed ?? false;

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) async {
    final responses = (message as dynamic).$1 as SendPort;
    final commands = ReceivePort()..listen((_) {});
    responses.send(commands.sendPort);
    return _isolate = _FakeSpawnedIsolate(autoExit: false);
  }
}

final class _FakeSpawnedIsolate implements SpawnedIsolate {
  _FakeSpawnedIsolate({bool autoExit = true}) {
    if (autoExit) _exit.complete();
  }

  final Completer<void> _exit = Completer<void>();
  bool killed = false;

  @override
  Future<void> get onExit => _exit.future;

  @override
  void kill() {
    killed = true;
    if (!_exit.isCompleted) _exit.complete();
  }

  @override
  void cleanup() {}
}
