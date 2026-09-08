// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_model_ref.dart';

class ProviderModelRefMapper extends ClassMapperBase<ProviderModelRef> {
  ProviderModelRefMapper._();

  static ProviderModelRefMapper? _instance;
  static ProviderModelRefMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderModelRefMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderModelRef';

  static String _$providerId(ProviderModelRef v) => v.providerId;
  static const Field<ProviderModelRef, String> _f$providerId = Field(
    'providerId',
    _$providerId,
  );
  static String _$modelId(ProviderModelRef v) => v.modelId;
  static const Field<ProviderModelRef, String> _f$modelId = Field(
    'modelId',
    _$modelId,
  );

  @override
  final MappableFields<ProviderModelRef> fields = const {
    #providerId: _f$providerId,
    #modelId: _f$modelId,
  };

  static ProviderModelRef _instantiate(DecodingData data) {
    return ProviderModelRef(
      providerId: data.dec(_f$providerId),
      modelId: data.dec(_f$modelId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderModelRef fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderModelRef>(map);
  }

  static ProviderModelRef fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderModelRef>(json);
  }
}

mixin ProviderModelRefMappable {
  String toJson() {
    return ProviderModelRefMapper.ensureInitialized()
        .encodeJson<ProviderModelRef>(this as ProviderModelRef);
  }

  Map<String, dynamic> toMap() {
    return ProviderModelRefMapper.ensureInitialized()
        .encodeMap<ProviderModelRef>(this as ProviderModelRef);
  }

  ProviderModelRefCopyWith<ProviderModelRef, ProviderModelRef, ProviderModelRef>
  get copyWith =>
      _ProviderModelRefCopyWithImpl<ProviderModelRef, ProviderModelRef>(
        this as ProviderModelRef,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProviderModelRefMapper.ensureInitialized().stringifyValue(
      this as ProviderModelRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderModelRefMapper.ensureInitialized().equalsValue(
      this as ProviderModelRef,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderModelRefMapper.ensureInitialized().hashValue(
      this as ProviderModelRef,
    );
  }
}

extension ProviderModelRefValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderModelRef, $Out> {
  ProviderModelRefCopyWith<$R, ProviderModelRef, $Out>
  get $asProviderModelRef =>
      $base.as((v, t, t2) => _ProviderModelRefCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProviderModelRefCopyWith<$R, $In extends ProviderModelRef, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? providerId, String? modelId});
  ProviderModelRefCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderModelRefCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderModelRef, $Out>
    implements ProviderModelRefCopyWith<$R, ProviderModelRef, $Out> {
  _ProviderModelRefCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderModelRef> $mapper =
      ProviderModelRefMapper.ensureInitialized();
  @override
  $R call({String? providerId, String? modelId}) => $apply(
    FieldCopyWithData({
      if (providerId != null) #providerId: providerId,
      if (modelId != null) #modelId: modelId,
    }),
  );
  @override
  ProviderModelRef $make(CopyWithData data) => ProviderModelRef(
    providerId: data.get(#providerId, or: $value.providerId),
    modelId: data.get(#modelId, or: $value.modelId),
  );

  @override
  ProviderModelRefCopyWith<$R2, ProviderModelRef, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderModelRefCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

