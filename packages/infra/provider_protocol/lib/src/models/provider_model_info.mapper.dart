// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_model_info.dart';

class ProviderModelInfoMapper extends ClassMapperBase<ProviderModelInfo> {
  ProviderModelInfoMapper._();

  static ProviderModelInfoMapper? _instance;
  static ProviderModelInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderModelInfoMapper._());
      ProviderReasoningMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderModelInfo';

  static String _$id(ProviderModelInfo v) => v.id;
  static const Field<ProviderModelInfo, String> _f$id = Field('id', _$id);
  static String _$name(ProviderModelInfo v) => v.name;
  static const Field<ProviderModelInfo, String> _f$name = Field('name', _$name);
  static bool _$supportsTools(ProviderModelInfo v) => v.supportsTools;
  static const Field<ProviderModelInfo, bool> _f$supportsTools = Field(
    'supportsTools',
    _$supportsTools,
  );
  static int? _$contextLength(ProviderModelInfo v) => v.contextLength;
  static const Field<ProviderModelInfo, int> _f$contextLength = Field(
    'contextLength',
    _$contextLength,
    opt: true,
  );
  static ProviderReasoning? _$reasoning(ProviderModelInfo v) => v.reasoning;
  static const Field<ProviderModelInfo, ProviderReasoning> _f$reasoning = Field(
    'reasoning',
    _$reasoning,
    opt: true,
  );
  static double? _$promptPricePerToken(ProviderModelInfo v) =>
      v.promptPricePerToken;
  static const Field<ProviderModelInfo, double> _f$promptPricePerToken = Field(
    'promptPricePerToken',
    _$promptPricePerToken,
    opt: true,
  );
  static double? _$completionPricePerToken(ProviderModelInfo v) =>
      v.completionPricePerToken;
  static const Field<ProviderModelInfo, double> _f$completionPricePerToken =
      Field('completionPricePerToken', _$completionPricePerToken, opt: true);

  @override
  final MappableFields<ProviderModelInfo> fields = const {
    #id: _f$id,
    #name: _f$name,
    #supportsTools: _f$supportsTools,
    #contextLength: _f$contextLength,
    #reasoning: _f$reasoning,
    #promptPricePerToken: _f$promptPricePerToken,
    #completionPricePerToken: _f$completionPricePerToken,
  };

  static ProviderModelInfo _instantiate(DecodingData data) {
    return ProviderModelInfo(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      supportsTools: data.dec(_f$supportsTools),
      contextLength: data.dec(_f$contextLength),
      reasoning: data.dec(_f$reasoning),
      promptPricePerToken: data.dec(_f$promptPricePerToken),
      completionPricePerToken: data.dec(_f$completionPricePerToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderModelInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderModelInfo>(map);
  }

  static ProviderModelInfo fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderModelInfo>(json);
  }
}

mixin ProviderModelInfoMappable {
  String toJson() {
    return ProviderModelInfoMapper.ensureInitialized()
        .encodeJson<ProviderModelInfo>(this as ProviderModelInfo);
  }

  Map<String, dynamic> toMap() {
    return ProviderModelInfoMapper.ensureInitialized()
        .encodeMap<ProviderModelInfo>(this as ProviderModelInfo);
  }

  ProviderModelInfoCopyWith<
    ProviderModelInfo,
    ProviderModelInfo,
    ProviderModelInfo
  >
  get copyWith =>
      _ProviderModelInfoCopyWithImpl<ProviderModelInfo, ProviderModelInfo>(
        this as ProviderModelInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProviderModelInfoMapper.ensureInitialized().stringifyValue(
      this as ProviderModelInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderModelInfoMapper.ensureInitialized().equalsValue(
      this as ProviderModelInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderModelInfoMapper.ensureInitialized().hashValue(
      this as ProviderModelInfo,
    );
  }
}

extension ProviderModelInfoValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderModelInfo, $Out> {
  ProviderModelInfoCopyWith<$R, ProviderModelInfo, $Out>
  get $asProviderModelInfo => $base.as(
    (v, t, t2) => _ProviderModelInfoCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProviderModelInfoCopyWith<
  $R,
  $In extends ProviderModelInfo,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ProviderReasoningCopyWith<$R, ProviderReasoning, ProviderReasoning>?
  get reasoning;
  $R call({
    String? id,
    String? name,
    bool? supportsTools,
    int? contextLength,
    ProviderReasoning? reasoning,
    double? promptPricePerToken,
    double? completionPricePerToken,
  });
  ProviderModelInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderModelInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderModelInfo, $Out>
    implements ProviderModelInfoCopyWith<$R, ProviderModelInfo, $Out> {
  _ProviderModelInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderModelInfo> $mapper =
      ProviderModelInfoMapper.ensureInitialized();
  @override
  ProviderReasoningCopyWith<$R, ProviderReasoning, ProviderReasoning>?
  get reasoning => $value.reasoning?.copyWith.$chain((v) => call(reasoning: v));
  @override
  $R call({
    String? id,
    String? name,
    bool? supportsTools,
    Object? contextLength = $none,
    Object? reasoning = $none,
    Object? promptPricePerToken = $none,
    Object? completionPricePerToken = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (supportsTools != null) #supportsTools: supportsTools,
      if (contextLength != $none) #contextLength: contextLength,
      if (reasoning != $none) #reasoning: reasoning,
      if (promptPricePerToken != $none)
        #promptPricePerToken: promptPricePerToken,
      if (completionPricePerToken != $none)
        #completionPricePerToken: completionPricePerToken,
    }),
  );
  @override
  ProviderModelInfo $make(CopyWithData data) => ProviderModelInfo(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    supportsTools: data.get(#supportsTools, or: $value.supportsTools),
    contextLength: data.get(#contextLength, or: $value.contextLength),
    reasoning: data.get(#reasoning, or: $value.reasoning),
    promptPricePerToken: data.get(
      #promptPricePerToken,
      or: $value.promptPricePerToken,
    ),
    completionPricePerToken: data.get(
      #completionPricePerToken,
      or: $value.completionPricePerToken,
    ),
  );

  @override
  ProviderModelInfoCopyWith<$R2, ProviderModelInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderModelInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

