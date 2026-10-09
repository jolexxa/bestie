import 'package:inference_llama/src/native/models/models.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Native parameter structs built from the option models, shared by model
/// loading, context creation and fit prediction so a prediction describes
/// exactly what a load would allocate.
extension LlamaNativeParams on LlamaCppBindings {
  /// The model load parameters for [options], over the backend defaults.
  llama_model_params modelParamsFor(LlamaModelOptions options) {
    final params = llama_model_default_params();
    return params
      ..n_gpu_layers = options.nGpuLayers ?? params.n_gpu_layers
      ..main_gpu = options.mainGpu ?? params.main_gpu
      ..load_modeAsInt = options.loadMode?.native.value ?? params.load_modeAsInt
      ..check_tensors = options.checkTensors ?? params.check_tensors;
  }

  /// The context parameters for [options], over the backend defaults.
  llama_context_params contextParamsFor(LlamaContextOptions options) {
    final params = llama_context_default_params();
    final kvType = options.kvCacheType.ggmlType;
    return params
      ..n_ctx = options.contextSize
      ..n_batch = options.nBatch
      ..n_ubatch = options.microBatchSize ?? options.nBatch
      ..n_threads = options.nThreads
      ..n_threads_batch = options.nThreadsBatch
      ..n_seq_max = options.maxSequences
      ..type_kAsInt = kvType.value
      ..type_vAsInt = kvType.value
      ..flash_attn_typeAsInt = _flashAttentionType(
        options.useFlashAttn,
        fallback: params.flash_attn_typeAsInt,
      )
      ..kv_unified = options.useUnifiedKvCache ?? params.kv_unified;
  }
}

int _flashAttentionType(bool? enabled, {required int fallback}) =>
    switch (enabled) {
      true => llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_ENABLED.value,
      false => llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_DISABLED.value,
      null => fallback,
    };
