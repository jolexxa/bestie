import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/model/model.dart';
import 'package:inference_llama/src/models.dart';
import 'package:inference_llama/src/native/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/throwing_isolate_spawner.dart';

void main() {
  group('LlamaModelLoader', () {
    late MockLlamaClientApi client;
    late MockLlamaModelWorker worker;
    late StreamController<LlamaModelEvent> events;
    late LlamaModelLoader loader;

    setUp(() {
      client = stubbedLlamaClient();
      worker = MockLlamaModelWorker();
      events = StreamController<LlamaModelEvent>.broadcast(sync: true);
      addTearDown(events.close);
      when(() => worker.events).thenAnswer((_) => events.stream);
      when(worker.close).thenAnswer((_) async {});
      when(
        () => worker.send(any(that: isA<LoadLlamaModel>())),
      ).thenAnswer((_) async => _loaded);
      when(
        () => worker.send(any(that: isA<DisposeLlamaModel>())),
      ).thenAnswer(
        (_) async =>
            const DisposeLlamaModelResponded(DisposeLlamaModelSucceeded()),
      );
      when(() => worker.send(const DisposeAllLlamaModels())).thenAnswer(
        (_) async => const DisposeAllLlamaModelsResponded(
          DisposeAllLlamaModelsSucceeded(disposedCount: 0),
        ),
      );
      loader = LlamaModelLoader(worker: worker, client: client);
    });

    Future<LlamaModel> loadModel() async {
      final loaded = await loader.load(
        const LlamaModelLoadRequest(path: 'model.gguf'),
      );
      return (loaded as LlamaLoadModelSucceeded).model;
    }

    group('spawn', () {
      LlamaBackend backend() {
        final libraries = MockLlamaNativeLibraries();
        when(
          () => libraries.open(any()),
        ).thenReturn(DynamicLibrary.process());
        when(
          () => libraries.bind(any()),
        ).thenAnswer((_) => FakeLlamaCppBindings());
        return LlamaBackend.open(
          const LlamaBackendConfiguration(
            libraries: LlamaBackendLibraries(
              runtimeLibraryPath: '/bestie/no/such/libllama.so',
              commonLibraryPath: '/bestie/no/such/libcommon.so',
            ),
            disableMetalResidency: false,
          ),
          libraries: libraries,
        );
      }

      setUpAll(() {
        registerFallbackValue(DynamicLibrary.process());
        registerFallbackValue(DynamicLibrary.process().lookup);
      });

      test('reports a model isolate that fails to spawn', () async {
        final spawned = await LlamaModelLoader.spawn(
          backend(),
          isolateSpawner: const ThrowingIsolateSpawner(),
        );

        expect(
          spawned,
          isA<LlamaSpawnModelLoaderFailed>().having(
            (failure) => failure.message,
            'message',
            contains('spawn failed'),
          ),
        );
      });

      test(
        'spawns a model isolate whose native failures come back typed',
        () async {
          final spawned = await LlamaModelLoader.spawn(backend());
          final loader = (spawned as LlamaSpawnModelLoaderSucceeded).loader;

          final loaded = await loader.load(
            const LlamaModelLoadRequest(path: 'model.gguf'),
          );

          expect(loaded, isA<LlamaLoadModelFailed>());
          expect(await loader.close(), isA<LlamaModelLoaderClosed>());
        },
      );
    });

    group('load', () {
      test('hands back a model over the loaded pointer', () async {
        await loadModel();

        verify(() => client.modelHandleFromPointer(7)).called(1);
      });

      test('reports only its own request progress', () async {
        when(
          () => worker.send(any(that: isA<LoadLlamaModel>())),
        ).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.first as LoadLlamaModel;
          events
            ..add(
              LlamaModelLoadProgressed(
                requestId: request.requestId + 1,
                fraction: 0.9,
              ),
            )
            ..add(
              LlamaModelLoadProgressed(
                requestId: request.requestId,
                fraction: 0.5,
              ),
            );
          return _loaded;
        });
        final fractions = <double>[];

        await loader.load(
          const LlamaModelLoadRequest(path: 'model.gguf'),
          onProgress: fractions.add,
        );
        await loader.load(
          const LlamaModelLoadRequest(path: 'model.gguf'),
          onProgress: fractions.add,
        );

        expect(fractions, [0.5, 0.5]);
        final requestIds = verify(
          () => worker.send(captureAny(that: isA<LoadLlamaModel>())),
        ).captured.cast<LoadLlamaModel>().map((load) => load.requestId);
        expect(requestIds, [0, 1]);
      });

      test('maps a failed load', () async {
        when(() => worker.send(any(that: isA<LoadLlamaModel>()))).thenAnswer(
          (_) async => const LoadLlamaModelResponded(
            LoadLlamaModelFailed(message: 'missing', stackTrace: 's'),
          ),
        );

        final loaded = await loader.load(
          const LlamaModelLoadRequest(path: 'model.gguf'),
        );

        expect(
          loaded,
          isA<LlamaLoadModelFailed>()
              .having((failure) => failure.message, 'message', 'missing')
              .having((failure) => failure.stackTrace, 'stackTrace', 's'),
        );
      });

      test('maps an unexpected response', () async {
        when(
          () => worker.send(any(that: isA<LoadLlamaModel>())),
        ).thenAnswer((_) async => _unexpected);

        expect(
          await loader.load(const LlamaModelLoadRequest(path: 'model.gguf')),
          isA<LlamaLoadModelFailed>(),
        );
      });
    });

    group('getDeviceInfo', () {
      test('unwraps the devices', () async {
        const device = LlamaDeviceInfo(
          name: 'CPU',
          description: 'cpu',
          type: LlamaDeviceType.cpu,
          freeMemory: 1,
          totalMemory: 2,
        );
        when(() => worker.send(const GetLlamaDeviceInfo())).thenAnswer(
          (_) async => const GetLlamaDeviceInfoResponded(
            GetLlamaDeviceInfoSucceeded([device]),
          ),
        );

        final result = await loader.getDeviceInfo();

        expect((result as LlamaDeviceInfoSucceeded).devices, [device]);
      });

      test('maps failures and unexpected responses', () async {
        when(() => worker.send(const GetLlamaDeviceInfo())).thenAnswer(
          (_) async => const GetLlamaDeviceInfoResponded(
            GetLlamaDeviceInfoFailed(message: 'gone', stackTrace: 's'),
          ),
        );
        expect(
          await loader.getDeviceInfo(),
          isA<LlamaDeviceInfoFailed>().having(
            (failure) => failure.message,
            'message',
            'gone',
          ),
        );

        when(
          () => worker.send(const GetLlamaDeviceInfo()),
        ).thenAnswer((_) async => _unexpected);
        expect(await loader.getDeviceInfo(), isA<LlamaDeviceInfoFailed>());
      });
    });

    group('fitMaxContext', () {
      const request = LlamaFitMaxContextRequest(
        path: 'model.gguf',
        options: LlamaModelOptions(nGpuLayers: 3),
        contextOptions: fakeContextOptions,
        minContextSize: 1024,
        maxContextSize: 8192,
        headroomBytesByDevice: [64],
      );

      test('forwards the request and unwraps the result', () async {
        const result = BestFitMaxContextResult(
          status: BestFitStatus.success,
          chosenContextSize: 4096,
          usedBytes: 1,
          freeBytes: 2,
          totalBytes: 3,
          nIterations: 2,
        );
        when(() => worker.send(any(that: isA<FitMaxLlamaModel>()))).thenAnswer(
          (_) async => const FitMaxLlamaModelResponded(
            FitMaxLlamaModelSucceeded(result),
          ),
        );

        final fitted = await loader.fitMaxContext(request);

        expect((fitted as LlamaFitMaxContextSucceeded).result, same(result));
        final sent =
            verify(
                  () => worker.send(captureAny(that: isA<FitMaxLlamaModel>())),
                ).captured.single
                as FitMaxLlamaModel;
        expect(sent.path, 'model.gguf');
        expect(sent.options.nGpuLayers, 3);
        expect(sent.contextOptions, same(fakeContextOptions));
        expect(sent.minContextSize, 1024);
        expect(sent.maxContextSize, 8192);
        expect(sent.headroomBytesByDevice, [64]);
      });

      test('maps failures and unexpected responses', () async {
        when(() => worker.send(any(that: isA<FitMaxLlamaModel>()))).thenAnswer(
          (_) async => const FitMaxLlamaModelResponded(
            FitMaxLlamaModelFailed(message: 'no fit', stackTrace: 's'),
          ),
        );
        expect(
          await loader.fitMaxContext(request),
          isA<LlamaFitMaxContextFailed>().having(
            (failure) => failure.message,
            'message',
            'no fit',
          ),
        );

        when(
          () => worker.send(any(that: isA<FitMaxLlamaModel>())),
        ).thenAnswer((_) async => _unexpected);
        expect(
          await loader.fitMaxContext(request),
          isA<LlamaFitMaxContextFailed>(),
        );
      });
    });

    group('close', () {
      test('refuses while a model it handed out is undisposed', () async {
        await loadModel();

        expect(
          await loader.close(),
          isA<LlamaModelLoaderCloseRefused>().having(
            (refused) => refused.liveModels,
            'liveModels',
            1,
          ),
        );
        verifyNever(worker.close);
      });

      test('frees what the isolate holds, then closes it once', () async {
        final model = await loadModel();
        await model.dispose();

        expect(await loader.close(), isA<LlamaModelLoaderClosed>());
        expect(await loader.close(), isA<LlamaModelLoaderClosed>());

        verifyInOrder([
          () => worker.send(const DisposeAllLlamaModels()),
          worker.close,
        ]);
        verifyNever(() => worker.send(const DisposeAllLlamaModels()));
        verifyNever(worker.close);
      });
    });

    group('model', () {
      test('creates a context over its weights', () async {
        final model = await loadModel();
        when(
          () => client.readEnvelope(any()),
        ).thenReturn(fakeEnvelope(contextSize: 256));

        final created = await model.createContext(
          const LlamaCreateContextRequest(options: fakeContextOptions),
        );

        final context = (created as LlamaCreateContextSucceeded).context;
        expect(context.contextSize, 256);
        verify(
          () => client.createContext(any(), fakeContextOptions),
        ).called(1);
      });

      test('maps context creation failures and throws', () async {
        final model = await loadModel();
        when(() => client.createContext(any(), any())).thenReturn(
          const LlamaClientCreateContextFailed(message: 'oom', stackTrace: 's'),
        );
        expect(
          await model.createContext(
            const LlamaCreateContextRequest(options: fakeContextOptions),
          ),
          isA<LlamaCreateContextFailed>().having(
            (failure) => failure.message,
            'message',
            'oom',
          ),
        );

        when(
          () => client.createContext(any(), any()),
        ).thenThrow(StateError('native'));
        expect(
          await model.createContext(
            const LlamaCreateContextRequest(options: fakeContextOptions),
          ),
          isA<LlamaCreateContextFailed>().having(
            (failure) => failure.message,
            'message',
            contains('native'),
          ),
        );
      });

      test('refuses contexts once disposed and disposes once', () async {
        final model = await loadModel();

        expect(await model.dispose(), isA<ModelDisposed>());
        expect(await model.dispose(), isA<ModelDisposed>());
        expect(
          await model.createContext(
            const LlamaCreateContextRequest(options: fakeContextOptions),
          ),
          isA<LlamaCreateContextFailed>(),
        );
        verify(
          () => worker.send(
            any(
              that: isA<DisposeLlamaModel>().having(
                (request) => request.modelId,
                'modelId',
                1,
              ),
            ),
          ),
        ).called(1);
        verifyNever(() => client.createContext(any(), any()));
      });

      test('stays live when the isolate fails to free it', () async {
        final model = await loadModel();
        when(
          () => worker.send(any(that: isA<DisposeLlamaModel>())),
        ).thenAnswer(
          (_) async => const DisposeLlamaModelResponded(
            DisposeLlamaModelFailed(message: 'busy', stackTrace: 's'),
          ),
        );

        expect(
          await model.dispose(),
          isA<DisposeModelFailed>().having(
            (failure) => failure.message,
            'message',
            'busy',
          ),
        );
        expect(await loader.close(), isA<LlamaModelLoaderCloseRefused>());

        when(
          () => worker.send(any(that: isA<DisposeLlamaModel>())),
        ).thenAnswer((_) async => _unexpected);
        expect(await model.dispose(), isA<DisposeModelFailed>());
      });

      test('tokenizes and detokenizes in this isolate', () async {
        final model = await loadModel();
        when(
          () => client.tokenize(
            any(),
            'hi',
            addSpecial: false,
            parseSpecial: false,
          ),
        ).thenReturn(const LlamaClientTokenizeSucceeded([5, 6]));

        final tokenized = model.tokenizer.tokenize(
          const TokenizeRequest(
            text: 'hi',
            addSpecial: false,
            parseSpecial: false,
          ),
        );
        final detokenized = model.tokenizer.detokenize(
          const DetokenizeRequest(token: 9),
        );

        expect((tokenized as TokenizeSucceeded).tokens, [5, 6]);
        expect(tokenized.tokens, isA<Int64List>());
        expect((detokenized as DetokenizeSucceeded).bytes, [9]);
      });

      test('maps tokenization failures', () async {
        final model = await loadModel();
        when(
          () => client.tokenize(
            any(),
            any(),
            addSpecial: any(named: 'addSpecial'),
            parseSpecial: any(named: 'parseSpecial'),
          ),
        ).thenReturn(
          const LlamaClientTokenizeFailed(message: 'bad', stackTrace: 's'),
        );

        expect(
          model.tokenizer.tokenize(const TokenizeRequest(text: 'hi')),
          isA<TokenizeFailed>().having(
            (failure) => failure.message,
            'message',
            'bad',
          ),
        );
      });
    });
  });
}

const _loaded = LoadLlamaModelResponded(
  LoadLlamaModelSucceeded(modelId: 1, modelAddress: 7),
);

const _unexpected = DisposeAllLlamaModelsResponded(
  DisposeAllLlamaModelsSucceeded(disposedCount: 0),
);
