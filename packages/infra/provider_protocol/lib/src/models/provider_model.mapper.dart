// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_model.dart';

class ProviderModelMapper extends ClassMapperBase<ProviderModel> {
  ProviderModelMapper._();

  static ProviderModelMapper? _instance;
  static ProviderModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderModelMapper._());
      ProviderReasoningMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderModel';

  static String _$id(ProviderModel v) => v.id;
  static const Field<ProviderModel, String> _f$id = Field('id', _$id);
  static String _$name(ProviderModel v) => v.name;
  static const Field<ProviderModel, String> _f$name = Field('name', _$name);
  static bool _$supportsTools(ProviderModel v) => v.supportsTools;
  static const Field<ProviderModel, bool> _f$supportsTools = Field(
    'supportsTools',
    _$supportsTools,
  );
  static int? _$contextLength(ProviderModel v) => v.contextLength;
  static const Field<ProviderModel, int> _f$contextLength = Field(
    'contextLength',
    _$contextLength,
    opt: true,
  );
  static ProviderReasoning? _$reasoning(ProviderModel v) => v.reasoning;
  static const Field<ProviderModel, ProviderReasoning> _f$reasoning = Field(
    'reasoning',
    _$reasoning,
    opt: true,
  );
  static double? _$promptPricePerToken(ProviderModel v) =>
      v.promptPricePerToken;
  static const Field<ProviderModel, double> _f$promptPricePerToken = Field(
    'promptPricePerToken',
    _$promptPricePerToken,
    opt: true,
  );
  static double? _$completionPricePerToken(ProviderModel v) =>
      v.completionPricePerToken;
  static const Field<ProviderModel, double> _f$completionPricePerToken = Field(
    'completionPricePerToken',
    _$completionPricePerToken,
    opt: true,
  );

  @override
  final MappableFields<ProviderModel> fields = const {
    #id: _f$id,
    #name: _f$name,
    #supportsTools: _f$supportsTools,
    #contextLength: _f$contextLength,
    #reasoning: _f$reasoning,
    #promptPricePerToken: _f$promptPricePerToken,
    #completionPricePerToken: _f$completionPricePerToken,
  };

  static ProviderModel _instantiate(DecodingData data) {
    return ProviderModel(
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

  static ProviderModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderModel>(map);
  }

  static ProviderModel fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderModel>(json);
  }
}

mixin ProviderModelMappable {
  String toJson() {
    return ProviderModelMapper.ensureInitialized().encodeJson<ProviderModel>(
      this as ProviderModel,
    );
  }

  Map<String, dynamic> toMap() {
    return ProviderModelMapper.ensureInitialized().encodeMap<ProviderModel>(
      this as ProviderModel,
    );
  }

  ProviderModelCopyWith<ProviderModel, ProviderModel, ProviderModel>
  get copyWith => _ProviderModelCopyWithImpl<ProviderModel, ProviderModel>(
    this as ProviderModel,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ProviderModelMapper.ensureInitialized().stringifyValue(
      this as ProviderModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderModelMapper.ensureInitialized().equalsValue(
      this as ProviderModel,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderModelMapper.ensureInitialized().hashValue(
      this as ProviderModel,
    );
  }
}

extension ProviderModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderModel, $Out> {
  ProviderModelCopyWith<$R, ProviderModel, $Out> get $asProviderModel =>
      $base.as((v, t, t2) => _ProviderModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProviderModelCopyWith<$R, $In extends ProviderModel, $Out>
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
  ProviderModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ProviderModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderModel, $Out>
    implements ProviderModelCopyWith<$R, ProviderModel, $Out> {
  _ProviderModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderModel> $mapper =
      ProviderModelMapper.ensureInitialized();
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
  ProviderModel $make(CopyWithData data) => ProviderModel(
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
  ProviderModelCopyWith<$R2, ProviderModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

