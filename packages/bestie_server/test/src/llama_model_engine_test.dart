import 'dart:async';
import 'dart:ffi';

import 'package:bestie_server/bestie_server.dart';
import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference/inference.dart';
import 'package:inference_llama/inference_llama.dart';
import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockLoader extends Mock implements LlamaModelLoader {}

final class _MockModel extends Mock implements LlamaModel {}

final class _MockContext extends Mock implements Context {}

final class _MockSequences extends Mock implements Sequences {}

final class _MockClient extends Mock implements LlamaClientApi {}

final class _MockLog extends Mock implements ServerLog {}

const _entry = ModelIndexEntry(
  localId: 'qwen',
  path: '/models/qwen.gguf',
  displayName: 'Qwen',
  profileId: ModelProfileId.qwen3,
  architecture: 'qwen3',
  fileType: 'Q4_K_M',
  sizeBytes: 1,
  trainedContextLength: 32768,
  reasoning: ModelReasoningToggle(),
  defaultSampling: ModelSamplingDefaults(
    temperature: 0.6,
    topK: 20,
    topP: 0.95,
    minP: 0.05,
    penaltyRepeat: 1.1,
    penaltyLastN: 128,
  ),
  provenance: ModelScanned(root: '/models'),
  fingerprint: 'f',
);

const _devices = [
  LlamaDeviceInfo(
    name: 'MTL0',
    description: 'Apple GPU',
    type: LlamaDeviceType.gpu,
    freeMemory: 900,
    totalMemory: 1000,
  ),
  LlamaDeviceInfo(
    name: 'BLAS',
    description: 'BLAS',
    type: LlamaDeviceType.accelerator,
    freeMemory: 0,
    totalMemory: 0,
  ),
  LlamaDeviceInfo(
    name: 'iGPU',
    description: 'Integrated GPU',
    type: LlamaDeviceType.integratedGpu,
    freeMemory: 1500,
    totalMemory: 2000,
  ),
  LlamaDeviceInfo(
    name: 'CPU',
    description: 'CPU',
    type: LlamaDeviceType.cpu,
    freeMemory: 5000,
    totalMemory: 8000,
  ),
];

BestFitMaxContextResult _fit({
  BestFitStatus status = BestFitStatus.success,
  int chosen = 16384,
}) => BestFitMaxContextResult(
  status: status,
  chosenContextSize: chosen,
  usedBytes: 777,
  freeBytes: 2000,
  totalBytes: 3000,
  nIterations: 3,
  errorMessage: 'not enough',
);

ContextEnvelope _envelope({int perSequenceLimit = 16384}) => ContextEnvelope(
  contextSize: 16384,
  perSequenceLimit: perSequenceLimit,
  maxSequences: 3,
  maxBatchTokens: 512,
  microBatchTokens: 512,
  nSwa: 0,
);

void main() {
  late _MockLoader loader;
  late _MockModel model;
  late _MockContext context;
  late _MockSequences sequences;
  late _MockLog log;
  late int nativeCloses;
  late LlamaModelEngine engine;

  setUpAll(() {
    registerFallbackValue(
      const LlamaFitMaxContextRequest(
        path: '',
        contextOptions: LlamaContextOptions(
          contextSize: 1,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
        ),
        minContextSize: 1,
        maxContextSize: 1,
        headroomBytesByDevice: [],
      ),
    );
    registerFallbackValue(const LlamaModelLoadRequest(path: ''));
    registerFallbackValue(const SequenceRequest(sampling: EngineSampling()));
    registerFallbackValue(
      const LlamaCreateContextRequest(
        options: LlamaContextOptions(
          contextSize: 1,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
        ),
      ),
    );
  });

  setUp(() {
    loader = _MockLoader();
    model = _MockModel();
    context = _MockContext();
    sequences = _MockSequences();
    log = _MockLog();
    nativeCloses = 0;
    engine = LlamaModelEngine(
      loader: loader,
      threads: 6,
      log: log,
      closeNative: () async => nativeCloses++,
    );
    when(
      loader.getDeviceInfo,
    ).thenAnswer((_) async => const LlamaDeviceInfoSucceeded(_devices));
    when(
      () => loader.fitMaxContext(any()),
    ).thenAnswer((_) async => LlamaFitMaxContextSucceeded(_fit()));
    when(
      () => loader.load(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((invocation) async {
      final onProgress =
          invocation.namedArguments[#onProgress] as void Function(double);
      onProgress(0.5);
      onProgress(1);
      return LlamaLoadModelSucceeded(model);
    });
    when(
      () => model.createContext(any()),
    ).thenAnswer((_) async => LlamaCreateContextSucceeded(context));
    when(model.dispose).thenAnswer((_) async => const ModelDisposed());
    when(
      () => model.tokenizer,
    ).thenReturn(
      LlamaTokenization(
        client: _MockClient(),
        model: LlamaModelHandle(pointer: nullptr, vocab: nullptr),
      ),
    );
    when(() => context.envelope).thenReturn(_envelope());
    when(() => context.sequences).thenReturn(sequences);
    when(
      context.dispose,
    ).thenAnswer((_) async => const DisposeContextSucceeded());
  });

  Future<List<ModelEngineEvent>> load({
    ModelIndexEntry entry = _entry,
    int? contextCap,
  }) => engine
      .load(
        ModelEngineRequest(entry: entry, maxAgents: 3, contextCap: contextCap),
      )
      .toList();

  String failureOf(List<ModelEngineEvent> events) =>
      (events.last as ModelEngineFailed).reason;

  test('fits, loads, and serves a model', () async {
    final events = await load(contextCap: 20000);

    expect(events, [
      isA<ModelEngineFitted>().having(
        (fitted) => fitted.contextSize,
        'context',
        16384,
      ),
      isA<ModelEngineProgressed>().having(
        (progressed) => progressed.progress,
        'progress',
        0.5,
      ),
      isA<ModelEngineProgressed>(),
      isA<ModelEngineLoaded>(),
    ]);
    final loaded = (events.last as ModelEngineLoaded).model;
    expect(loaded.deviceBytes, 777);
    expect(loaded.runtime, isA<ScheduledCompletionRuntime>());
    expect(loaded.runtime.contextSize, 16384);
    expect(loaded.runtime.maxAgents, 3);

    final fit =
        verify(() => loader.fitMaxContext(captureAny())).captured.single
            as LlamaFitMaxContextRequest;
    expect(fit.path, '/models/qwen.gguf');
    expect(fit.maxContextSize, 20000);
    expect(fit.minContextSize, 2048);
    expect(fit.headroomBytesByDevice, [100, 200, 512 * 1024 * 1024]);
    final options = fit.contextOptions;
    expect(options.contextSize, 20000);
    expect(options.nBatch, 512);
    expect(options.nThreads, 6);
    expect(options.nThreadsBatch, 6);
    expect(options.useFlashAttn, isTrue);
    expect(options.maxSequences, 3);
    expect(options.useUnifiedKvCache, isTrue);
    expect(options.kvCacheType, LlamaKvCacheType.q8_0);
    expect(options.contextCheckpointCount, 4);

    final created =
        verify(() => model.createContext(captureAny())).captured.single
            as LlamaCreateContextRequest;
    expect(created.options, options.copyWith(contextSize: 16384));
    verify(() => log.info(any(that: contains('MTL0 (gpu)')))).called(1);
  });

  test("serves the model's sampling defaults", () async {
    when(() => sequences.acquire(any())).thenReturn(
      const RequestSequenceFailed(message: 'full', stackTrace: ''),
    );
    final events = await load();
    final runtime = (events.last as ModelEngineLoaded).model.runtime;

    await runtime.openPrimary('main');

    final request =
        verify(() => sequences.acquire(captureAny())).captured.single
            as SequenceRequest;
    expect(
      request.sampling,
      const EngineSampling(
        temperature: 0.6,
        topK: 20,
        topP: 0.95,
        minP: 0.05,
        penaltyRepeat: 1.1,
        penaltyLastN: 128,
      ),
    );
    await runtime.dispose();
  });

  test('fits up to the trained length without a cap', () async {
    await load();

    final fit =
        verify(() => loader.fitMaxContext(captureAny())).captured.single
            as LlamaFitMaxContextRequest;
    expect(fit.maxContextSize, 32768);
  });

  test('never fits past the trained length or below a small one', () async {
    await load(
      entry: _entry.copyWith(trainedContextLength: 1024),
      contextCap: 4096,
    );

    final fit =
        verify(() => loader.fitMaxContext(captureAny())).captured.single
            as LlamaFitMaxContextRequest;
    expect(fit.maxContextSize, 1024);
    expect(fit.minContextSize, 1024);
  });

  test('unloading frees the context, then the model', () async {
    final loaded = ((await load()).last as ModelEngineLoaded).model;

    await loaded.unload();

    verifyInOrder([context.dispose, model.dispose]);
  });

  test('fails when the devices cannot be read', () async {
    when(loader.getDeviceInfo).thenAnswer(
      (_) async =>
          const LlamaDeviceInfoFailed(message: 'no devices', stackTrace: ''),
    );

    expect(failureOf(await load()), 'no devices');
  });

  test('fails when the model does not fit', () async {
    when(() => loader.fitMaxContext(any())).thenAnswer(
      (_) async =>
          LlamaFitMaxContextSucceeded(_fit(status: BestFitStatus.failure)),
    );

    expect(
      failureOf(await load()),
      'The model does not fit in memory. not enough',
    );
    verifyNever(() => loader.load(any(), onProgress: any(named: 'onProgress')));
  });

  test('fails when fitting fails', () async {
    when(() => loader.fitMaxContext(any())).thenAnswer(
      (_) async =>
          const LlamaFitMaxContextFailed(message: 'bad file', stackTrace: ''),
    );

    expect(failureOf(await load()), 'bad file');
  });

  test('fails when the weights do not load', () async {
    when(
      () => loader.load(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer(
      (_) async =>
          const LlamaLoadModelFailed(message: 'corrupt', stackTrace: ''),
    );

    expect(failureOf(await load()), 'corrupt');
  });

  test('frees the model when its context cannot be made', () async {
    when(() => model.createContext(any())).thenAnswer(
      (_) async =>
          const LlamaCreateContextFailed(message: 'no memory', stackTrace: ''),
    );

    expect(failureOf(await load()), 'no memory');
    verify(model.dispose).called(1);
  });

  test('refuses a context whose KV cache is not unified', () async {
    when(
      () => context.envelope,
    ).thenReturn(_envelope(perSequenceLimit: 5461));

    expect(failureOf(await load()), contains('not unified'));
    verifyInOrder([context.dispose, model.dispose]);
  });

  test('reports a load that breaks as a failure', () async {
    when(loader.getDeviceInfo).thenThrow(StateError('ffi gone'));

    expect(failureOf(await load()), contains('ffi gone'));
  });

  test('does not start loading until listened to', () async {
    engine.load(const ModelEngineRequest(entry: _entry, maxAgents: 3));
    await pumpEventQueue();

    verifyNever(loader.getDeviceInfo);
  });

  test('a load abandoned once fitted never reads the weights', () async {
    late final StreamSubscription<ModelEngineEvent> subscription;
    subscription = engine
        .load(const ModelEngineRequest(entry: _entry, maxAgents: 3))
        .listen((event) {
          if (event is ModelEngineFitted) unawaited(subscription.cancel());
        });
    await pumpEventQueue();

    verifyNever(() => loader.load(any(), onProgress: any(named: 'onProgress')));
  });

  test('weights read after the load was abandoned are freed', () async {
    late final StreamSubscription<ModelEngineEvent> subscription;
    subscription = engine
        .load(const ModelEngineRequest(entry: _entry, maxAgents: 3))
        .listen((event) {
          if (event is ModelEngineProgressed) unawaited(subscription.cancel());
        });
    await pumpEventQueue();

    verify(model.dispose).called(1);
    verifyNever(() => model.createContext(any()));
  });

  test('a model built after its load was abandoned is unloaded', () async {
    final creating = Completer<LlamaCreateContextResult>();
    when(() => model.createContext(any())).thenAnswer((_) => creating.future);
    final subscription = engine
        .load(const ModelEngineRequest(entry: _entry, maxAgents: 3))
        .listen((_) {});
    await pumpEventQueue();

    await subscription.cancel();
    creating.complete(LlamaCreateContextSucceeded(context));
    await pumpEventQueue();

    verifyInOrder([context.dispose, model.dispose]);
  });

  test('close waits for a load in flight before freeing natives', () async {
    when(
      loader.close,
    ).thenAnswer((_) async => const LlamaModelLoaderClosed());
    final reading = Completer<LlamaLoadModelResult>();
    when(
      () => loader.load(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) => reading.future);
    final subscription = engine
        .load(const ModelEngineRequest(entry: _entry, maxAgents: 3))
        .listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();

    final closed = engine.close();
    await pumpEventQueue();
    verifyNever(loader.close);

    reading.complete(LlamaLoadModelSucceeded(model));
    await closed;

    verifyInOrder([model.dispose, loader.close]);
    expect(nativeCloses, 1);
    verifyNever(() => model.createContext(any()));
  });

  test('closes the loader, then the native libraries', () async {
    when(
      loader.close,
    ).thenAnswer((_) async => const LlamaModelLoaderClosed());

    await engine.close();

    verify(loader.close).called(1);
    expect(nativeCloses, 1);
  });

  test('reports models left loaded at shutdown', () async {
    when(
      loader.close,
    ).thenAnswer(
      (_) async => const LlamaModelLoaderCloseRefused(liveModels: 2),
    );

    await engine.close();

    verify(
      () => log.error('2 models were still loaded at shutdown.'),
    ).called(1);
    expect(nativeCloses, 1);
  });
}
