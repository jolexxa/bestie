// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'server_error.dart';

class ServerErrorMapper extends ClassMapperBase<ServerError> {
  ServerErrorMapper._();

  static ServerErrorMapper? _instance;
  static ServerErrorMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ServerErrorMapper._());
      ServerBusyMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ServerError';

  @override
  final MappableFields<ServerError> fields = const {};

  static ServerError _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ServerError',
      'error',
      '${data.value['error']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ServerError fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ServerError>(map);
  }

  static ServerError fromJson(String json) {
    return ensureInitialized().decodeJson<ServerError>(json);
  }
}

mixin ServerErrorMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ServerErrorCopyWith<ServerError, ServerError, ServerError> get copyWith;
}

abstract class ServerErrorCopyWith<$R, $In extends ServerError, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ServerErrorCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class ServerBusyMapper extends SubClassMapperBase<ServerBusy> {
  ServerBusyMapper._();

  static ServerBusyMapper? _instance;
  static ServerBusyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ServerBusyMapper._());
      ServerErrorMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ServerBusy';

  static int _$ownerPid(ServerBusy v) => v.ownerPid;
  static const Field<ServerBusy, int> _f$ownerPid = Field(
    'ownerPid',
    _$ownerPid,
    key: r'owner_pid',
  );

  @override
  final MappableFields<ServerBusy> fields = const {#ownerPid: _f$ownerPid};

  @override
  final String discriminatorKey = 'error';
  @override
  final dynamic discriminatorValue = 'server_busy';
  @override
  late final ClassMapperBase superMapper =
      ServerErrorMapper.ensureInitialized();

  static ServerBusy _instantiate(DecodingData data) {
    return ServerBusy(ownerPid: data.dec(_f$ownerPid));
  }

  @override
  final Function instantiate = _instantiate;

  static ServerBusy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ServerBusy>(map);
  }

  static ServerBusy fromJson(String json) {
    return ensureInitialized().decodeJson<ServerBusy>(json);
  }
}

mixin ServerBusyMappable {
  String toJson() {
    return ServerBusyMapper.ensureInitialized().encodeJson<ServerBusy>(
      this as ServerBusy,
    );
  }

  Map<String, dynamic> toMap() {
    return ServerBusyMapper.ensureInitialized().encodeMap<ServerBusy>(
      this as ServerBusy,
    );
  }

  ServerBusyCopyWith<ServerBusy, ServerBusy, ServerBusy> get copyWith =>
      _ServerBusyCopyWithImpl<ServerBusy, ServerBusy>(
        this as ServerBusy,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ServerBusyMapper.ensureInitialized().stringifyValue(
      this as ServerBusy,
    );
  }

  @override
  bool operator ==(Object other) {
    return ServerBusyMapper.ensureInitialized().equalsValue(
      this as ServerBusy,
      other,
    );
  }

  @override
  int get hashCode {
    return ServerBusyMapper.ensureInitialized().hashValue(this as ServerBusy);
  }
}

extension ServerBusyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ServerBusy, $Out> {
  ServerBusyCopyWith<$R, ServerBusy, $Out> get $asServerBusy =>
      $base.as((v, t, t2) => _ServerBusyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ServerBusyCopyWith<$R, $In extends ServerBusy, $Out>
    implements ServerErrorCopyWith<$R, $In, $Out> {
  @override
  $R call({int? ownerPid});
  ServerBusyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ServerBusyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ServerBusy, $Out>
    implements ServerBusyCopyWith<$R, ServerBusy, $Out> {
  _ServerBusyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ServerBusy> $mapper =
      ServerBusyMapper.ensureInitialized();
  @override
  $R call({int? ownerPid}) =>
      $apply(FieldCopyWithData({if (ownerPid != null) #ownerPid: ownerPid}));
  @override
  ServerBusy $make(CopyWithData data) =>
      ServerBusy(ownerPid: data.get(#ownerPid, or: $value.ownerPid));

  @override
  ServerBusyCopyWith<$R2, ServerBusy, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ServerBusyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

