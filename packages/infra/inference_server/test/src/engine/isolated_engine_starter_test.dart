import 'dart:async';
import 'dart:isolate';

import 'package:inference_server/inference_server.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/index.dart';
import '../../helpers/mocks.dart';

const _request = ModelEngineRequest(entry: qwenEntry, maxAgents: 1);

enum _Behavior { serve, missing, refuse, crash }

/// Runs inside the engine isolate, so it holds nothing but plain data.
final class _FakeStarter implements ModelEngineStarter {
  const _FakeStarter(this.behavior, {this.payload});

  final _Behavior behavior;

  final Object? payload;

  @override
  Future<ModelEngineStart> start(ServerLog log) async {
    log
      ..info('starting')
      ..error('warming up');
    return switch (behavior) {
      _Behavior.serve => const ModelEngineStarted(_FakeEngine()),
      _Behavior.missing => const ModelEngineLibrariesMissing(
        message: 'no dylib',
      ),
      _Behavior.refuse => const ModelEngineFailedToStart(message: 'no loader'),
      _Behavior.crash => throw StateError('boom'),
    };
  }
}

/// Fits any model, then fails it; a model with no id stops the isolate.
final class _FakeEngine implements ModelEngine {
  const _FakeEngine();

  @override
  Stream<ModelEngineEvent> load(ModelEngineRequest request) {
    if (request.maxAgents > 1) Isolate.exit();
    return Stream.fromIterable(const [
      ModelEngineFitted(contextSize: 2048),
      ModelEngineFailed(reason: 'fake'),
    ]);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late MockServerLog log;

  setUp(() => log = MockServerLog());

  Future<ModelEngineStart> start(_Behavior behavior, {Object? payload}) =>
      IsolatedEngineStarter(
        _FakeStarter(behavior, payload: payload),
      ).start(log);

  test('runs the engine in its own isolate', () async {
    final engine = (await start(_Behavior.serve) as ModelEngineStarted).engine;

    final events = await engine.load(_request).toList();
    await engine.close();

    expect(events, [
      isA<ModelEngineFitted>().having(
        (fitted) => fitted.contextSize,
        'context size',
        2048,
      ),
      isA<ModelEngineFailed>().having(
        (failed) => failed.reason,
        'reason',
        'fake',
      ),
    ]);
    verify(() => log.info('starting')).called(1);
    verify(() => log.error('warming up')).called(1);
  });

  test('an engine isolate that dies fails what waits on it', () async {
    final engine = (await start(_Behavior.serve) as ModelEngineStarted).engine;

    final events = await engine
        .load(const ModelEngineRequest(entry: qwenEntry, maxAgents: 2))
        .toList();
    await engine.close();

    expect(events, [
      isA<ModelEngineFailed>().having(
        (failed) => failed.reason,
        'reason',
        'The engine stopped.',
      ),
    ]);
  });

  test('reports missing libraries', () async {
    expect(
      await start(_Behavior.missing),
      isA<ModelEngineLibrariesMissing>().having(
        (missing) => missing.message,
        'message',
        'no dylib',
      ),
    );
  });

  test('reports an engine that would not start', () async {
    expect(await start(_Behavior.refuse), isA<ModelEngineFailedToStart>());
  });

  test('reports an engine isolate that died while starting', () async {
    expect(
      await start(_Behavior.crash),
      isA<ModelEngineFailedToStart>().having(
        (failed) => failed.message,
        'message',
        'The engine stopped while starting.',
      ),
    );
    verify(
      () => log.error(any(that: contains('The engine broke'))),
    ).called(1);
  });

  test('reports an engine that cannot be sent to an isolate', () async {
    final port = ReceivePort();
    addTearDown(port.close);

    expect(
      await start(_Behavior.serve, payload: port),
      isA<ModelEngineFailedToStart>(),
    );
  });
}
