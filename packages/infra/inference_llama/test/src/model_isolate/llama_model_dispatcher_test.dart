import 'package:inference_llama/src/model_isolate/llama_model_dispatcher.dart';
import 'package:inference_llama/src/model_isolate/llama_model_events.dart';
import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/mocks.dart';

void main() {
  group('LlamaModelDispatcher', () {
    late MockLlamaClientApi client;
    late MockBestFitApi fit;
    late MockIsolateEventSink events;
    late LlamaModelDispatcher dispatcher;

    setUp(() {
      client = stubbedLlamaClient();
      fit = MockBestFitApi();
      events = MockIsolateEventSink();
      dispatcher = LlamaModelDispatcher(client: client, fit: fit);
    });

    LlamaModelResponse handle(LlamaModelRequest request) =>
        dispatcher.handle(request, events: events);

    LoadLlamaModelResponse load({
      int requestId = 0,
      String path = 'model.gguf',
      LlamaModelOptions options = const LlamaModelOptions(),
    }) {
      final response = handle(
        LoadLlamaModel(requestId: requestId, path: path, options: options),
      );
      return (response as LoadLlamaModelResponded).response;
    }

    List<double> emittedFractions({required int requestId}) {
      final emitted = verify(() => events.emit(captureAny())).captured;
      return [
        for (final event in emitted.cast<LlamaModelLoadProgressed>())
          if (event.requestId == requestId) event.fraction,
      ];
    }

    DisposeAllLlamaModelsResponse disposeAll() =>
        (handle(const DisposeAllLlamaModels())
                as DisposeAllLlamaModelsResponded)
            .response;

    test('loads a model and reports monotonic progress for the request', () {
      when(
        () => client.loadModel(
          modelPath: any(named: 'modelPath'),
          modelOptions: any(named: 'modelOptions'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) {
        final onProgress =
            invocation.namedArguments[#onProgress] as ModelLoadProgressCallback;
        [0.5, 0.4, 0.7, 1.0, 2.0].forEach(onProgress);
        return LlamaClientLoadModelSucceeded(fakeModelHandle);
      });

      final loaded = load(requestId: 7) as LoadLlamaModelSucceeded;

      expect(loaded.modelId, 1);
      expect(loaded.modelAddress, fakeModelHandle.pointerAddress);
      expect(emittedFractions(requestId: 7), [0, 0.5, 0.7, 1]);
    });

    test('reports a native load failure without holding a model', () {
      when(
        () => client.loadModel(
          modelPath: any(named: 'modelPath'),
          modelOptions: any(named: 'modelOptions'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenReturn(
        const LlamaClientLoadModelFailed(message: 'missing', stackTrace: 's'),
      );

      final failed = load() as LoadLlamaModelFailed;

      expect(failed.message, 'missing');
      expect(failed.stackTrace, 's');
      expect(
        disposeAll(),
        isA<DisposeAllLlamaModelsSucceeded>().having(
          (response) => response.disposedCount,
          'disposedCount',
          0,
        ),
      );
    });

    test('shares identical loads until the last holder disposes', () {
      final first = load() as LoadLlamaModelSucceeded;
      final second = load(requestId: 1) as LoadLlamaModelSucceeded;

      expect(second.modelId, first.modelId);
      expect(emittedFractions(requestId: 1), [1]);
      verify(
        () => client.loadModel(
          modelPath: 'model.gguf',
          modelOptions: any(named: 'modelOptions'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      expect(
        handle(DisposeLlamaModel(first.modelId)),
        isA<DisposeLlamaModelResponded>(),
      );
      verifyNever(() => client.disposeModel(any()));

      handle(DisposeLlamaModel(first.modelId));
      verify(() => client.disposeModel(fakeModelHandle)).called(1);
    });

    test('loads distinct options as distinct models', () {
      final first = load() as LoadLlamaModelSucceeded;
      final second =
          load(options: const LlamaModelOptions(nGpuLayers: 4))
              as LoadLlamaModelSucceeded;

      expect(second.modelId, isNot(first.modelId));
    });

    test('treats disposing an unknown model as done', () {
      final response = handle(const DisposeLlamaModel(42));

      expect(
        (response as DisposeLlamaModelResponded).response,
        isA<DisposeLlamaModelSucceeded>(),
      );
      verifyNever(() => client.disposeModel(any()));
    });

    test('keeps a model whose free throws so a retry can reach it', () {
      final loaded = load() as LoadLlamaModelSucceeded;
      when(() => client.disposeModel(any())).thenThrow(StateError('busy'));

      final failed = handle(DisposeLlamaModel(loaded.modelId));

      expect(
        (failed as DisposeLlamaModelResponded).response,
        isA<DisposeLlamaModelFailed>().having(
          (response) => response.message,
          'message',
          contains('busy'),
        ),
      );

      when(() => client.disposeModel(any())).thenReturn(null);
      final retried = handle(DisposeLlamaModel(loaded.modelId));

      expect(
        (retried as DisposeLlamaModelResponded).response,
        isA<DisposeLlamaModelSucceeded>(),
      );
      verify(() => client.disposeModel(fakeModelHandle)).called(2);
      expect(
        (disposeAll() as DisposeAllLlamaModelsSucceeded).disposedCount,
        0,
      );
    });

    test('disposes every held model at once', () {
      load();
      load(options: const LlamaModelOptions(nGpuLayers: 4));

      expect(
        (disposeAll() as DisposeAllLlamaModelsSucceeded).disposedCount,
        2,
      );
      verify(() => client.disposeModel(any())).called(2);
      expect(
        (disposeAll() as DisposeAllLlamaModelsSucceeded).disposedCount,
        0,
      );
    });

    test('reports a dispose-all whose free throws', () {
      load();
      when(() => client.disposeModel(any())).thenThrow(StateError('busy'));

      expect(disposeAll(), isA<DisposeAllLlamaModelsFailed>());
    });

    test('reads device info', () {
      const device = LlamaDeviceInfo(
        name: 'Metal',
        description: 'Apple M4',
        type: LlamaDeviceType.gpu,
        freeMemory: 1,
        totalMemory: 2,
      );
      when(client.getDeviceInfo).thenReturn(const [device]);

      final response = handle(const GetLlamaDeviceInfo());

      expect(
        ((response as GetLlamaDeviceInfoResponded).response
                as GetLlamaDeviceInfoSucceeded)
            .devices,
        [device],
      );
    });

    test('maps a native device info failure', () {
      when(client.getDeviceInfo).thenThrow(StateError('no devices'));

      final response = handle(const GetLlamaDeviceInfo());

      expect(
        (response as GetLlamaDeviceInfoResponded).response,
        isA<GetLlamaDeviceInfoFailed>(),
      );
    });

    test('forwards fit predictions to the predictor', () {
      const result = BestFitMaxContextResult(
        status: BestFitStatus.success,
        chosenContextSize: 4096,
        usedBytes: 1,
        freeBytes: 2,
        totalBytes: 3,
        nIterations: 2,
      );
      when(
        () => fit.fitMaxContext(
          modelPath: 'model.gguf',
          modelOptions: any(named: 'modelOptions'),
          contextOptions: fakeContextOptions,
          minContextSize: 1024,
          maxContextSize: 8192,
          headroomBytesByDevice: [64],
        ),
      ).thenReturn(result);

      final response = handle(
        const FitMaxLlamaModel(
          path: 'model.gguf',
          contextOptions: fakeContextOptions,
          minContextSize: 1024,
          maxContextSize: 8192,
          headroomBytesByDevice: [64],
        ),
      );

      expect(
        ((response as FitMaxLlamaModelResponded).response
                as FitMaxLlamaModelSucceeded)
            .result,
        same(result),
      );
    });

    test('maps a native fit failure', () {
      when(
        () => fit.fitMaxContext(
          modelPath: any(named: 'modelPath'),
          modelOptions: any(named: 'modelOptions'),
          contextOptions: any(named: 'contextOptions'),
          minContextSize: any(named: 'minContextSize'),
          maxContextSize: any(named: 'maxContextSize'),
          headroomBytesByDevice: any(named: 'headroomBytesByDevice'),
        ),
      ).thenThrow(StateError('predict failed'));

      final response = handle(
        const FitMaxLlamaModel(
          path: 'model.gguf',
          contextOptions: fakeContextOptions,
          minContextSize: 1024,
          maxContextSize: 8192,
          headroomBytesByDevice: [],
        ),
      );

      expect(
        (response as FitMaxLlamaModelResponded).response,
        isA<FitMaxLlamaModelFailed>(),
      );
    });

    test('maps a native load throw to a failed load', () {
      when(
        () => client.loadModel(
          modelPath: any(named: 'modelPath'),
          modelOptions: any(named: 'modelOptions'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(StateError('boom'));

      expect(
        load(),
        isA<LoadLlamaModelFailed>().having(
          (response) => response.message,
          'message',
          contains('boom'),
        ),
      );
    });
  });
}
