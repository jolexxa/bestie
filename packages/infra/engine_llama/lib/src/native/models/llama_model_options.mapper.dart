// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'llama_model_options.dart';

class LlamaModelOptionsMapper extends ClassMapperBase<LlamaModelOptions> {
  LlamaModelOptionsMapper._();

  static LlamaModelOptionsMapper? _instance;
  static LlamaModelOptionsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlamaModelOptionsMapper._());
      LlamaLoadModeMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlamaModelOptions';

  static int? _$nGpuLayers(LlamaModelOptions v) => v.nGpuLayers;
  static const Field<LlamaModelOptions, int> _f$nGpuLayers = Field(
    'nGpuLayers',
    _$nGpuLayers,
    opt: true,
  );
  static int? _$mainGpu(LlamaModelOptions v) => v.mainGpu;
  static const Field<LlamaModelOptions, int> _f$mainGpu = Field(
    'mainGpu',
    _$mainGpu,
    opt: true,
  );
  static int? _$numa(LlamaModelOptions v) => v.numa;
  static const Field<LlamaModelOptions, int> _f$numa = Field(
    'numa',
    _$numa,
    opt: true,
  );
  static LlamaLoadMode? _$loadMode(LlamaModelOptions v) => v.loadMode;
  static const Field<LlamaModelOptions, LlamaLoadMode> _f$loadMode = Field(
    'loadMode',
    _$loadMode,
    opt: true,
  );
  static bool? _$checkTensors(LlamaModelOptions v) => v.checkTensors;
  static const Field<LlamaModelOptions, bool> _f$checkTensors = Field(
    'checkTensors',
    _$checkTensors,
    opt: true,
  );

  @override
  final MappableFields<LlamaModelOptions> fields = const {
    #nGpuLayers: _f$nGpuLayers,
    #mainGpu: _f$mainGpu,
    #numa: _f$numa,
    #loadMode: _f$loadMode,
    #checkTensors: _f$checkTensors,
  };

  static LlamaModelOptions _instantiate(DecodingData data) {
    return LlamaModelOptions(
      nGpuLayers: data.dec(_f$nGpuLayers),
      mainGpu: data.dec(_f$mainGpu),
      numa: data.dec(_f$numa),
      loadMode: data.dec(_f$loadMode),
      checkTensors: data.dec(_f$checkTensors),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlamaModelOptions fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlamaModelOptions>(map);
  }

  static LlamaModelOptions fromJson(String json) {
    return ensureInitialized().decodeJson<LlamaModelOptions>(json);
  }
}

mixin LlamaModelOptionsMappable {
  String toJson() {
    return LlamaModelOptionsMapper.ensureInitialized()
        .encodeJson<LlamaModelOptions>(this as LlamaModelOptions);
  }

  Map<String, dynamic> toMap() {
    return LlamaModelOptionsMapper.ensureInitialized()
        .encodeMap<LlamaModelOptions>(this as LlamaModelOptions);
  }

  LlamaModelOptionsCopyWith<
    LlamaModelOptions,
    LlamaModelOptions,
    LlamaModelOptions
  >
  get copyWith =>
      _LlamaModelOptionsCopyWithImpl<LlamaModelOptions, LlamaModelOptions>(
        this as LlamaModelOptions,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LlamaModelOptionsMapper.ensureInitialized().stringifyValue(
      this as LlamaModelOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    return LlamaModelOptionsMapper.ensureInitialized().equalsValue(
      this as LlamaModelOptions,
      other,
    );
  }

  @override
  int get hashCode {
    return LlamaModelOptionsMapper.ensureInitialized().hashValue(
      this as LlamaModelOptions,
    );
  }
}

extension LlamaModelOptionsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlamaModelOptions, $Out> {
  LlamaModelOptionsCopyWith<$R, LlamaModelOptions, $Out>
  get $asLlamaModelOptions => $base.as(
    (v, t, t2) => _LlamaModelOptionsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class LlamaModelOptionsCopyWith<
  $R,
  $In extends LlamaModelOptions,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? nGpuLayers,
    int? mainGpu,
    int? numa,
    LlamaLoadMode? loadMode,
    bool? checkTensors,
  });
  LlamaModelOptionsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LlamaModelOptionsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlamaModelOptions, $Out>
    implements LlamaModelOptionsCopyWith<$R, LlamaModelOptions, $Out> {
  _LlamaModelOptionsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LlamaModelOptions> $mapper =
      LlamaModelOptionsMapper.ensureInitialized();
  @override
  $R call({
    Object? nGpuLayers = $none,
    Object? mainGpu = $none,
    Object? numa = $none,
    Object? loadMode = $none,
    Object? checkTensors = $none,
  }) => $apply(
    FieldCopyWithData({
      if (nGpuLayers != $none) #nGpuLayers: nGpuLayers,
      if (mainGpu != $none) #mainGpu: mainGpu,
      if (numa != $none) #numa: numa,
      if (loadMode != $none) #loadMode: loadMode,
      if (checkTensors != $none) #checkTensors: checkTensors,
    }),
  );
  @override
  LlamaModelOptions $make(CopyWithData data) => LlamaModelOptions(
    nGpuLayers: data.get(#nGpuLayers, or: $value.nGpuLayers),
    mainGpu: data.get(#mainGpu, or: $value.mainGpu),
    numa: data.get(#numa, or: $value.numa),
    loadMode: data.get(#loadMode, or: $value.loadMode),
    checkTensors: data.get(#checkTensors, or: $value.checkTensors),
  );

  @override
  LlamaModelOptionsCopyWith<$R2, LlamaModelOptions, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LlamaModelOptionsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

