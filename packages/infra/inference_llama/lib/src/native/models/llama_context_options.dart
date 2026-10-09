import 'package:dart_mappable/dart_mappable.dart';
import 'package:inference_llama/src/native/models/llama_kv_cache_type.dart';

part 'llama_context_options.mapper.dart';

/// llama.cpp per-context configuration.
@MappableClass()
class LlamaContextOptions with LlamaContextOptionsMappable {
  /// Creates a set of context options.
  const LlamaContextOptions({
    required this.contextSize,
    required this.nBatch,
    required this.nThreads,
    required this.nThreadsBatch,
    this.useFlashAttn,
    this.maxSequences = 1,
    this.microBatchSize,
    this.useUnifiedKvCache,
    this.kvCacheType = LlamaKvCacheType.q8_0,
    this.contextCheckpointCount = 0,
  }) : assert(nBatch > 0, 'nBatch must be greater than zero.'),
       assert(maxSequences > 0, 'maxSequences must be greater than zero.'),
       assert(
         microBatchSize == null || microBatchSize > 0,
         'microBatchSize must be greater than zero.',
       );

  /// Maximum context length, in tokens, the KV cache will hold.
  final int contextSize;

  /// Maximum logical batch size for decode calls.
  final int nBatch;

  /// Threads used for single-token (generation) decoding.
  final int nThreads;

  /// Threads used for multi-token (prompt processing) decoding.
  final int nThreadsBatch;

  /// Whether to enable flash attention. Null leaves the backend default.
  final bool? useFlashAttn;

  /// Maximum number of sequences this context can track.
  final int maxSequences;

  /// Micro-batch size (`n_ubatch`). Null defaults to [nBatch].
  final int? microBatchSize;

  /// Whether to use llama.cpp's unified KV cache mode.
  final bool? useUnifiedKvCache;

  /// KV cache element type (`type_k`/`type_v`).
  final LlamaKvCacheType kvCacheType;

  /// Sliding-window checkpoint ring size (`n_ctx_checkpoints`). 0 disables
  /// checkpointing. Not a native context param — consumed by the scheduler.
  final int contextCheckpointCount;
}
