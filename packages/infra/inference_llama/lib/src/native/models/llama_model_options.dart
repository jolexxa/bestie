import 'package:dart_mappable/dart_mappable.dart';
import 'package:inference_llama/src/native/models/llama_load_mode.dart';

part 'llama_model_options.mapper.dart';

/// llama.cpp load-time options. Null fields leave the backend default.
@MappableClass()
class LlamaModelOptions with LlamaModelOptionsMappable {
  /// Creates a set of model load options.
  const LlamaModelOptions({
    this.nGpuLayers,
    this.mainGpu,
    this.numa,
    this.loadMode,
    this.checkTensors,
  });

  /// Number of transformer layers to offload to the GPU. `-1` offloads every
  /// layer; `0` keeps the model on the CPU.
  final int? nGpuLayers;

  /// Index of the GPU that holds tensors that aren't split across devices.
  final int? mainGpu;

  /// NUMA strategy index. See `ggml_numa_strategy` for valid values.
  final int? numa;

  /// How the weights are read from disk.
  final LlamaLoadMode? loadMode;

  /// Whether to validate tensor data against the file's checksums during load.
  final bool? checkTensors;
}
