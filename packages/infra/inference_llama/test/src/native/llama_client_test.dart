import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:inference/inference.dart';
import 'package:inference_llama/src/native/native.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';

void main() {
  group('BatchEntry', () {
    test('compares by decoded batch fields', () {
      const entry = BatchEntry(token: 1, pos: 2, seqId: 3, logits: true);

      expect(
        entry,
        const BatchEntry(token: 1, pos: 2, seqId: 3, logits: true),
      );
      expect(
        entry == const BatchEntry(token: 1, pos: 2, seqId: 3, logits: false),
        isFalse,
      );
      expect(
        entry.hashCode,
        const BatchEntry(token: 1, pos: 2, seqId: 3, logits: true).hashCode,
      );
    });
  });

  group('LlamaClient', () {
    late FakeLlamaCppBindings bindings;

    setUp(() {
      bindings = FakeLlamaCppBindings();
    });

    test('tokenize reallocates when needed and returns tokens', () {
      var call = 0;
      bindings.tokenizeImpl =
          (
            _,
            _,
            _,
            tokens,
            _,
            _,
            _,
          ) {
            call += 1;
            if (call == 1) return -3;
            tokens[0] = 1;
            tokens[1] = 2;
            tokens[2] = 3;
            return 3;
          };

      final client = _client(bindings);
      final model = _model(client);

      final result = client.tokenize(model, 'hi');
      expect(result, isA<LlamaClientTokenizeSucceeded>());
      expect((result as LlamaClientTokenizeSucceeded).tokens, [1, 2, 3]);
    });

    test('tokenize returns a failure when tokenization fails twice', () {
      bindings.tokenizeImpl =
          (
            _,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => -2;

      final client = _client(bindings);
      final model = _model(client);

      final result = client.tokenize(model, 'hi');
      expect(result, isA<LlamaClientTokenizeFailed>());
      expect((result as LlamaClientTokenizeFailed).message, contains('need 2'));
    });

    test('tokenToBytes returns bytes for valid tokens', () {
      bindings.tokenToPieceImpl =
          (
            _,
            _,
            buf,
            _,
            _,
            _,
          ) {
            final bytes = 'ok'.codeUnits;
            for (var i = 0; i < bytes.length; i += 1) {
              buf.cast<Uint8>()[i] = bytes[i];
            }
            return bytes.length;
          };

      final client = _client(bindings);
      final model = _model(client);

      final bytes = client.tokenToBytes(model, 1);
      expect(bytes, 'ok'.codeUnits);
    });

    test('tokenToBytes returns empty when conversion fails', () {
      bindings.tokenToPieceImpl =
          (
            _,
            _,
            _,
            _,
            _,
            _,
          ) => -1;

      final client = _client(bindings);
      final model = _model(client);

      final bytes = client.tokenToBytes(model, 1);
      expect(bytes, isEmpty);
    });

    test('createContext applies flash attention options', () {
      bindings.contextParams = calloc<llama_context_params>().ref;

      final client = _client(bindings);
      final model = _model(client);

      client.createContext(
        model,
        const LlamaContextOptions(
          contextSize: 8,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
          maxSequences: 3,
          useFlashAttn: true,
          useUnifiedKvCache: true,
        ),
      );

      expect(bindings.contextParams.n_seq_max, 3);
      expect(bindings.contextParams.kv_unified, isTrue);
      expect(bindings.contextParams.n_ubatch, 1, reason: 'defaults to nBatch');
      expect(
        bindings.contextParams.flash_attn_typeAsInt,
        llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_ENABLED.value,
      );
    });

    test('createContext applies an explicit micro-batch size', () {
      bindings.contextParams = calloc<llama_context_params>().ref;

      final client = _client(bindings);
      final model = _model(client);

      client.createContext(
        model,
        const LlamaContextOptions(
          contextSize: 8,
          nBatch: 4,
          nThreads: 1,
          nThreadsBatch: 1,
          microBatchSize: 2,
        ),
      );

      expect(bindings.contextParams.n_batch, 4);
      expect(bindings.contextParams.n_ubatch, 2);
    });

    test('readEnvelope reads the real limits from the context', () {
      bindings.contextParams = calloc<llama_context_params>().ref
        ..n_ctx = 4096
        ..n_seq_max = 8
        ..n_batch = 512
        ..n_ubatch = 256;

      final client = _client(bindings);
      final envelope = client.readEnvelope(
        Pointer<llama_context>.fromAddress(1),
      );

      expect(envelope.contextSize, 4096);
      expect(envelope.perSequenceLimit, 4096);
      expect(envelope.maxSequences, 8);
      expect(envelope.maxBatchTokens, 512);
      expect(envelope.microBatchTokens, 256);
      expect(envelope.isRecurrent, isFalse);
    });

    test('readEnvelope flags recurrent and hybrid models as recurrent', () {
      ContextEnvelope read() {
        bindings.contextParams = calloc<llama_context_params>().ref;
        return _client(
          bindings,
        ).readEnvelope(Pointer<llama_context>.fromAddress(1));
      }

      bindings
        ..isRecurrent = true
        ..isHybrid = false;
      expect(read().isRecurrent, isTrue, reason: 'pure recurrent (Mamba/RWKV)');

      bindings
        ..isRecurrent = false
        ..isHybrid = true;
      expect(
        read().isRecurrent,
        isTrue,
        reason: 'hybrid recurrent (Qwen3.5 Gated DeltaNet)',
      );
    });

    test('createContext applies flash attention disabled', () {
      bindings.contextParams = calloc<llama_context_params>().ref;

      final client = _client(bindings);
      final model = _model(client);

      client.createContext(
        model,
        const LlamaContextOptions(
          contextSize: 8,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
          useFlashAttn: false,
        ),
      );

      expect(
        bindings.contextParams.flash_attn_typeAsInt,
        llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_DISABLED.value,
      );
    });

    test('loadModel applies model options', () {
      LlamaClient(bindings: bindings).loadModel(
        modelPath: 'model',
        modelOptions: const LlamaModelOptions(),
      );

      final client = LlamaClient(bindings: bindings);
      final result = client.loadModel(
        modelPath: 'model',
        modelOptions: LlamaModelOptions(
          nGpuLayers: 7,
          mainGpu: 1,
          loadMode: LlamaLoadMode.mmapMlock,
          checkTensors: true,
          numa: ggml_numa_strategy.GGML_NUMA_STRATEGY_DISTRIBUTE.value,
        ),
      );
      final model = (result as LlamaClientLoadModelSucceeded).handle;

      expect(bindings.backendInitCalls, 0);
      expect(bindings.llamaLogSetCalls, 0);
      expect(bindings.ggmlLogSetCalls, 0);
      expect(
        bindings.lastNumaInit?.value,
        ggml_numa_strategy.GGML_NUMA_STRATEGY_DISTRIBUTE.value,
      );
      expect(bindings.modelParams.n_gpu_layers, 7);
      expect(bindings.modelParams.main_gpu, 1);
      expect(
        bindings.modelParams.load_mode,
        llama_load_mode.LLAMA_LOAD_MODE_MMAP_MLOCK,
      );
      expect(bindings.modelParams.check_tensors, isTrue);
      expect(model.pointer, isNot(equals(nullptr)));
    });

    test('loadModel returns a failure when model fails to load', () {
      bindings.modelPtr = nullptr;

      final client = LlamaClient(bindings: bindings);
      final result = client.loadModel(
        modelPath: 'missing',
        modelOptions: const LlamaModelOptions(),
      );

      expect(result, isA<LlamaClientLoadModelFailed>());
      expect(
        (result as LlamaClientLoadModelFailed).message,
        contains('missing'),
      );
    });

    test(
      'getDeviceInfo returns an empty list when no devices are registered',
      () {
        final client = _client(bindings);

        expect(client.getDeviceInfo(), isEmpty);
      },
    );

    test('getDeviceInfo maps backend devices to Bestie device info', () {
      bindings.fakeDevices.addAll(const [
        FakeLlamaDevice(
          name: 'CPU',
          description: 'Apple silicon CPU',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_CPU,
          freeMemory: 16000000000,
          totalMemory: 32000000000,
          deviceId: 'cpu-0',
        ),
        FakeLlamaDevice(
          name: 'Metal',
          description: 'Apple M3 Max',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_GPU,
          freeMemory: 8000000000,
          totalMemory: 16000000000,
          deviceId: 'mtl-0',
        ),
        FakeLlamaDevice(
          name: 'iGPU',
          description: 'Integrated graphics',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_IGPU,
          freeMemory: 1000000000,
          totalMemory: 2000000000,
          deviceId: 'igpu-0',
        ),
        FakeLlamaDevice(
          name: 'AMX',
          description: 'Apple matrix accelerator',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_ACCEL,
          freeMemory: 0,
          totalMemory: 0,
        ),
        FakeLlamaDevice(
          name: 'Meta',
          description: 'Tensor parallel meta device',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_META,
          freeMemory: 0,
          totalMemory: 0,
          deviceId: 'meta-0',
        ),
      ]);

      final devices = _client(bindings).getDeviceInfo();

      expect(devices, hasLength(5));
      expect(devices[0].type, LlamaDeviceType.cpu);
      expect(devices[0].name, 'CPU');
      expect(devices[0].deviceId, 'cpu-0');
      expect(devices[1].type, LlamaDeviceType.gpu);
      expect(devices[1].totalMemory, 16000000000);
      expect(devices[2].type, LlamaDeviceType.integratedGpu);
      expect(devices[3].type, LlamaDeviceType.accelerator);
      expect(devices[3].deviceId, isNull);
      expect(devices[4].type, LlamaDeviceType.meta);
    });

    test('getDeviceInfo clamps free memory into the total range', () {
      bindings.fakeDevices.addAll(const [
        // Underflowed free (ggml computed budget - usage with usage > budget),
        // which arrives read back as a negative size_t.
        FakeLlamaDevice(
          name: 'Vulkan0',
          description: 'AMD Radeon 8060S',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_IGPU,
          freeMemory: -10000000000,
          totalMemory: 56000000000,
          deviceId: 'vk-0',
        ),
        // Free reported above total (budget larger than the heap size).
        FakeLlamaDevice(
          name: 'GPU1',
          description: 'Discrete GPU',
          type: ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_GPU,
          freeMemory: 30000000000,
          totalMemory: 24000000000,
          deviceId: 'gpu-1',
        ),
      ]);

      final devices = _client(bindings).getDeviceInfo();

      expect(devices[0].freeMemory, 0);
      expect(devices[0].totalMemory, 56000000000);
      expect(devices[1].freeMemory, 24000000000);
    });

    test(
      'decodeBatch returns a failure when llama_decode returns non-zero',
      () {
        bindings.decodeImpl = (_, _) => decodeKvSlotUnavailableBackendCode;

        final client = _client(bindings);
        final context = Pointer<llama_context>.fromAddress(1);

        final result = client.decodeBatch(context, const [
          BatchEntry(token: 1, pos: 0, seqId: 0, logits: true),
        ]);
        expect(result, isA<LlamaDecodeFailed>());
        expect(
          (result as LlamaDecodeFailed).backendCode,
          decodeKvSlotUnavailableBackendCode,
        );
      },
    );

    test('decodeBatch is a no-op for empty entry lists', () {
      final client = _client(bindings);
      final context = Pointer<llama_context>.fromAddress(1);

      final result = client.decodeBatch(context, const []);
      expect(bindings.decodeCalls, 0);
      expect(result, isA<LlamaDecodeSucceeded>());
    });

    test('createContext returns a failure when context creation fails', () {
      bindings.newContextImpl = (_, _) => nullptr;

      final client = _client(bindings);
      final model = _model(client);

      final result = client.createContext(
        model,
        const LlamaContextOptions(
          contextSize: 8,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
        ),
      );

      expect(result, isA<LlamaClientCreateContextFailed>());
    });

    test('disposeContext and disposeModel free separate resources', () {
      final client = LlamaClient(bindings: bindings);
      final loaded = client.loadModel(
        modelPath: 'model',
        modelOptions: const LlamaModelOptions(),
      );
      final model = (loaded as LlamaClientLoadModelSucceeded).handle;
      final context = Pointer<llama_context>.fromAddress(99);

      client.disposeContext(context);
      expect(bindings.freeCalls, 1);

      client.disposeModel(model);
      expect(bindings.freeCalls, 1);
      expect(bindings.freeModelCalls, 1);
      expect(bindings.backendFreeCalls, 0);
    });

    test('sampler chain adds expected samplers for greedy and temp modes', () {
      final greedy = LlamaSamplerChain.build(
        bindings,
        const EngineSampling(
          seed: 0,
          temperature: 0,
          topK: 10,
          topP: 0.9,
          minP: 0.2,
          typicalP: 0.8,
          penaltyRepeat: 1.2,
          penaltyLastN: 32,
        ),
        vocabularySize: 32000,
      );
      expect(bindings.samplerChainAddCalls, 6);
      greedy.dispose();
      expect(bindings.samplerFreeCalls, 1);

      bindings
        ..samplerChainAddCalls = 0
        ..samplerFreeCalls = 0;

      final temp = LlamaSamplerChain.build(
        bindings,
        const EngineSampling(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          minP: 0.05,
          typicalP: 1,
          penaltyRepeat: 1.1,
          penaltyLastN: 64,
          seed: 7,
        ),
        vocabularySize: 32000,
      );
      expect(bindings.samplerChainAddCalls, 6);
      temp.dispose();
      expect(bindings.samplerFreeCalls, 1);
    });

    test('loadModel with progress callback sets up native callback', () {
      final progressValues = <double>[];
      final client = LlamaClient(bindings: bindings);

      final result = client.loadModel(
        modelPath: 'model',
        modelOptions: const LlamaModelOptions(),
        onProgress: progressValues.add,
      );
      final model = (result as LlamaClientLoadModelSucceeded).handle;

      // The callback is set up even if not invoked during test.
      expect(model.pointer, isNot(equals(nullptr)));
    });

    test('sampleAt delegates to the sampler with batch index', () {
      bindings.samplerSampleResult = 99;

      final client = _client(bindings);
      final context = Pointer<llama_context>.fromAddress(2);

      final sampler = LlamaSamplerChain.build(
        bindings,
        const EngineSampling(seed: 0),
        vocabularySize: 32000,
      );

      final value = client.sampleAt(context, sampler, 3);
      expect(value, 99);
      expect(bindings.samplerSampleCalls, 1);
      sampler.dispose();
    });

    test('sampler clone and reset delegate to llama sampler APIs', () {
      final sampler = LlamaSamplerChain.build(
        bindings,
        const EngineSampling(seed: 0),
        vocabularySize: 32000,
      );

      sampler.clone()
        ..reset()
        ..dispose();
      sampler.dispose();

      expect(bindings.samplerCloneCalls, 1);
      expect(bindings.samplerResetCalls, 1);
      expect(bindings.samplerFreeCalls, 2);
    });

    test('createSampler sizes penalties by the model vocabulary', () {
      bindings.vocabularySize = 151936;
      final client = _client(bindings);

      client
          .createSampler(
            _model(client),
            const EngineSampling(penaltyRepeat: 1.1),
          )
          .dispose();

      expect(bindings.lastPenaltiesVocabularySize, 151936);
    });

    test('sampler chain falls back to the documented defaults', () {
      LlamaSamplerChain.build(
        bindings,
        const EngineSampling(),
        vocabularySize: 32000,
      ).dispose();

      expect(bindings.lastTopK, EngineSampling.defaultTopK);
      expect(bindings.lastTemperature, EngineSampling.defaultTemperature);
      expect(bindings.lastPenaltiesVocabularySize, isNull);
      expect(bindings.lastDistSeed, LLAMA_DEFAULT_SEED);
    });

    test('a zero seed asks llama.cpp for a random seed', () {
      LlamaSamplerChain.build(
        bindings,
        const EngineSampling(seed: 0),
        vocabularySize: 32000,
      ).dispose();

      expect(bindings.lastDistSeed, LLAMA_DEFAULT_SEED);
    });

    test('an explicit seed reaches the distribution sampler', () {
      LlamaSamplerChain.build(
        bindings,
        const EngineSampling(seed: 7),
        vocabularySize: 32000,
      ).dispose();

      expect(bindings.lastDistSeed, 7);
    });

    test('pointerAddress returns model address', () {
      final client = _client(bindings);
      final model = _model(client);

      expect(model.pointerAddress, model.pointer.address);
    });
  });
}

LlamaClient _client(FakeLlamaCppBindings bindings) =>
    LlamaClient(bindings: bindings);

LlamaModelHandle _model(LlamaClient client) {
  final result = client.loadModel(
    modelPath: 'model',
    modelOptions: const LlamaModelOptions(),
  );
  return (result as LlamaClientLoadModelSucceeded).handle;
}
