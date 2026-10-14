import 'package:dart_mappable/dart_mappable.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

part 'llama_kv_cache_type.mapper.dart';

/// KV cache element type for a llama.cpp context. Serialized by name
/// (`f16`/`q8_0`/`q4_0`).
@MappableEnum()
enum LlamaKvCacheType {
  /// Full-precision 16-bit (no quantization).
  f16,

  /// 8-bit quantized (~half the KV footprint, negligible quality loss).
  q8_0,

  /// 4-bit quantized (~quarter the KV footprint, some quality loss).
  q4_0;

  /// The ggml element type for `type_k`/`type_v` on a llama context.
  ggml_type get ggmlType => switch (this) {
    LlamaKvCacheType.f16 => ggml_type.GGML_TYPE_F16,
    LlamaKvCacheType.q8_0 => ggml_type.GGML_TYPE_Q8_0,
    LlamaKvCacheType.q4_0 => ggml_type.GGML_TYPE_Q4_0,
  };
}
