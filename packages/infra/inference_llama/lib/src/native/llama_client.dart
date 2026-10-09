import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:inference/inference.dart';
import 'package:inference_llama/src/native/llama_native_params.dart';
import 'package:inference_llama/src/native/llama_sampler_chain.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:meta/meta.dart';

typedef ModelLoadProgressCallback = void Function(double progress);

/// A single entry in a batch decode request.
@immutable
final class BatchEntry {
  /// Creates a batch decode entry.
  const BatchEntry({
    required this.token,
    required this.pos,
    required this.seqId,
    required this.logits,
  });

  /// Token to decode.
  final int token;

  /// Position in the sequence.
  final int pos;

  /// Sequence id that owns this token.
  final int seqId;

  /// Whether llama.cpp should retain logits for this token.
  final bool logits;

  @override
  bool operator ==(Object other) {
    return other is BatchEntry &&
        other.token == token &&
        other.pos == pos &&
        other.seqId == seqId &&
        other.logits == logits;
  }

  @override
  int get hashCode => Object.hash(token, pos, seqId, logits);
}

abstract interface class LlamaClientApi {
  LlamaClientLoadModelResult loadModel({
    required String modelPath,
    required LlamaModelOptions modelOptions,
    ModelLoadProgressCallback? onProgress,
  });

  LlamaModelHandle modelHandleFromPointer(int pointerAddress);

  LlamaClientTokenizeResult tokenize(
    LlamaModelHandle model,
    String text, {
    bool addSpecial,
    bool parseSpecial,
  });

  LlamaClientCreateContextResult createContext(
    LlamaModelHandle model,
    LlamaContextOptions options,
  );

  /// Reads the backend's real capacity limits from a created [context].
  ContextEnvelope readEnvelope(LlamaContextHandle context);

  LlamaDecodeResult decodeBatch(
    LlamaContextHandle context,
    List<BatchEntry> entries,
  );

  int sampleAt(
    LlamaContextHandle context,
    LlamaSamplerChain sampler,
    int batchIndex,
  );

  int sequencePositionMax(
    LlamaContextHandle context,
    int sequenceId,
  );

  int sequencePositionMin(
    LlamaContextHandle context,
    int sequenceId,
  );

  bool removeSequenceRange(
    LlamaContextHandle context,
    int sequenceId,
    int start,
    int end,
  );

  /// Serializes a sequence's KV/recurrent state. [full] captures the entire
  /// state (attention KV + recurrent) for recurrent/hybrid models; otherwise
  /// only the partial (sliding-window / recurrent-only) state is captured.
  Uint8List readSequenceCheckpoint(
    LlamaContextHandle context,
    int sequenceId, {
    bool full = false,
  });

  bool writeSequenceCheckpoint(
    LlamaContextHandle context,
    int sequenceId,
    Uint8List bytes, {
    bool full = false,
  });

  bool isEndOfGeneration(LlamaModelHandle model, int token);

  void acceptToken(LlamaSamplerChain sampler, int token);

  Uint8List tokenToBytes(
    LlamaModelHandle model,
    int token, {
    int bufferSize,
  });

  /// A fresh sampler chain for [sampling] over [model]'s vocabulary.
  LlamaSamplerChain createSampler(
    LlamaModelHandle model,
    EngineSampling sampling,
  );

  List<LlamaDeviceInfo> getDeviceInfo();

  void disposeContext(LlamaContextHandle context);

  void disposeModel(LlamaModelHandle model);
}

final class LlamaClient implements LlamaClientApi {
  LlamaClient({required LlamaCppBindings bindings}) : _bindings = bindings;

  final LlamaCppBindings _bindings;

  @override
  LlamaClientLoadModelResult loadModel({
    required String modelPath,
    required LlamaModelOptions modelOptions,
    ModelLoadProgressCallback? onProgress,
  }) {
    if (modelOptions.numa != null) {
      _bindings.llama_numa_init(
        ggml_numa_strategy.fromValue(modelOptions.numa!),
      );
    }

    final modelParams = _bindings.modelParamsFor(modelOptions);

    NativeCallable<llama_progress_callbackFunction>? nativeCallback;
    if (onProgress != null) {
      nativeCallback =
          NativeCallable<llama_progress_callbackFunction>.isolateLocal(
            // coverage:ignore-start
            (double progress, Pointer<Void> userData) {
              onProgress(progress);
              return true;
            },
            // coverage:ignore-end
            exceptionalReturn: false,
          );
      modelParams.progress_callback = nativeCallback.nativeFunction;
    }

    final modelPathPtr = modelPath.toNativeUtf8(allocator: calloc).cast<Char>();
    final model = _bindings.llama_model_load_from_file(
      modelPathPtr,
      modelParams,
    );
    calloc.free(modelPathPtr);

    nativeCallback?.close();

    if (model == nullptr) {
      return LlamaClientLoadModelFailed(
        message: 'Failed to load model: $modelPath.',
        stackTrace: '',
      );
    }

    final vocab = _bindings.llama_model_get_vocab(model);
    return LlamaClientLoadModelSucceeded(
      LlamaModelHandle(pointer: model, vocab: vocab),
    );
  }

  @override
  LlamaModelHandle modelHandleFromPointer(int pointerAddress) {
    final model = Pointer<llama_model>.fromAddress(pointerAddress);
    return LlamaModelHandle(
      pointer: model,
      vocab: _bindings.llama_model_get_vocab(model),
    );
  }

  @override
  LlamaClientCreateContextResult createContext(
    LlamaModelHandle model,
    LlamaContextOptions options,
  ) {
    final context = _bindings.llama_init_from_model(
      model.pointer,
      _bindings.contextParamsFor(options),
    );
    if (context == nullptr) {
      return const LlamaClientCreateContextFailed(
        message: 'Failed to create context.',
        stackTrace: '',
      );
    }
    return LlamaClientCreateContextSucceeded(context);
  }

  @override
  ContextEnvelope readEnvelope(LlamaContextHandle context) {
    return ContextEnvelope(
      contextSize: _bindings.llama_n_ctx(context),
      perSequenceLimit: _bindings.llama_n_ctx_seq(context),
      maxSequences: _bindings.llama_n_seq_max(context),
      maxBatchTokens: _bindings.llama_n_batch(context),
      microBatchTokens: _bindings.llama_n_ubatch(context),
      nSwa: _bindings.llama_model_n_swa(_bindings.llama_get_model(context)),
      isRecurrent: _isRecurrent(context),
    );
  }

  // True when any layer keeps rolling recurrent state (SSM / Gated DeltaNet):
  // pure recurrent models (Mamba, RWKV) report `is_recurrent`, while hybrid
  // recurrent models (Qwen3.5 / Qwen3-Next Gated DeltaNet) report `is_hybrid`.
  // Both hold state that cannot be partially rewound.
  bool _isRecurrent(LlamaContextHandle context) {
    final model = _bindings.llama_get_model(context);
    return _bindings.llama_model_is_recurrent(model) ||
        _bindings.llama_model_is_hybrid(model);
  }

  @override
  void disposeContext(LlamaContextHandle context) {
    if (context == nullptr) {
      return;
    }
    _bindings.llama_free(context);
  }

  @override
  void disposeModel(LlamaModelHandle model) {
    _bindings.llama_model_free(model.pointer);
  }

  @override
  LlamaSamplerChain createSampler(
    LlamaModelHandle model,
    EngineSampling sampling,
  ) {
    return LlamaSamplerChain.build(
      _bindings,
      sampling,
      vocabularySize: _bindings.llama_vocab_n_tokens(model.vocab),
    );
  }

  @override
  List<LlamaDeviceInfo> getDeviceInfo() {
    final bindings = _bindings;
    final count = bindings.ggml_backend_dev_count();
    if (count == 0) return const [];

    final pProps = calloc<ggml_backend_dev_props>();
    try {
      return [
        for (var index = 0; index < count; index++)
          _readDevice(bindings, index, pProps),
      ];
    } finally {
      calloc.free(pProps);
    }
  }

  LlamaDeviceInfo _readDevice(
    LlamaCppBindings bindings,
    int deviceIndex,
    Pointer<ggml_backend_dev_props> pProps,
  ) {
    final dev = bindings.ggml_backend_dev_get(deviceIndex);
    bindings.ggml_backend_dev_get_props(dev, pProps);
    final props = pProps.ref;
    final deviceIdPtr = props.device_id;
    final totalMemory = props.memory_total;
    return LlamaDeviceInfo(
      name: props.name.cast<Utf8>().toDartString(),
      description: props.description.cast<Utf8>().toDartString(),
      type: _toDeviceType(props.type),
      // ggml reports free memory as an unsigned size_t computed as
      // budget - usage. When usage exceeds budget the subtraction underflows
      // and arrives here as a negative (or above-total) value; clamp it back
      // into a meaningful range so a pressured device reads as fully used.
      freeMemory: props.memory_free.clamp(0, totalMemory),
      totalMemory: totalMemory,
      deviceId: deviceIdPtr == nullptr
          ? null
          : deviceIdPtr.cast<Utf8>().toDartString(),
    );
  }

  LlamaDeviceType _toDeviceType(ggml_backend_dev_type raw) => switch (raw) {
    ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_CPU => LlamaDeviceType.cpu,
    ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_GPU => LlamaDeviceType.gpu,
    ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_IGPU =>
      LlamaDeviceType.integratedGpu,
    ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_ACCEL =>
      LlamaDeviceType.accelerator,
    ggml_backend_dev_type.GGML_BACKEND_DEVICE_TYPE_META => LlamaDeviceType.meta,
  };

  @override
  LlamaClientTokenizeResult tokenize(
    LlamaModelHandle model,
    String text, {
    bool addSpecial = true,
    bool parseSpecial = true,
  }) {
    final textUtf8 = text.toNativeUtf8(allocator: calloc);
    final textPtr = textUtf8.cast<Char>();
    final textLen = textUtf8.length;
    var maxTokens = textLen + 8;
    var tokensPtr = calloc<llama_token>(maxTokens);

    var tokenCount = _bindings.llama_tokenize(
      model.vocab,
      textPtr,
      textLen,
      tokensPtr,
      maxTokens,
      addSpecial,
      parseSpecial,
    );
    if (tokenCount < 0) {
      calloc.free(tokensPtr);
      maxTokens = -tokenCount;
      tokensPtr = calloc<llama_token>(maxTokens);
      tokenCount = _bindings.llama_tokenize(
        model.vocab,
        textPtr,
        textLen,
        tokensPtr,
        maxTokens,
        addSpecial,
        parseSpecial,
      );
    }
    calloc.free(textUtf8);

    if (tokenCount < 0) {
      calloc.free(tokensPtr);
      return LlamaClientTokenizeFailed(
        message: 'Tokenization failed, need ${-tokenCount} tokens.',
        stackTrace: '',
      );
    }

    final result = tokensPtr.asTypedList(tokenCount).toList(growable: false);
    calloc.free(tokensPtr);
    return LlamaClientTokenizeSucceeded(result);
  }

  Uint8List _tokenToPieceBytes(
    LlamaModelHandle model,
    int token, {
    int bufferSize = 256,
  }) {
    var buf = calloc<Char>(bufferSize);
    var byteCount = _bindings.llama_token_to_piece(
      model.vocab,
      token,
      buf,
      bufferSize,
      0,
      true,
    );

    if (byteCount < 0) {
      calloc.free(buf);
      final needed = -byteCount + 1;
      buf = calloc<Char>(needed);
      byteCount = _bindings.llama_token_to_piece(
        model.vocab,
        token,
        buf,
        needed,
        0,
        true,
      );
    }

    if (byteCount < 0) {
      calloc.free(buf);
      return Uint8List(0);
    }

    final bytes = Uint8List.fromList(buf.cast<Uint8>().asTypedList(byteCount));
    calloc.free(buf);
    return bytes;
  }

  @override
  Uint8List tokenToBytes(
    LlamaModelHandle model,
    int token, {
    int bufferSize = 256,
  }) {
    return _tokenToPieceBytes(model, token, bufferSize: bufferSize);
  }

  @override
  LlamaDecodeResult decodeBatch(
    LlamaContextHandle context,
    List<BatchEntry> entries,
  ) {
    if (entries.isEmpty) return const LlamaDecodeSucceeded();
    final batch = _bindings.llama_batch_init(entries.length, 0, 1);

    try {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        batch.token[index] = entry.token;
        batch.pos[index] = entry.pos;
        batch.n_seq_id[index] = 1;
        batch.seq_id[index][0] = entry.seqId;
        batch.logits[index] = entry.logits ? 1 : 0;
      }
      batch.n_tokens = entries.length;

      final rc = _bindings.llama_decode(context, batch);
      if (rc != 0) {
        return LlamaDecodeFailed(
          message: 'llama_decode failed with code $rc.',
          stackTrace: '',
          backendCode: rc,
        );
      }
      return const LlamaDecodeSucceeded();
    } finally {
      _bindings.llama_batch_free(batch);
    }
  }

  @override
  int sampleAt(
    LlamaContextHandle context,
    LlamaSamplerChain sampler,
    int batchIndex,
  ) {
    return sampler.sampleAt(context, batchIndex);
  }

  @override
  int sequencePositionMax(
    LlamaContextHandle context,
    int sequenceId,
  ) {
    final mem = _bindings.llama_get_memory(context);
    return _bindings.llama_memory_seq_pos_max(mem, sequenceId);
  }

  @override
  int sequencePositionMin(
    LlamaContextHandle context,
    int sequenceId,
  ) {
    final mem = _bindings.llama_get_memory(context);
    return _bindings.llama_memory_seq_pos_min(mem, sequenceId);
  }

  @override
  bool removeSequenceRange(
    LlamaContextHandle context,
    int sequenceId,
    int start,
    int end,
  ) {
    final mem = _bindings.llama_get_memory(context);
    return _bindings.llama_memory_seq_rm(mem, sequenceId, start, end);
  }

  @override
  Uint8List readSequenceCheckpoint(
    LlamaContextHandle context,
    int sequenceId, {
    bool full = false,
  }) {
    final flags = full
        ? LLAMA_STATE_SEQ_FLAGS_NONE
        : LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY;
    final size = _bindings.llama_state_seq_get_size_ext(
      context,
      sequenceId,
      flags,
    );
    if (size == 0) return Uint8List(0);
    final buffer = calloc<Uint8>(size);
    try {
      final written = _bindings.llama_state_seq_get_data_ext(
        context,
        buffer,
        size,
        sequenceId,
        flags,
      );
      return Uint8List.fromList(buffer.asTypedList(written));
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  bool writeSequenceCheckpoint(
    LlamaContextHandle context,
    int sequenceId,
    Uint8List bytes, {
    bool full = false,
  }) {
    if (bytes.isEmpty) return false;
    final flags = full
        ? LLAMA_STATE_SEQ_FLAGS_NONE
        : LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY;
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final read = _bindings.llama_state_seq_set_data_ext(
        context,
        buffer,
        bytes.length,
        sequenceId,
        flags,
      );
      return read != 0;
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  bool isEndOfGeneration(LlamaModelHandle model, int token) {
    return _bindings.llama_vocab_is_eog(model.vocab, token);
  }

  @override
  void acceptToken(LlamaSamplerChain sampler, int token) {
    sampler.accept(token);
  }
}

sealed class LlamaClientLoadModelResult {
  const LlamaClientLoadModelResult();
}

final class LlamaClientLoadModelSucceeded extends LlamaClientLoadModelResult {
  const LlamaClientLoadModelSucceeded(this.handle);

  final LlamaModelHandle handle;
}

final class LlamaClientLoadModelFailed extends LlamaClientLoadModelResult {
  const LlamaClientLoadModelFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;

  final String stackTrace;
}

sealed class LlamaClientCreateContextResult {
  const LlamaClientCreateContextResult();
}

final class LlamaClientCreateContextSucceeded
    extends LlamaClientCreateContextResult {
  const LlamaClientCreateContextSucceeded(this.context);

  final LlamaContextHandle context;
}

final class LlamaClientCreateContextFailed
    extends LlamaClientCreateContextResult {
  const LlamaClientCreateContextFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;

  final String stackTrace;
}

sealed class LlamaClientTokenizeResult {
  const LlamaClientTokenizeResult();
}

final class LlamaClientTokenizeSucceeded extends LlamaClientTokenizeResult {
  const LlamaClientTokenizeSucceeded(this.tokens);

  final List<int> tokens;
}

final class LlamaClientTokenizeFailed extends LlamaClientTokenizeResult {
  const LlamaClientTokenizeFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;

  final String stackTrace;
}

sealed class LlamaDecodeResult {
  const LlamaDecodeResult();
}

final class LlamaDecodeSucceeded extends LlamaDecodeResult {
  const LlamaDecodeSucceeded();
}

final class LlamaDecodeFailed extends LlamaDecodeResult {
  const LlamaDecodeFailed({
    required this.message,
    required this.stackTrace,
    required this.backendCode,
  });

  final String message;

  final String stackTrace;

  final int backendCode;
}
