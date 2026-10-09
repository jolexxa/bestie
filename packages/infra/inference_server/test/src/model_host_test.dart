import 'dart:async';

import 'package:file/memory.dart';
import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/index.dart';
import '../helpers/mocks.dart';

const _indexPath = '/bestie/models/index.json';

void main() {
  late MemoryFileSystem fileSystem;
  late MockModelEngine engine;
  late ModelHost host;
  late List<ModelStatus> statuses;

  setUpAll(() {
    registerFallbackValue(
      const ModelEngineRequest(entry: qwenEntry, maxAgents: 1),
    );
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    writeIndex(fileSystem, _indexPath, [qwenEntry, gemmaEntry]);
    engine = MockModelEngine();
    host = ModelHost(
      engine: engine,
      index: ModelIndexReader(fileSystem: fileSystem, path: _indexPath),
    );
    statuses = [];
    host.statusChanges.listen(statuses.add);
  });

  void engineLoads(List<ModelEngineEvent> events) {
    when(
      () => engine.load(any()),
    ).thenAnswer((_) => Stream.fromIterable(events));
  }

  test('starts unloaded', () {
    expect(host.status, isA<ModelUnloaded>());
    expect(host.hosted, isNull);
  });

  test('loads a model, reporting each stage', () async {
    final model = MockLoadedModel.serving(contextSize: 8192, maxAgents: 3);
    engineLoads([
      const ModelEngineFitted(contextSize: 8192),
      const ModelEngineProgressed(progress: 0.004),
      const ModelEngineProgressed(progress: 0.5),
      const ModelEngineProgressed(progress: 0.505),
      const ModelEngineProgressed(progress: 1),
      ModelEngineLoaded(model: model),
    ]);

    final outcome = await host.load(
      const ModelLoadRequest(
        localId: 'qwen3-1.7b',
        maxAgents: 3,
        contextCap: 9000,
      ),
    );

    expect(
      (outcome as ModelLoadSucceeded).ready,
      const ModelReady(
        localId: 'qwen3-1.7b',
        contextSize: 8192,
        maxAgents: 3,
        deviceBytes: 1234,
      ),
    );
    expect(statuses, [
      const ModelFitting(localId: 'qwen3-1.7b'),
      const ModelLoading(localId: 'qwen3-1.7b', progress: 0),
      const ModelLoading(localId: 'qwen3-1.7b', progress: 0.5),
      const ModelLoading(localId: 'qwen3-1.7b', progress: 1),
      outcome.ready,
    ]);
    expect(host.status, outcome.ready);
    expect(host.hosted?.entry, qwenEntry);
    expect(host.hosted?.model, same(model));
    final request =
        verify(() => engine.load(captureAny())).captured.single
            as ModelEngineRequest;
    expect(request.entry, qwenEntry);
    expect(request.maxAgents, 3);
    expect(request.contextCap, 9000);
  });

  test('refuses fewer than one agent', () async {
    expect(
      await host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 0),
      ),
      isA<ModelLoadRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        ModelLoadRejection.invalidRequest,
      ),
    );
  });

  test('refuses a context cap below one', () async {
    expect(
      await host.load(
        const ModelLoadRequest(
          localId: 'qwen3-1.7b',
          maxAgents: 1,
          contextCap: 0,
        ),
      ),
      isA<ModelLoadRejected>()
          .having(
            (rejected) => rejected.reason,
            'reason',
            ModelLoadRejection.invalidRequest,
          )
          .having(
            (rejected) => rejected.message,
            'message',
            'context_cap must be at least 1.',
          ),
    );
    verifyNever(() => engine.load(any()));
  });

  test('refuses a model the index does not list', () async {
    expect(
      await host.load(const ModelLoadRequest(localId: 'nope', maxAgents: 1)),
      isA<ModelLoadRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        ModelLoadRejection.unknownModel,
      ),
    );
  });

  test('refuses every model while no index exists', () async {
    fileSystem.file(_indexPath).deleteSync();

    expect(
      await host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
      ),
      isA<ModelLoadRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        ModelLoadRejection.unknownModel,
      ),
    );
  });

  test('refuses to load from an unreadable index', () async {
    fileSystem.file(_indexPath).writeAsStringSync('{');

    expect(
      await host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
      ),
      isA<ModelLoadRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        ModelLoadRejection.indexUnreadable,
      ),
    );
    verifyNever(() => engine.load(any()));
  });

  test('reports an engine failure', () async {
    engineLoads([const ModelEngineFailed(reason: 'out of memory')]);

    final outcome = await host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );

    expect(
      outcome,
      isA<ModelLoadFailed>().having(
        (failed) => failed.reason,
        'reason',
        'out of memory',
      ),
    );
    expect(
      host.status,
      const ModelFailed(localId: 'qwen3-1.7b', reason: 'out of memory'),
    );
    expect(host.hosted, isNull);
  });

  test('fails when the engine stops without a model', () async {
    engineLoads(const []);

    expect(
      await host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
      ),
      isA<ModelLoadFailed>(),
    );
  });

  test('reports an engine that breaks while loading', () async {
    when(() => engine.load(any())).thenAnswer(
      (_) => Stream.error(StateError('native crash')),
    );

    final outcome = await host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );

    expect(
      outcome,
      isA<ModelLoadFailed>().having(
        (failed) => failed.reason,
        'reason',
        contains('native crash'),
      ),
    );
    expect(host.status, isA<ModelFailed>());
  });

  test('reports an engine that refuses to start a load', () async {
    when(() => engine.load(any())).thenThrow(StateError('no engine'));

    expect(
      await host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
      ),
      isA<ModelLoadFailed>().having(
        (failed) => failed.reason,
        'reason',
        contains('no engine'),
      ),
    );
  });

  test('an unload that breaks does not hold up the next load', () async {
    final broken = MockLoadedModel.serving(contextSize: 1024, maxAgents: 1);
    when(broken.unload).thenThrow(StateError('stuck'));
    engineLoads([ModelEngineLoaded(model: broken)]);
    await host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );

    await expectLater(host.unload(), throwsStateError);
    final next = MockLoadedModel.serving(contextSize: 2048, maxAgents: 1);
    engineLoads([ModelEngineLoaded(model: next)]);

    expect(
      await host.load(const ModelLoadRequest(localId: 'gemma', maxAgents: 1)),
      isA<ModelLoadSucceeded>(),
    );
    expect(host.hosted?.model, same(next));
  });

  test('unloads the previous model before loading the next', () async {
    final first = MockLoadedModel.serving(contextSize: 1024, maxAgents: 1);
    final second = MockLoadedModel.serving(contextSize: 2048, maxAgents: 1);
    engineLoads([ModelEngineLoaded(model: first)]);
    await host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );
    engineLoads([ModelEngineLoaded(model: second)]);

    await host.load(const ModelLoadRequest(localId: 'gemma', maxAgents: 1));

    verifyInOrder([
      () => first.runtime.dispose(),
      first.unload,
      () => engine.load(any()),
    ]);
    expect(
      statuses,
      containsAllInOrder([isA<ModelUnloaded>(), isA<ModelFitting>()]),
    );
    expect(host.hosted?.entry, gemmaEntry);
  });

  test('runs loads and unloads in the order they were asked for', () async {
    final loading = StreamController<ModelEngineEvent>();
    final model = MockLoadedModel.serving(contextSize: 1024, maxAgents: 1);
    when(() => engine.load(any())).thenAnswer((_) => loading.stream);

    final load = host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );
    final unload = host.unload();
    await pumpEventQueue();
    verifyNever(model.unload);

    loading.add(ModelEngineLoaded(model: model));
    await load;
    await unload;

    verify(model.unload).called(1);
    expect(host.status, isA<ModelUnloaded>());
    await loading.close();
  });

  test('unloading with nothing loaded does nothing', () async {
    await host.unload();

    expect(statuses, isEmpty);
  });

  test('dispose abandons a load in flight', () async {
    var abandoned = false;
    final loading = StreamController<ModelEngineEvent>(
      onCancel: () => abandoned = true,
    );
    when(() => engine.load(any())).thenAnswer((_) => loading.stream);
    final load = host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );
    await pumpEventQueue();
    loading.add(const ModelEngineFitted(contextSize: 1024));
    await pumpEventQueue();

    await host.dispose();

    expect(abandoned, isTrue);
    expect(await load, isA<ModelLoadInterrupted>());
    expect(host.hosted, isNull);
    expect(host.status, isA<ModelUnloaded>());
  });

  test(
    'loads waiting behind dispose are interrupted without loading',
    () async {
      final disposed = host.dispose();
      final load = host.load(
        const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
      );
      await disposed;

      expect(await load, isA<ModelLoadInterrupted>());
      verifyNever(() => engine.load(any()));
    },
  );

  test('dispose unloads the model and ends status reports', () async {
    final model = MockLoadedModel.serving(contextSize: 1024, maxAgents: 1);
    engineLoads([ModelEngineLoaded(model: model)]);
    await host.load(
      const ModelLoadRequest(localId: 'qwen3-1.7b', maxAgents: 1),
    );
    final done = host.statusChanges.toList();

    await host.dispose();

    verify(model.unload).called(1);
    expect(await done, [isA<ModelUnloaded>()]);
  });
}
