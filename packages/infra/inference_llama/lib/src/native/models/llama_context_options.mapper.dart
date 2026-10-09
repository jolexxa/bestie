// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'llama_context_options.dart';

class LlamaContextOptionsMapper extends ClassMapperBase<LlamaContextOptions> {
  LlamaContextOptionsMapper._();

  static LlamaContextOptionsMapper? _instance;
  static LlamaContextOptionsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlamaContextOptionsMapper._());
      LlamaKvCacheTypeMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlamaContextOptions';

  static int _$contextSize(LlamaContextOptions v) => v.contextSize;
  static const Field<LlamaContextOptions, int> _f$contextSize = Field(
    'contextSize',
    _$contextSize,
  );
  static int _$nBatch(LlamaContextOptions v) => v.nBatch;
  static const Field<LlamaContextOptions, int> _f$nBatch = Field(
    'nBatch',
    _$nBatch,
  );
  static int _$nThreads(LlamaContextOptions v) => v.nThreads;
  static const Field<LlamaContextOptions, int> _f$nThreads = Field(
    'nThreads',
    _$nThreads,
  );
  static int _$nThreadsBatch(LlamaContextOptions v) => v.nThreadsBatch;
  static const Field<LlamaContextOptions, int> _f$nThreadsBatch = Field(
    'nThreadsBatch',
    _$nThreadsBatch,
  );
  static bool? _$useFlashAttn(LlamaContextOptions v) => v.useFlashAttn;
  static const Field<LlamaContextOptions, bool> _f$useFlashAttn = Field(
    'useFlashAttn',
    _$useFlashAttn,
    opt: true,
  );
  static int _$maxSequences(LlamaContextOptions v) => v.maxSequences;
  static const Field<LlamaContextOptions, int> _f$maxSequences = Field(
    'maxSequences',
    _$maxSequences,
    opt: true,
    def: 1,
  );
  static int? _$microBatchSize(LlamaContextOptions v) => v.microBatchSize;
  static const Field<LlamaContextOptions, int> _f$microBatchSize = Field(
    'microBatchSize',
    _$microBatchSize,
    opt: true,
  );
  static bool? _$useUnifiedKvCache(LlamaContextOptions v) =>
      v.useUnifiedKvCache;
  static const Field<LlamaContextOptions, bool> _f$useUnifiedKvCache = Field(
    'useUnifiedKvCache',
    _$useUnifiedKvCache,
    opt: true,
  );
  static LlamaKvCacheType _$kvCacheType(LlamaContextOptions v) => v.kvCacheType;
  static const Field<LlamaContextOptions, LlamaKvCacheType> _f$kvCacheType =
      Field(
        'kvCacheType',
        _$kvCacheType,
        opt: true,
        def: LlamaKvCacheType.q8_0,
      );
  static int _$contextCheckpointCount(LlamaContextOptions v) =>
      v.contextCheckpointCount;
  static const Field<LlamaContextOptions, int> _f$contextCheckpointCount =
      Field(
        'contextCheckpointCount',
        _$contextCheckpointCount,
        opt: true,
        def: 0,
      );

  @override
  final MappableFields<LlamaContextOptions> fields = const {
    #contextSize: _f$contextSize,
    #nBatch: _f$nBatch,
    #nThreads: _f$nThreads,
    #nThreadsBatch: _f$nThreadsBatch,
    #useFlashAttn: _f$useFlashAttn,
    #maxSequences: _f$maxSequences,
    #microBatchSize: _f$microBatchSize,
    #useUnifiedKvCache: _f$useUnifiedKvCache,
    #kvCacheType: _f$kvCacheType,
    #contextCheckpointCount: _f$contextCheckpointCount,
  };

  static LlamaContextOptions _instantiate(DecodingData data) {
    return LlamaContextOptions(
      contextSize: data.dec(_f$contextSize),
      nBatch: data.dec(_f$nBatch),
      nThreads: data.dec(_f$nThreads),
      nThreadsBatch: data.dec(_f$nThreadsBatch),
      useFlashAttn: data.dec(_f$useFlashAttn),
      maxSequences: data.dec(_f$maxSequences),
      microBatchSize: data.dec(_f$microBatchSize),
      useUnifiedKvCache: data.dec(_f$useUnifiedKvCache),
      kvCacheType: data.dec(_f$kvCacheType),
      contextCheckpointCount: data.dec(_f$contextCheckpointCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlamaContextOptions fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlamaContextOptions>(map);
  }

  static LlamaContextOptions fromJson(String json) {
    return ensureInitialized().decodeJson<LlamaContextOptions>(json);
  }
}

mixin LlamaContextOptionsMappable {
  String toJson() {
    return LlamaContextOptionsMapper.ensureInitialized()
        .encodeJson<LlamaContextOptions>(this as LlamaContextOptions);
  }

  Map<String, dynamic> toMap() {
    return LlamaContextOptionsMapper.ensureInitialized()
        .encodeMap<LlamaContextOptions>(this as LlamaContextOptions);
  }

  LlamaContextOptionsCopyWith<
    LlamaContextOptions,
    LlamaContextOptions,
    LlamaContextOptions
  >
  get copyWith =>
      _LlamaContextOptionsCopyWithImpl<
        LlamaContextOptions,
        LlamaContextOptions
      >(this as LlamaContextOptions, $identity, $identity);
  @override
  String toString() {
    return LlamaContextOptionsMapper.ensureInitialized().stringifyValue(
      this as LlamaContextOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlamaContextOptionsMapper.ensureInitialized().equalsValue(
      this as LlamaContextOptions,
      other,
    );
  }

  @override
  int get hashCode {
    return LlamaContextOptionsMapper.ensureInitialized().hashValue(
      this as LlamaContextOptions,
    );
  }
}

extension LlamaContextOptionsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlamaContextOptions, $Out> {
  LlamaContextOptionsCopyWith<$R, LlamaContextOptions, $Out>
  get $asLlamaContextOptions => $base.as(
    (v, t, t2) => _LlamaContextOptionsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class LlamaContextOptionsCopyWith<
  $R,
  $In extends LlamaContextOptions,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? contextSize,
    int? nBatch,
    int? nThreads,
    int? nThreadsBatch,
    bool? useFlashAttn,
    int? maxSequences,
    int? microBatchSize,
    bool? useUnifiedKvCache,
    LlamaKvCacheType? kvCacheType,
    int? contextCheckpointCount,
  });
  LlamaContextOptionsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LlamaContextOptionsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlamaContextOptions, $Out>
    implements LlamaContextOptionsCopyWith<$R, LlamaContextOptions, $Out> {
  _LlamaContextOptionsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlamaContextOptions> $mapper =
      LlamaContextOptionsMapper.ensureInitialized();
  @override
  $R call({
    int? contextSize,
    int? nBatch,
    int? nThreads,
    int? nThreadsBatch,
    Object? useFlashAttn = $none,
    int? maxSequences,
    Object? microBatchSize = $none,
    Object? useUnifiedKvCache = $none,
    LlamaKvCacheType? kvCacheType,
    int? contextCheckpointCount,
  }) => $apply(
    FieldCopyWithData({
      if (contextSize != null) #contextSize: contextSize,
      if (nBatch != null) #nBatch: nBatch,
      if (nThreads != null) #nThreads: nThreads,
      if (nThreadsBatch != null) #nThreadsBatch: nThreadsBatch,
      if (useFlashAttn != $none) #useFlashAttn: useFlashAttn,
      if (maxSequences != null) #maxSequences: maxSequences,
      if (microBatchSize != $none) #microBatchSize: microBatchSize,
      if (useUnifiedKvCache != $none) #useUnifiedKvCache: useUnifiedKvCache,
      if (kvCacheType != null) #kvCacheType: kvCacheType,
      if (contextCheckpointCount != null)
        #contextCheckpointCount: contextCheckpointCount,
    }),
  );
  @override
  LlamaContextOptions $make(CopyWithData data) => LlamaContextOptions(
    contextSize: data.get(#contextSize, or: $value.contextSize),
    nBatch: data.get(#nBatch, or: $value.nBatch),
    nThreads: data.get(#nThreads, or: $value.nThreads),
    nThreadsBatch: data.get(#nThreadsBatch, or: $value.nThreadsBatch),
    useFlashAttn: data.get(#useFlashAttn, or: $value.useFlashAttn),
    maxSequences: data.get(#maxSequences, or: $value.maxSequences),
    microBatchSize: data.get(#microBatchSize, or: $value.microBatchSize),
    useUnifiedKvCache: data.get(
      #useUnifiedKvCache,
      or: $value.useUnifiedKvCache,
    ),
    kvCacheType: data.get(#kvCacheType, or: $value.kvCacheType),
    contextCheckpointCount: data.get(
      #contextCheckpointCount,
      or: $value.contextCheckpointCount,
    ),
  );

  @override
  LlamaContextOptionsCopyWith<$R2, LlamaContextOptions, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LlamaContextOptionsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

