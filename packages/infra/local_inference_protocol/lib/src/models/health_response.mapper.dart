// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'health_response.dart';

class HealthResponseMapper extends ClassMapperBase<HealthResponse> {
  HealthResponseMapper._();

  static HealthResponseMapper? _instance;
  static HealthResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HealthResponseMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'HealthResponse';

  static int _$protocolVersion(HealthResponse v) => v.protocolVersion;
  static const Field<HealthResponse, int> _f$protocolVersion = Field(
    'protocolVersion',
    _$protocolVersion,
    key: r'protocol_version',
  );
  static String _$serverVersion(HealthResponse v) => v.serverVersion;
  static const Field<HealthResponse, String> _f$serverVersion = Field(
    'serverVersion',
    _$serverVersion,
    key: r'server_version',
  );
  static int _$pid(HealthResponse v) => v.pid;
  static const Field<HealthResponse, int> _f$pid = Field('pid', _$pid);

  @override
  final MappableFields<HealthResponse> fields = const {
    #protocolVersion: _f$protocolVersion,
    #serverVersion: _f$serverVersion,
    #pid: _f$pid,
  };

  static HealthResponse _instantiate(DecodingData data) {
    return HealthResponse(
      protocolVersion: data.dec(_f$protocolVersion),
      serverVersion: data.dec(_f$serverVersion),
      pid: data.dec(_f$pid),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HealthResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HealthResponse>(map);
  }

  static HealthResponse fromJson(String json) {
    return ensureInitialized().decodeJson<HealthResponse>(json);
  }
}

mixin HealthResponseMappable {
  String toJson() {
    return HealthResponseMapper.ensureInitialized().encodeJson<HealthResponse>(
      this as HealthResponse,
    );
  }

  Map<String, dynamic> toMap() {
    return HealthResponseMapper.ensureInitialized().encodeMap<HealthResponse>(
      this as HealthResponse,
    );
  }

  HealthResponseCopyWith<HealthResponse, HealthResponse, HealthResponse>
  get copyWith => _HealthResponseCopyWithImpl<HealthResponse, HealthResponse>(
    this as HealthResponse,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return HealthResponseMapper.ensureInitialized().stringifyValue(
      this as HealthResponse,
    );
  }

  @override
  bool operator ==(Object other) {
    return HealthResponseMapper.ensureInitialized().equalsValue(
      this as HealthResponse,
      other,
    );
  }

  @override
  int get hashCode {
    return HealthResponseMapper.ensureInitialized().hashValue(
      this as HealthResponse,
    );
  }
}

extension HealthResponseValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HealthResponse, $Out> {
  HealthResponseCopyWith<$R, HealthResponse, $Out> get $asHealthResponse =>
      $base.as((v, t, t2) => _HealthResponseCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HealthResponseCopyWith<$R, $In extends HealthResponse, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? protocolVersion, String? serverVersion, int? pid});
  HealthResponseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _HealthResponseCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HealthResponse, $Out>
    implements HealthResponseCopyWith<$R, HealthResponse, $Out> {
  _HealthResponseCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HealthResponse> $mapper =
      HealthResponseMapper.ensureInitialized();
  @override
  $R call({int? protocolVersion, String? serverVersion, int? pid}) => $apply(
    FieldCopyWithData({
      if (protocolVersion != null) #protocolVersion: protocolVersion,
      if (serverVersion != null) #serverVersion: serverVersion,
      if (pid != null) #pid: pid,
    }),
  );
  @override
  HealthResponse $make(CopyWithData data) => HealthResponse(
    protocolVersion: data.get(#protocolVersion, or: $value.protocolVersion),
    serverVersion: data.get(#serverVersion, or: $value.serverVersion),
    pid: data.get(#pid, or: $value.pid),
  );

  @override
  HealthResponseCopyWith<$R2, HealthResponse, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HealthResponseCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

