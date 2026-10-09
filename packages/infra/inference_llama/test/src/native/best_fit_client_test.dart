// Native llama bindings use generated C names.
// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:inference_llama/src/native/native.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';
import '../../fixtures/fake_llama_cpp_bindings_stubs.dart';

void main() {
  group('BestFitClient', () {
    test('fitMaxContext applies model and context options', () {
      final common = _FakeBestFitBindings();
      BestFitClient(
        llamaBindings: FakeLlamaCppBindings(),
        commonBindings: common,
      ).fitMaxContext(
        modelPath: '/models/qwen.gguf',
        modelOptions: const LlamaModelOptions(
          nGpuLayers: 12,
          mainGpu: 1,
          loadMode: LlamaLoadMode.mmapMlock,
          checkTensors: true,
        ),
        contextOptions: const LlamaContextOptions(
          contextSize: 8192,
          nBatch: 1024,
          nThreads: 6,
          nThreadsBatch: 8,
          maxSequences: 3,
          useFlashAttn: true,
          useUnifiedKvCache: true,
        ),
        minContextSize: 2048,
        maxContextSize: 8192,
        headroomBytesByDevice: const [100, 200],
      );

      expect(common.lastModelPath, '/models/qwen.gguf');
      expect(common.lastModelParams!.n_gpu_layers, 12);
      expect(common.lastModelParams!.main_gpu, 1);
      expect(
        common.lastModelParams!.load_mode,
        llama_load_mode.LLAMA_LOAD_MODE_MMAP_MLOCK,
      );
      expect(common.lastModelParams!.check_tensors, isTrue);
      expect(common.lastContextParams!.n_ctx, 8192);
      expect(common.lastContextParams!.n_batch, 1024);
      expect(common.lastContextParams!.n_ubatch, 1024);
      expect(common.lastContextParams!.n_threads, 6);
      expect(common.lastContextParams!.n_threads_batch, 8);
      expect(common.lastContextParams!.n_seq_max, 3);
      expect(common.lastContextParams!.kv_unified, isTrue);
      expect(
        common.lastContextParams!.flash_attn_typeAsInt,
        llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_ENABLED.value,
      );
    });

    test('fitMaxContext disables flash attention and defaults headroom', () {
      final common = _FakeBestFitBindings();
      BestFitClient(
        llamaBindings: FakeLlamaCppBindings(),
        commonBindings: common,
      ).fitMaxContext(
        modelPath: '/models/qwen.gguf',
        modelOptions: const LlamaModelOptions(),
        contextOptions: const LlamaContextOptions(
          contextSize: 4096,
          nBatch: 512,
          nThreads: 4,
          nThreadsBatch: 4,
          useFlashAttn: false,
        ),
        minContextSize: 2048,
        maxContextSize: 4096,
        headroomBytesByDevice: const [],
      );

      expect(
        common.lastContextParams!.flash_attn_typeAsInt,
        llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_DISABLED.value,
      );
      expect(common.lastHeadroom, everyElement(0));
    });

    test('fitMaxContext maps native errors and messages', () {
      final common = _FakeBestFitBindings()
        ..maxContextResult = _maxContextResult(
          status: best_fit_status.BEST_FIT_STATUS_ERROR,
          errorMessage: 'failed to load model',
        );
      final fit = BestFitClient(
        llamaBindings: FakeLlamaCppBindings(),
        commonBindings: common,
      );

      final result = fit.fitMaxContext(
        modelPath: '/missing.gguf',
        modelOptions: const LlamaModelOptions(),
        contextOptions: const LlamaContextOptions(
          contextSize: 1,
          nBatch: 1,
          nThreads: 1,
          nThreadsBatch: 1,
        ),
        minContextSize: 1,
        maxContextSize: 1,
        headroomBytesByDevice: const [0],
      );

      expect(result.status, BestFitStatus.error);
      expect(result.fits, isFalse);
      expect(result.errorMessage, 'failed to load model');
    });

    test('fitMaxContext maps native max context result', () {
      final common = _FakeBestFitBindings()
        ..maxContextResult = _maxContextResult(
          chosenContext: 16384,
          iterations: 4,
          prediction: _prediction(
            nDevices: 1,
            devices: [
              _device(free: 2000, total: 4000, used: 1200),
              _device(free: 3000, total: 6000, used: 700),
            ],
          ),
        );
      final fit = BestFitClient(
        llamaBindings: FakeLlamaCppBindings(),
        commonBindings: common,
      );

      final result = fit.fitMaxContext(
        modelPath: '/models/qwen.gguf',
        modelOptions: const LlamaModelOptions(nGpuLayers: -1),
        contextOptions: const LlamaContextOptions(
          contextSize: 32768,
          nBatch: 512,
          nThreads: 4,
          nThreadsBatch: 4,
          maxSequences: 2,
        ),
        minContextSize: 2048,
        maxContextSize: 32768,
        headroomBytesByDevice: const [256, 512],
      );

      expect(result.status, BestFitStatus.success);
      expect(result.fits, isTrue);
      expect(result.chosenContextSize, 16384);
      expect(result.usedBytes, 1900);
      expect(result.freeBytes, 5000);
      expect(result.totalBytes, 10000);
      expect(result.nIterations, 4);
      expect(common.lastMinContextSize, 2048);
      expect(common.lastMaxContextSize, 32768);
      expect(common.lastHeadroom[0], 256);
      expect(common.lastHeadroom.skip(1), everyElement(512));
      expect(common.lastContextParams!.n_seq_max, 2);
    });

    test('fitMaxContext maps native minimum-fit failures', () {
      final common = _FakeBestFitBindings()
        ..maxContextResult = _maxContextResult(
          status: best_fit_status.BEST_FIT_STATUS_FAILURE,
          iterations: 1,
          errorMessage: 'model does not fit',
          prediction: _prediction(
            status: best_fit_status.BEST_FIT_STATUS_FAILURE,
          ),
        );
      final fit = BestFitClient(
        llamaBindings: FakeLlamaCppBindings(),
        commonBindings: common,
      );

      final result = fit.fitMaxContext(
        modelPath: '/models/qwen.gguf',
        modelOptions: const LlamaModelOptions(),
        contextOptions: const LlamaContextOptions(
          contextSize: 4096,
          nBatch: 512,
          nThreads: 4,
          nThreadsBatch: 4,
        ),
        minContextSize: 2048,
        maxContextSize: 4096,
        headroomBytesByDevice: const [0],
      );

      expect(result.status, BestFitStatus.failure);
      expect(result.fits, isFalse);
      expect(result.errorMessage, 'model does not fit');
    });
  });
}

final class _FakeBestFitBindings extends FakeLlamaCppBindingsStubs {
  best_fit_max_ctx_result? maxContextResult;
  String? lastModelPath;
  llama_model_params? lastModelParams;
  llama_context_params? lastContextParams;
  int? lastMinContextSize;
  int? lastMaxContextSize;
  List<int> lastHeadroom = const [];

  @override
  best_fit_max_ctx_result best_fit_max_ctx(
    Pointer<Char> pathModel,
    Pointer<llama_model_params> modelParams,
    Pointer<llama_context_params> contextParams,
    Pointer<Size> headroomPerDevice,
    int minContextSize,
    int maxContextSize,
  ) {
    lastModelPath = pathModel.cast<Utf8>().toDartString();
    lastModelParams = _copyModelParams(modelParams.ref);
    lastContextParams = _copyContextParams(contextParams.ref);
    lastMinContextSize = minContextSize;
    lastMaxContextSize = maxContextSize;
    lastHeadroom = [
      for (var i = 0; i <= BEST_FIT_MAX_DEVICES; i += 1) headroomPerDevice[i],
    ];
    return maxContextResult ?? _maxContextResult();
  }
}

llama_model_params _copyModelParams(llama_model_params source) {
  final ptr = calloc<llama_model_params>()..ref = source;
  return ptr.ref;
}

llama_context_params _copyContextParams(llama_context_params source) {
  final ptr = calloc<llama_context_params>()..ref = source;
  return ptr.ref;
}

best_fit_prediction _prediction({
  best_fit_status status = best_fit_status.BEST_FIT_STATUS_SUCCESS,
  int nDevices = 0,
  List<_DeviceMemory> devices = const [],
  String errorMessage = '',
}) {
  final ptr = calloc<best_fit_prediction>();
  ptr.ref
    ..statusAsInt = status.value
    ..n_devices = nDevices;
  for (var index = 0; index < devices.length; index += 1) {
    final device = devices[index];
    ptr.ref.devices[index]
      ..free_bytes = device.free
      ..total_bytes = device.total
      ..total_used_bytes = device.used;
  }
  _writeCharArray(ptr.ref.error_msg, errorMessage);
  return ptr.ref;
}

best_fit_max_ctx_result _maxContextResult({
  best_fit_status status = best_fit_status.BEST_FIT_STATUS_SUCCESS,
  int chosenContext = 0,
  int iterations = 0,
  best_fit_prediction? prediction,
  String errorMessage = '',
}) {
  final ptr = calloc<best_fit_max_ctx_result>();
  ptr.ref
    ..statusAsInt = status.value
    ..n_ctx_chosen = chosenContext
    ..n_iterations = iterations
    ..prediction_at_chosen = prediction ?? _prediction();
  _writeCharArray(ptr.ref.error_msg, errorMessage);
  return ptr.ref;
}

_DeviceMemory _device({
  required int free,
  required int total,
  required int used,
}) => _DeviceMemory(free: free, total: total, used: used);

final class _DeviceMemory {
  const _DeviceMemory({
    required this.free,
    required this.total,
    required this.used,
  });

  final int free;
  final int total;
  final int used;
}

void _writeCharArray(Array<Char> target, String value) {
  final bytes = utf8.encode(value);
  final count = bytes.length < 255 ? bytes.length : 255;
  for (var i = 0; i < count; i += 1) {
    target[i] = bytes[i];
  }
  target[count] = 0;
}
