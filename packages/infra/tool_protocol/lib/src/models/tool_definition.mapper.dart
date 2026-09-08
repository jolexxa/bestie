// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'tool_definition.dart';

class ToolDefinitionMapper extends ClassMapperBase<ToolDefinition> {
  ToolDefinitionMapper._();

  static ToolDefinitionMapper? _instance;
  static ToolDefinitionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolDefinitionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ToolDefinition';

  static String _$name(ToolDefinition v) => v.name;
  static const Field<ToolDefinition, String> _f$name = Field('name', _$name);
  static String _$description(ToolDefinition v) => v.description;
  static const Field<ToolDefinition, String> _f$description = Field(
    'description',
    _$description,
  );
  static Map<String, Object?> _$parameters(ToolDefinition v) => v.parameters;
  static const Field<ToolDefinition, Map<String, Object?>> _f$parameters =
      Field('parameters', _$parameters);
  static String _$onProgress(ToolDefinition v) => v.onProgress;
  static const Field<ToolDefinition, String> _f$onProgress = Field(
    'onProgress',
    _$onProgress,
  );
  static String _$onSuccess(ToolDefinition v) => v.onSuccess;
  static const Field<ToolDefinition, String> _f$onSuccess = Field(
    'onSuccess',
    _$onSuccess,
  );
  static String _$onError(ToolDefinition v) => v.onError;
  static const Field<ToolDefinition, String> _f$onError = Field(
    'onError',
    _$onError,
  );
  static String _$onBackgrounded(ToolDefinition v) => v.onBackgrounded;
  static const Field<ToolDefinition, String> _f$onBackgrounded = Field(
    'onBackgrounded',
    _$onBackgrounded,
    opt: true,
    def: '',
  );
  static String _$onJobSuccess(ToolDefinition v) => v.onJobSuccess;
  static const Field<ToolDefinition, String> _f$onJobSuccess = Field(
    'onJobSuccess',
    _$onJobSuccess,
    opt: true,
    def: '',
  );
  static String _$onJobError(ToolDefinition v) => v.onJobError;
  static const Field<ToolDefinition, String> _f$onJobError = Field(
    'onJobError',
    _$onJobError,
    opt: true,
    def: '',
  );

  @override
  final MappableFields<ToolDefinition> fields = const {
    #name: _f$name,
    #description: _f$description,
    #parameters: _f$parameters,
    #onProgress: _f$onProgress,
    #onSuccess: _f$onSuccess,
    #onError: _f$onError,
    #onBackgrounded: _f$onBackgrounded,
    #onJobSuccess: _f$onJobSuccess,
    #onJobError: _f$onJobError,
  };

  static ToolDefinition _instantiate(DecodingData data) {
    return ToolDefinition(
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      parameters: data.dec(_f$parameters),
      onProgress: data.dec(_f$onProgress),
      onSuccess: data.dec(_f$onSuccess),
      onError: data.dec(_f$onError),
      onBackgrounded: data.dec(_f$onBackgrounded),
      onJobSuccess: data.dec(_f$onJobSuccess),
      onJobError: data.dec(_f$onJobError),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolDefinition fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolDefinition>(map);
  }

  static ToolDefinition fromJson(String json) {
    return ensureInitialized().decodeJson<ToolDefinition>(json);
  }
}

mixin ToolDefinitionMappable {
  String toJson() {
    return ToolDefinitionMapper.ensureInitialized().encodeJson<ToolDefinition>(
      this as ToolDefinition,
    );
  }

  Map<String, dynamic> toMap() {
    return ToolDefinitionMapper.ensureInitialized().encodeMap<ToolDefinition>(
      this as ToolDefinition,
    );
  }

  ToolDefinitionCopyWith<ToolDefinition, ToolDefinition, ToolDefinition>
  get copyWith => _ToolDefinitionCopyWithImpl<ToolDefinition, ToolDefinition>(
    this as ToolDefinition,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ToolDefinitionMapper.ensureInitialized().stringifyValue(
      this as ToolDefinition,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolDefinitionMapper.ensureInitialized().equalsValue(
      this as ToolDefinition,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolDefinitionMapper.ensureInitialized().hashValue(
      this as ToolDefinition,
    );
  }
}

extension ToolDefinitionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolDefinition, $Out> {
  ToolDefinitionCopyWith<$R, ToolDefinition, $Out> get $asToolDefinition =>
      $base.as((v, t, t2) => _ToolDefinitionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolDefinitionCopyWith<$R, $In extends ToolDefinition, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get parameters;
  $R call({
    String? name,
    String? description,
    Map<String, Object?>? parameters,
    String? onProgress,
    String? onSuccess,
    String? onError,
    String? onBackgrounded,
    String? onJobSuccess,
    String? onJobError,
  });
  ToolDefinitionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolDefinitionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolDefinition, $Out>
    implements ToolDefinitionCopyWith<$R, ToolDefinition, $Out> {
  _ToolDefinitionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolDefinition> $mapper =
      ToolDefinitionMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get parameters => MapCopyWith(
    $value.parameters,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(parameters: v),
  );
  @override
  $R call({
    String? name,
    String? description,
    Map<String, Object?>? parameters,
    String? onProgress,
    String? onSuccess,
    String? onError,
    String? onBackgrounded,
    String? onJobSuccess,
    String? onJobError,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (description != null) #description: description,
      if (parameters != null) #parameters: parameters,
      if (onProgress != null) #onProgress: onProgress,
      if (onSuccess != null) #onSuccess: onSuccess,
      if (onError != null) #onError: onError,
      if (onBackgrounded != null) #onBackgrounded: onBackgrounded,
      if (onJobSuccess != null) #onJobSuccess: onJobSuccess,
      if (onJobError != null) #onJobError: onJobError,
    }),
  );
  @override
  ToolDefinition $make(CopyWithData data) => ToolDefinition(
    name: data.get(#name, or: $value.name),
    description: data.get(#description, or: $value.description),
    parameters: data.get(#parameters, or: $value.parameters),
    onProgress: data.get(#onProgress, or: $value.onProgress),
    onSuccess: data.get(#onSuccess, or: $value.onSuccess),
    onError: data.get(#onError, or: $value.onError),
    onBackgrounded: data.get(#onBackgrounded, or: $value.onBackgrounded),
    onJobSuccess: data.get(#onJobSuccess, or: $value.onJobSuccess),
    onJobError: data.get(#onJobError, or: $value.onJobError),
  );

  @override
  ToolDefinitionCopyWith<$R2, ToolDefinition, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolDefinitionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

