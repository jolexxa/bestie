import 'dart:ffi';
import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/model/llama_model_loader.dart';
import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/model_isolate/llama_model_worker.dart';
import 'package:inference_llama/src/native/best_fit_client.dart';
import 'package:inference_llama/src/native/llama_backend.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:inference_llama/src/native/llama_sampler_chain.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_bindings.dart';
import 'fake_llama_cpp_bindings_stubs.dart';

class MockLlamaClientApi extends Mock implements LlamaClientApi {}

class MockBestFitApi extends Mock implements BestFitApi {}

class MockLlamaModelWorker extends Mock implements LlamaModelWorker {}

class MockLlamaNativeLibraries extends Mock implements LlamaNativeLibraries {}

class MockIsolateEventSink extends Mock implements IsolateEventSink {}

final fakeModelHandle = LlamaModelHandle(
  pointer: Pointer.fromAddress(1),
  vocab: nullptr,
);

final fakeContextHandle = Pointer<llama_context>.fromAddress(2);

ContextEnvelope fakeEnvelope({
  int contextSize = 128,
  int maxSequences = 4,
  int maxBatchTokens = 8,
  bool isRecurrent = false,
}) => ContextEnvelope(
  contextSize: contextSize,
  perSequenceLimit: contextSize,
  maxSequences: maxSequences,
  maxBatchTokens: maxBatchTokens,
  microBatchTokens: maxBatchTokens,
  nSwa: 0,
  isRecurrent: isRecurrent,
);

const fakeContextOptions = LlamaContextOptions(
  contextSize: 128,
  nBatch: 8,
  nThreads: 1,
  nThreadsBatch: 1,
);

var _fallbacksRegistered = false;

void registerLlamaFallbacks() {
  if (_fallbacksRegistered) return;
  _fallbacksRegistered = true;
  registerFallbackValue(fakeModelHandle);
  registerFallbackValue(fakeContextHandle);
  registerFallbackValue(const LlamaModelOptions());
  registerFallbackValue(fakeContextOptions);
  registerFallbackValue(const EngineSampling());
  registerFallbackValue(<BatchEntry>[]);
  registerFallbackValue(Uint8List(0));
  registerFallbackValue(
    LlamaSamplerChain(FakeLlamaCppBindingsStubs(), nullptr),
  );
  registerFallbackValue(const DisposeAllLlamaModels());
}

/// A client whose every call succeeds with neutral values. Tests restub the
/// calls they exercise; samplers it hands out run over [bindings].
MockLlamaClientApi stubbedLlamaClient({FakeLlamaCppBindings? bindings}) {
  registerLlamaFallbacks();
  final samplerBindings = bindings ?? FakeLlamaCppBindings();
  final client = MockLlamaClientApi();
  when(
    () => client.loadModel(
      modelPath: any(named: 'modelPath'),
      modelOptions: any(named: 'modelOptions'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenReturn(LlamaClientLoadModelSucceeded(fakeModelHandle));
  when(() => client.modelHandleFromPointer(any())).thenAnswer(
    (invocation) => LlamaModelHandle(
      pointer: Pointer.fromAddress(invocation.positionalArguments.first as int),
      vocab: nullptr,
    ),
  );
  when(
    () => client.tokenize(
      any(),
      any(),
      addSpecial: any(named: 'addSpecial'),
      parseSpecial: any(named: 'parseSpecial'),
    ),
  ).thenReturn(const LlamaClientTokenizeSucceeded([1, 2]));
  when(
    () => client.createContext(any(), any()),
  ).thenReturn(LlamaClientCreateContextSucceeded(fakeContextHandle));
  when(() => client.readEnvelope(any())).thenReturn(fakeEnvelope());
  when(
    () => client.decodeBatch(any(), any()),
  ).thenReturn(const LlamaDecodeSucceeded());
  when(() => client.sampleAt(any(), any(), any())).thenReturn(1);
  when(() => client.sequencePositionMax(any(), any())).thenReturn(0);
  when(() => client.sequencePositionMin(any(), any())).thenReturn(0);
  when(
    () => client.removeSequenceRange(any(), any(), any(), any()),
  ).thenReturn(true);
  when(
    () => client.readSequenceCheckpoint(any(), any(), full: any(named: 'full')),
  ).thenAnswer((_) => Uint8List(0));
  when(
    () => client.writeSequenceCheckpoint(
      any(),
      any(),
      any(),
      full: any(named: 'full'),
    ),
  ).thenReturn(true);
  when(() => client.isEndOfGeneration(any(), any())).thenReturn(false);
  when(
    () => client.tokenToBytes(
      any(),
      any(),
      bufferSize: any(named: 'bufferSize'),
    ),
  ).thenAnswer(
    (invocation) =>
        Uint8List.fromList([invocation.positionalArguments[1] as int]),
  );
  when(() => client.createSampler(any(), any())).thenAnswer(
    (_) => LlamaSamplerChain(
      samplerBindings,
      samplerBindings.llama_sampler_chain_init(samplerBindings.chainParams),
    ),
  );
  when(client.getDeviceInfo).thenReturn(const []);
  return client;
}

/// Tokens the engine accepted into samplers, in order.
List<int> acceptedTokens(MockLlamaClientApi client) => verify(
  () => client.acceptToken(any(), captureAny()),
).captured.cast<int>();

/// A model loader whose worker answers every load with [modelAddress] and
/// every other request with success, so the models it hands out run over
/// [client] in this isolate.
LlamaModelLoader stubbedLlamaModelLoader({
  required LlamaClientApi client,
  required int modelAddress,
}) {
  registerLlamaFallbacks();
  final worker = MockLlamaModelWorker();
  when(() => worker.events).thenAnswer((_) => const Stream.empty());
  when(() => worker.send(any())).thenAnswer(
    (invocation) async => switch (invocation.positionalArguments.first) {
      LoadLlamaModel() => LoadLlamaModelResponded(
        LoadLlamaModelSucceeded(modelId: 1, modelAddress: modelAddress),
      ),
      _ => const DisposeLlamaModelResponded(DisposeLlamaModelSucceeded()),
    },
  );
  return LlamaModelLoader(worker: worker, client: client);
}
