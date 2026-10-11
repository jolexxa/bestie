// Native llama bindings have odd names and signatures.
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:test/test.dart' as test;

import 'fake_llama_cpp_bindings_stubs.dart';

final class FakeLlamaCppBindings extends FakeLlamaCppBindingsStubs {
  FakeLlamaCppBindings({
    this.tokenizeImpl,
    this.tokenToPieceImpl,
    this.decodeImpl,
    this.vocabIsEogImpl,
    this.vocabIsControlImpl,
    this.memorySeqRmImpl,
    this.newContextImpl,
  }) {
    modelPtr = _modelMemory.cast<llama_model>();
    memory = _memoryData.cast<llama_memory_i>();
    _allocations.addAll([
      _modelParamsPtr,
      _contextParamsPtr,
      _chainParamsPtr,
      _batchPtr,
      _modelMemory,
      _vocabMemory,
      _contextMemory,
      _memoryData,
      _samplerChainPtr,
      _topKSamplerPtr,
      _topPSamplerPtr,
      _minPSamplerPtr,
      _typicalSamplerPtr,
      _penaltiesSamplerPtr,
      _greedySamplerPtr,
      _tempSamplerPtr,
      _distSamplerPtr,
      _clonedSamplerPtr,
    ]);
    test.addTearDown(dispose);
  }

  final Pointer<llama_model_params> _modelParamsPtr =
      calloc<llama_model_params>();
  final Pointer<llama_context_params> _contextParamsPtr =
      calloc<llama_context_params>();
  final Pointer<llama_sampler_chain_params> _chainParamsPtr =
      calloc<llama_sampler_chain_params>();
  final Pointer<llama_batch> _batchPtr = calloc<llama_batch>();
  final Pointer<Uint8> _modelMemory = calloc<Uint8>();
  final Pointer<Uint8> _vocabMemory = calloc<Uint8>();
  final Pointer<Uint8> _contextMemory = calloc<Uint8>();
  final Pointer<Uint8> _memoryData = calloc<Uint8>();
  final Pointer<llama_sampler> _samplerChainPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _topKSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _topPSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _minPSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _typicalSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _penaltiesSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _greedySamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _tempSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _distSamplerPtr = calloc<llama_sampler>();
  final Pointer<llama_sampler> _clonedSamplerPtr = calloc<llama_sampler>();
  final _NativeAllocations _allocations = _NativeAllocations();
  final Map<int, _NativeAllocations> _batchAllocations = {};
  final List<Pointer<Char>> _deviceStringPointers = [];

  llama_model_params get modelParams => _modelParamsPtr.ref;
  set modelParams(llama_model_params value) => _modelParamsPtr.ref = value;

  llama_context_params get contextParams => _contextParamsPtr.ref;
  set contextParams(llama_context_params value) =>
      _contextParamsPtr.ref = value;

  llama_sampler_chain_params get chainParams => _chainParamsPtr.ref;
  set chainParams(llama_sampler_chain_params value) =>
      _chainParamsPtr.ref = value;

  llama_batch get batch => _batchPtr.ref;
  set batch(llama_batch value) => _batchPtr.ref = value;

  late Pointer<llama_model> modelPtr;

  int llamaLogSetCalls = 0;
  int ggmlLogSetCalls = 0;
  int backendInitCalls = 0;
  int backendFreeCalls = 0;
  ggml_numa_strategy? lastNumaInit;
  int freeCalls = 0;
  int freeModelCalls = 0;
  int backendLoadAllFromPathCalls = 0;
  String? lastBackendLoadPath;
  int samplerChainAddCalls = 0;
  int samplerFreeCalls = 0;
  int decodeCalls = 0;
  int samplerSampleCalls = 0;
  final samplerSampleIndexes = <int>[];
  int samplerAcceptCalls = 0;
  int? lastAcceptedToken;
  final acceptedTokens = <int>[];
  int samplerResetCalls = 0;
  int samplerCloneCalls = 0;
  int samplerSampleResult = 0;
  final samplerSampleResults = <int>[];

  int tokenizeCalls = 0;
  int tokenToPieceCalls = 0;

  int Function(
    Pointer<llama_vocab>,
    Pointer<Char>,
    int,
    Pointer<llama_token>,
    int,
    bool,
    bool,
  )?
  tokenizeImpl;

  int Function(
    Pointer<llama_vocab>,
    int,
    Pointer<Char>,
    int,
    int,
    bool,
  )?
  tokenToPieceImpl;

  int Function(Pointer<llama_context>, llama_batch)? decodeImpl;

  bool Function(Pointer<llama_vocab>, int)? vocabIsEogImpl;
  bool Function(Pointer<llama_vocab>, int)? vocabIsControlImpl;

  bool Function(llama_memory_t, int, int, int)? memorySeqRmImpl;
  Pointer<llama_context> Function(
    Pointer<llama_model>,
    llama_context_params,
  )?
  newContextImpl;

  MemoryRangeRemoval? lastMemoryRemoval;

  late llama_memory_t memory;
  int posMin = 0;
  int posMax = 0;
  int nSwa = 0;
  bool isRecurrent = false;
  bool isHybrid = false;

  void dispose() {
    _batchAllocations
      ..values.forEach((allocation) => allocation.free())
      ..clear();
    _deviceStringPointers
      ..forEach(malloc.free)
      ..clear();
    _allocations.free();
  }

  @override
  void llama_log_set(
    Pointer<NativeFunction<ggml_log_callbackFunction>> cb,
    Pointer<Void> userData,
  ) {
    llamaLogSetCalls += 1;
  }

  @override
  void ggml_log_set(
    Pointer<NativeFunction<ggml_log_callbackFunction>> cb,
    Pointer<Void> userData,
  ) {
    ggmlLogSetCalls += 1;
  }

  @override
  void llama_backend_init() {
    backendInitCalls += 1;
  }

  @override
  void llama_backend_free() {
    backendFreeCalls += 1;
  }

  @override
  void ggml_backend_load_all_from_path(Pointer<Char> path) {
    backendLoadAllFromPathCalls += 1;
    lastBackendLoadPath = path.cast<Utf8>().toDartString();
  }

  @override
  void llama_numa_init(ggml_numa_strategy numa) {
    lastNumaInit = numa;
  }

  @override
  llama_model_params llama_model_default_params() => modelParams;

  @override
  Pointer<llama_model> llama_model_load_from_file(
    Pointer<Char> path,
    llama_model_params params,
  ) {
    return modelPtr;
  }

  @override
  Pointer<llama_vocab> llama_model_get_vocab(Pointer<llama_model> model) {
    return _vocabMemory.cast<llama_vocab>();
  }

  @override
  llama_context_params llama_context_default_params() => contextParams;

  @override
  Pointer<llama_context> llama_init_from_model(
    Pointer<llama_model> model,
    llama_context_params params,
  ) {
    return newContextImpl?.call(model, params) ??
        _contextMemory.cast<llama_context>();
  }

  @override
  void llama_free(Pointer<llama_context> ctx) {
    freeCalls += 1;
  }

  @override
  void llama_model_free(Pointer<llama_model> model) {
    freeModelCalls += 1;
  }

  @override
  int llama_tokenize(
    Pointer<llama_vocab> vocab,
    Pointer<Char> text,
    int textLen,
    Pointer<llama_token> tokens,
    int nTokensMax,
    bool addSpecial,
    bool parseSpecial,
  ) {
    tokenizeCalls += 1;
    return tokenizeImpl?.call(
          vocab,
          text,
          textLen,
          tokens,
          nTokensMax,
          addSpecial,
          parseSpecial,
        ) ??
        0;
  }

  @override
  int llama_token_to_piece(
    Pointer<llama_vocab> vocab,
    int token,
    Pointer<Char> buf,
    int length,
    int lstrip,
    bool special,
  ) {
    tokenToPieceCalls += 1;
    return tokenToPieceImpl?.call(vocab, token, buf, length, lstrip, special) ??
        0;
  }

  @override
  llama_batch llama_batch_get_one(Pointer<llama_token> tokens, int nTokens) {
    return batch;
  }

  int batchInitCalls = 0;
  int batchFreeCalls = 0;

  @override
  llama_batch llama_batch_init(int nTokens, int embd, int nSeqMax) {
    batchInitCalls++;
    final allocations = _NativeAllocations();
    final batchPtr = calloc<llama_batch>();
    final b = batchPtr.ref;
    final tokenPtr = calloc<llama_token>(nTokens);
    final posPtr = calloc<llama_pos>(nTokens);
    final nSeqIdPtr = calloc<Int32>(nTokens);
    final seqIdPtr = calloc<Pointer<llama_seq_id>>(nTokens);
    final logitsPtr = calloc<Int8>(nTokens);
    for (var i = 0; i < nTokens; i++) {
      seqIdPtr[i] = calloc<llama_seq_id>(nSeqMax);
      allocations.add(seqIdPtr[i]);
    }
    b
      ..token = tokenPtr
      ..pos = posPtr
      ..n_seq_id = nSeqIdPtr
      ..seq_id = seqIdPtr
      ..logits = logitsPtr
      ..n_tokens = 0;
    allocations.addAll([
      batchPtr,
      tokenPtr,
      posPtr,
      nSeqIdPtr,
      seqIdPtr,
      logitsPtr,
    ]);
    _batchAllocations[tokenPtr.address] = allocations;
    return b;
  }

  @override
  void llama_batch_free(llama_batch batch) {
    batchFreeCalls++;
    _batchAllocations.remove(batch.token.address)?.free();
  }

  @override
  int llama_decode(Pointer<llama_context> ctx, llama_batch batch) {
    decodeCalls += 1;
    return decodeImpl?.call(ctx, batch) ?? 0;
  }

  @override
  llama_sampler_chain_params llama_sampler_chain_default_params() =>
      chainParams;

  @override
  Pointer<llama_sampler> llama_sampler_chain_init(
    llama_sampler_chain_params params,
  ) {
    return _samplerChainPtr;
  }

  @override
  void llama_sampler_chain_add(
    Pointer<llama_sampler> chain,
    Pointer<llama_sampler> sampler,
  ) {
    samplerChainAddCalls += 1;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_top_k(int k) {
    lastTopK = k;
    return _topKSamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_top_p(double p, int minKeep) {
    return _topPSamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_min_p(double p, int minKeep) {
    return _minPSamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_typical(double p, int minKeep) {
    return _typicalSamplerPtr;
  }

  int vocabularySize = 32000;
  int? lastPenaltiesVocabularySize;
  int? lastDistSeed;
  double? lastTemperature;
  int? lastTopK;

  @override
  int llama_vocab_n_tokens(Pointer<llama_vocab> vocab) => vocabularySize;

  @override
  Pointer<llama_sampler> llama_sampler_init_penalties(
    int vocabularySize,
    int penaltyLastN,
    double penaltyRepeat,
    double penaltyFreq,
    double penaltyPresent,
  ) {
    lastPenaltiesVocabularySize = vocabularySize;
    return _penaltiesSamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_greedy() {
    return _greedySamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_temp(double temp) {
    lastTemperature = temp;
    return _tempSamplerPtr;
  }

  @override
  Pointer<llama_sampler> llama_sampler_init_dist(int seed) {
    lastDistSeed = seed;
    return _distSamplerPtr;
  }

  @override
  int llama_sampler_sample(
    Pointer<llama_sampler> sampler,
    Pointer<llama_context> ctx,
    int idx,
  ) {
    samplerSampleCalls += 1;
    samplerSampleIndexes.add(idx);
    if (samplerSampleResults.isNotEmpty) {
      return samplerSampleResults.removeAt(0);
    }
    return samplerSampleResult;
  }

  @override
  void llama_sampler_accept(Pointer<llama_sampler> sampler, int token) {
    samplerAcceptCalls += 1;
    lastAcceptedToken = token;
    acceptedTokens.add(token);
  }

  @override
  Pointer<llama_sampler> llama_sampler_clone(Pointer<llama_sampler> smpl) {
    samplerCloneCalls += 1;
    return _clonedSamplerPtr;
  }

  @override
  void llama_sampler_reset(Pointer<llama_sampler> smpl) {
    samplerResetCalls += 1;
  }

  @override
  void llama_sampler_free(Pointer<llama_sampler> sampler) {
    samplerFreeCalls += 1;
  }

  @override
  bool llama_vocab_is_eog(Pointer<llama_vocab> vocab, int token) {
    return vocabIsEogImpl?.call(vocab, token) ?? false;
  }

  @override
  bool llama_vocab_is_control(Pointer<llama_vocab> vocab, int token) {
    return vocabIsControlImpl?.call(vocab, token) ?? false;
  }

  @override
  llama_memory_t llama_get_memory(Pointer<llama_context> ctx) {
    return memory;
  }

  @override
  Pointer<llama_model> llama_get_model(Pointer<llama_context> ctx) {
    return Pointer.fromAddress(1);
  }

  @override
  int llama_model_n_swa(Pointer<llama_model> model) {
    return nSwa;
  }

  @override
  bool llama_model_is_recurrent(Pointer<llama_model> model) {
    return isRecurrent;
  }

  @override
  bool llama_model_is_hybrid(Pointer<llama_model> model) {
    return isHybrid;
  }

  @override
  int llama_memory_seq_pos_min(llama_memory_t mem, int seqId) {
    return posMin;
  }

  @override
  int llama_memory_seq_pos_max(llama_memory_t mem, int seqId) {
    return posMax;
  }

  @override
  bool llama_memory_seq_rm(
    llama_memory_t mem,
    int seqId,
    int p0,
    int p1,
  ) {
    lastMemoryRemoval = MemoryRangeRemoval(
      memory: mem,
      sequenceId: seqId,
      start: p0,
      end: p1,
    );
    return memorySeqRmImpl?.call(mem, seqId, p0, p1) ?? true;
  }

  Uint8List sequenceState = Uint8List(0);
  Uint8List? restoredSequenceState;
  bool acceptsSequenceState = true;
  int? lastSequenceStateFlags;

  @override
  int llama_state_seq_get_size_ext(
    Pointer<llama_context> ctx,
    int seqId,
    int flags,
  ) {
    lastSequenceStateFlags = flags;
    return sequenceState.length;
  }

  @override
  int llama_state_seq_get_data_ext(
    Pointer<llama_context> ctx,
    Pointer<Uint8> dst,
    int size,
    int seqId,
    int flags,
  ) {
    dst.asTypedList(size).setAll(0, sequenceState);
    return sequenceState.length;
  }

  @override
  int llama_state_seq_set_data_ext(
    Pointer<llama_context> ctx,
    Pointer<Uint8> src,
    int size,
    int destSeqId,
    int flags,
  ) {
    lastSequenceStateFlags = flags;
    restoredSequenceState = Uint8List.fromList(src.asTypedList(size));
    return acceptsSequenceState ? size : 0;
  }

  @override
  int llama_n_ctx(Pointer<llama_context> ctx) => contextParams.n_ctx;

  @override
  int llama_n_ctx_seq(Pointer<llama_context> ctx) => contextParams.n_ctx;

  @override
  int llama_n_seq_max(Pointer<llama_context> ctx) => contextParams.n_seq_max;

  @override
  int llama_n_batch(Pointer<llama_context> ctx) => contextParams.n_batch;

  @override
  int llama_n_ubatch(Pointer<llama_context> ctx) => contextParams.n_ubatch;

  final List<FakeLlamaDevice> fakeDevices = [];

  @override
  int ggml_backend_dev_count() => fakeDevices.length;

  @override
  ggml_backend_dev_t ggml_backend_dev_get(int index) =>
      Pointer.fromAddress(index + 1);

  @override
  void ggml_backend_dev_get_props(
    ggml_backend_dev_t dev,
    Pointer<ggml_backend_dev_props> props,
  ) {
    final fake = fakeDevices[dev.address - 1];
    final namePtr = fake.name.toNativeUtf8().cast<Char>();
    final descriptionPtr = fake.description.toNativeUtf8().cast<Char>();
    final deviceIdPtr = switch (fake.deviceId) {
      null => nullptr.cast<Char>(),
      final deviceId => deviceId.toNativeUtf8().cast<Char>(),
    };
    _deviceStringPointers
      ..add(namePtr)
      ..add(descriptionPtr);
    if (deviceIdPtr != nullptr) {
      _deviceStringPointers.add(deviceIdPtr);
    }
    props.ref
      ..name = namePtr
      ..description = descriptionPtr
      ..memory_free = fake.freeMemory
      ..memory_total = fake.totalMemory
      ..typeAsInt = fake.type.value
      ..device_id = deviceIdPtr;
  }
}

final class FakeLlamaDevice {
  const FakeLlamaDevice({
    required this.name,
    required this.description,
    required this.type,
    required this.freeMemory,
    required this.totalMemory,
    this.deviceId,
  });

  final String name;
  final String description;
  final ggml_backend_dev_type type;
  final int freeMemory;
  final int totalMemory;
  final String? deviceId;
}

final class MemoryRangeRemoval {
  const MemoryRangeRemoval({
    required this.memory,
    required this.sequenceId,
    required this.start,
    required this.end,
  });

  final llama_memory_t memory;
  final int sequenceId;
  final int start;
  final int end;
}

final class _NativeAllocations {
  final List<Pointer<NativeType>> _pointers = [];
  var _freed = false;

  void add(Pointer<NativeType> pointer) => _pointers.add(pointer);

  void addAll(Iterable<Pointer<NativeType>> pointers) =>
      _pointers.addAll(pointers);

  void free() {
    if (_freed) return;
    _freed = true;
    _pointers.reversed.forEach(calloc.free);
    _pointers.clear();
  }
}
