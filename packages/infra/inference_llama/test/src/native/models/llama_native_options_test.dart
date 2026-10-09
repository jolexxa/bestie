import 'package:inference_llama/inference_llama.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:test/test.dart';

void main() {
  group('LlamaKvCacheType', () {
    test('maps each element type to its ggml type', () {
      expect(LlamaKvCacheType.f16.ggmlType, ggml_type.GGML_TYPE_F16);
      expect(LlamaKvCacheType.q8_0.ggmlType, ggml_type.GGML_TYPE_Q8_0);
      expect(LlamaKvCacheType.q4_0.ggmlType, ggml_type.GGML_TYPE_Q4_0);
    });
  });

  group('LlamaLoadMode', () {
    test('maps each load mode to its native mode', () {
      expect(
        LlamaLoadMode.values.map((mode) => mode.native),
        orderedEquals([
          llama_load_mode.LLAMA_LOAD_MODE_AUTO,
          llama_load_mode.LLAMA_LOAD_MODE_NONE,
          llama_load_mode.LLAMA_LOAD_MODE_MMAP,
          llama_load_mode.LLAMA_LOAD_MODE_MLOCK,
          llama_load_mode.LLAMA_LOAD_MODE_MMAP_MLOCK,
          llama_load_mode.LLAMA_LOAD_MODE_DIRECT_IO,
        ]),
      );
    });
  });

  group('LlamaContextOptions', () {
    LlamaContextOptions options({
      LlamaKvCacheType kvCacheType = LlamaKvCacheType.q8_0,
    }) => LlamaContextOptions(
      contextSize: 1024,
      nBatch: 512,
      nThreads: 4,
      nThreadsBatch: 4,
      kvCacheType: kvCacheType,
    );

    test('equality includes kvCacheType', () {
      expect(options(), options());
      expect(
        options(kvCacheType: LlamaKvCacheType.f16),
        isNot(options()),
      );
    });
  });
}
