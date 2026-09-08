// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'resolved_model.dart';

class ResolvedModelMapper extends ClassMapperBase<ResolvedModel> {
  ResolvedModelMapper._();

  static ResolvedModelMapper? _instance;
  static ResolvedModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ResolvedModelMapper._());
      ProviderModelRefMapper.ensureInitialized();
      ProviderReasoningMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ResolvedModel';

  static ProviderModelRef _$ref(ResolvedModel v) => v.ref;
  static const Field<ResolvedModel, ProviderModelRef> _f$ref = Field(
    'ref',
    _$ref,
  );
  static String _$name(ResolvedModel v) => v.name;
  static const Field<ResolvedModel, String> _f$name = Field('name', _$name);
  static int _$contextWindow(ResolvedModel v) => v.contextWindow;
  static const Field<ResolvedModel, int> _f$contextWindow = Field(
    'contextWindow',
    _$contextWindow,
  );
  static bool _$supportsTools(ResolvedModel v) => v.supportsTools;
  static const Field<ResolvedModel, bool> _f$supportsTools = Field(
    'supportsTools',
    _$supportsTools,
  );
  static ProviderReasoning? _$reasoning(ResolvedModel v) => v.reasoning;
  static const Field<ResolvedModel, ProviderReasoning> _f$reasoning = Field(
    'reasoning',
    _$reasoning,
    opt: true,
  );

  @override
  final MappableFields<ResolvedModel> fields = const {
    #ref: _f$ref,
    #name: _f$name,
    #contextWindow: _f$contextWindow,
    #supportsTools: _f$supportsTools,
    #reasoning: _f$reasoning,
  };

  static ResolvedModel _instantiate(DecodingData data) {
    return ResolvedModel(
      ref: data.dec(_f$ref),
      name: data.dec(_f$name),
      contextWindow: data.dec(_f$contextWindow),
      supportsTools: data.dec(_f$supportsTools),
      reasoning: data.dec(_f$reasoning),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ResolvedModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ResolvedModel>(map);
  }

  static ResolvedModel fromJson(String json) {
    return ensureInitialized().decodeJson<ResolvedModel>(json);
  }
}

mixin ResolvedModelMappable {
  String toJson() {
    return ResolvedModelMapper.ensureInitialized().encodeJson<ResolvedModel>(
      this as ResolvedModel,
    );
  }

  Map<String, dynamic> toMap() {
    return ResolvedModelMapper.ensureInitialized().encodeMap<ResolvedModel>(
      this as ResolvedModel,
    );
  }

  ResolvedModelCopyWith<ResolvedModel, ResolvedModel, ResolvedModel>
  get copyWith => _ResolvedModelCopyWithImpl<ResolvedModel, ResolvedModel>(
    this as ResolvedModel,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ResolvedModelMapper.ensureInitialized().stringifyValue(
      this as ResolvedModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return ResolvedModelMapper.ensureInitialized().equalsValue(
      this as ResolvedModel,
      other,
    );
  }

  @override
  int get hashCode {
    return ResolvedModelMapper.ensureInitialized().hashValue(
      this as ResolvedModel,
    );
  }
}

extension ResolvedModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ResolvedModel, $Out> {
  ResolvedModelCopyWith<$R, ResolvedModel, $Out> get $asResolvedModel =>
      $base.as((v, t, t2) => _ResolvedModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ResolvedModelCopyWith<$R, $In extends ResolvedModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef> get ref;
  ProviderReasoningCopyWith<$R, ProviderReasoning, ProviderReasoning>?
  get reasoning;
  $R call({
    ProviderModelRef? ref,
    String? name,
    int? contextWindow,
    bool? supportsTools,
    ProviderReasoning? reasoning,
  });
  ResolvedModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ResolvedModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ResolvedModel, $Out>
    implements ResolvedModelCopyWith<$R, ResolvedModel, $Out> {
  _ResolvedModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ResolvedModel> $mapper =
      ResolvedModelMapper.ensureInitialized();
  @override
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef> get ref =>
      $value.ref.copyWith.$chain((v) => call(ref: v));
  @override
  ProviderReasoningCopyWith<$R, ProviderReasoning, ProviderReasoning>?
  get reasoning => $value.reasoning?.copyWith.$chain((v) => call(reasoning: v));
  @override
  $R call({
    ProviderModelRef? ref,
    String? name,
    int? contextWindow,
    bool? supportsTools,
    Object? reasoning = $none,
  }) => $apply(
    FieldCopyWithData({
      if (ref != null) #ref: ref,
      if (name != null) #name: name,
      if (contextWindow != null) #contextWindow: contextWindow,
      if (supportsTools != null) #supportsTools: supportsTools,
      if (reasoning != $none) #reasoning: reasoning,
    }),
  );
  @override
  ResolvedModel $make(CopyWithData data) => ResolvedModel(
    ref: data.get(#ref, or: $value.ref),
    name: data.get(#name, or: $value.name),
    contextWindow: data.get(#contextWindow, or: $value.contextWindow),
    supportsTools: data.get(#supportsTools, or: $value.supportsTools),
    reasoning: data.get(#reasoning, or: $value.reasoning),
  );

  @override
  ResolvedModelCopyWith<$R2, ResolvedModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ResolvedModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

