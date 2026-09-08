// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_descriptor.dart';

class ProviderDescriptorMapper extends ClassMapperBase<ProviderDescriptor> {
  ProviderDescriptorMapper._();

  static ProviderDescriptorMapper? _instance;
  static ProviderDescriptorMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderDescriptorMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderDescriptor';

  static String _$id(ProviderDescriptor v) => v.id;
  static const Field<ProviderDescriptor, String> _f$id = Field('id', _$id);
  static String _$displayName(ProviderDescriptor v) => v.displayName;
  static const Field<ProviderDescriptor, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static bool _$requiresApiKey(ProviderDescriptor v) => v.requiresApiKey;
  static const Field<ProviderDescriptor, bool> _f$requiresApiKey = Field(
    'requiresApiKey',
    _$requiresApiKey,
  );
  static InferenceDialect _$dialect(ProviderDescriptor v) => v.dialect;
  static const Field<ProviderDescriptor, InferenceDialect> _f$dialect = Field(
    'dialect',
    _$dialect,
  );
  static bool _$requiresBaseUrl(ProviderDescriptor v) => v.requiresBaseUrl;
  static const Field<ProviderDescriptor, bool> _f$requiresBaseUrl = Field(
    'requiresBaseUrl',
    _$requiresBaseUrl,
    opt: true,
    def: false,
  );
  static Uri? _$baseUrl(ProviderDescriptor v) => v.baseUrl;
  static const Field<ProviderDescriptor, Uri> _f$baseUrl = Field(
    'baseUrl',
    _$baseUrl,
    opt: true,
  );
  static String? _$catalogId(ProviderDescriptor v) => v.catalogId;
  static const Field<ProviderDescriptor, String> _f$catalogId = Field(
    'catalogId',
    _$catalogId,
    opt: true,
  );

  @override
  final MappableFields<ProviderDescriptor> fields = const {
    #id: _f$id,
    #displayName: _f$displayName,
    #requiresApiKey: _f$requiresApiKey,
    #dialect: _f$dialect,
    #requiresBaseUrl: _f$requiresBaseUrl,
    #baseUrl: _f$baseUrl,
    #catalogId: _f$catalogId,
  };

  static ProviderDescriptor _instantiate(DecodingData data) {
    return ProviderDescriptor(
      id: data.dec(_f$id),
      displayName: data.dec(_f$displayName),
      requiresApiKey: data.dec(_f$requiresApiKey),
      dialect: data.dec(_f$dialect),
      requiresBaseUrl: data.dec(_f$requiresBaseUrl),
      baseUrl: data.dec(_f$baseUrl),
      catalogId: data.dec(_f$catalogId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderDescriptor fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderDescriptor>(map);
  }

  static ProviderDescriptor fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderDescriptor>(json);
  }
}

mixin ProviderDescriptorMappable {
  String toJson() {
    return ProviderDescriptorMapper.ensureInitialized()
        .encodeJson<ProviderDescriptor>(this as ProviderDescriptor);
  }

  Map<String, dynamic> toMap() {
    return ProviderDescriptorMapper.ensureInitialized()
        .encodeMap<ProviderDescriptor>(this as ProviderDescriptor);
  }

  ProviderDescriptorCopyWith<
    ProviderDescriptor,
    ProviderDescriptor,
    ProviderDescriptor
  >
  get copyWith =>
      _ProviderDescriptorCopyWithImpl<ProviderDescriptor, ProviderDescriptor>(
        this as ProviderDescriptor,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProviderDescriptorMapper.ensureInitialized().stringifyValue(
      this as ProviderDescriptor,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderDescriptorMapper.ensureInitialized().equalsValue(
      this as ProviderDescriptor,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderDescriptorMapper.ensureInitialized().hashValue(
      this as ProviderDescriptor,
    );
  }
}

extension ProviderDescriptorValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderDescriptor, $Out> {
  ProviderDescriptorCopyWith<$R, ProviderDescriptor, $Out>
  get $asProviderDescriptor => $base.as(
    (v, t, t2) => _ProviderDescriptorCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProviderDescriptorCopyWith<
  $R,
  $In extends ProviderDescriptor,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? displayName,
    bool? requiresApiKey,
    InferenceDialect? dialect,
    bool? requiresBaseUrl,
    Uri? baseUrl,
    String? catalogId,
  });
  ProviderDescriptorCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderDescriptorCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderDescriptor, $Out>
    implements ProviderDescriptorCopyWith<$R, ProviderDescriptor, $Out> {
  _ProviderDescriptorCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderDescriptor> $mapper =
      ProviderDescriptorMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? displayName,
    bool? requiresApiKey,
    InferenceDialect? dialect,
    bool? requiresBaseUrl,
    Object? baseUrl = $none,
    Object? catalogId = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (displayName != null) #displayName: displayName,
      if (requiresApiKey != null) #requiresApiKey: requiresApiKey,
      if (dialect != null) #dialect: dialect,
      if (requiresBaseUrl != null) #requiresBaseUrl: requiresBaseUrl,
      if (baseUrl != $none) #baseUrl: baseUrl,
      if (catalogId != $none) #catalogId: catalogId,
    }),
  );
  @override
  ProviderDescriptor $make(CopyWithData data) => ProviderDescriptor(
    id: data.get(#id, or: $value.id),
    displayName: data.get(#displayName, or: $value.displayName),
    requiresApiKey: data.get(#requiresApiKey, or: $value.requiresApiKey),
    dialect: data.get(#dialect, or: $value.dialect),
    requiresBaseUrl: data.get(#requiresBaseUrl, or: $value.requiresBaseUrl),
    baseUrl: data.get(#baseUrl, or: $value.baseUrl),
    catalogId: data.get(#catalogId, or: $value.catalogId),
  );

  @override
  ProviderDescriptorCopyWith<$R2, ProviderDescriptor, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderDescriptorCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

