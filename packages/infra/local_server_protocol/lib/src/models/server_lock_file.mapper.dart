// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'server_lock_file.dart';

class ServerLockFileMapper extends ClassMapperBase<ServerLockFile> {
  ServerLockFileMapper._();

  static ServerLockFileMapper? _instance;
  static ServerLockFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ServerLockFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ServerLockFile';

  static int _$pid(ServerLockFile v) => v.pid;
  static const Field<ServerLockFile, int> _f$pid = Field('pid', _$pid);
  static int _$port(ServerLockFile v) => v.port;
  static const Field<ServerLockFile, int> _f$port = Field('port', _$port);
  static int _$protocolVersion(ServerLockFile v) => v.protocolVersion;
  static const Field<ServerLockFile, int> _f$protocolVersion = Field(
    'protocolVersion',
    _$protocolVersion,
    key: r'protocol_version',
  );

  @override
  final MappableFields<ServerLockFile> fields = const {
    #pid: _f$pid,
    #port: _f$port,
    #protocolVersion: _f$protocolVersion,
  };

  static ServerLockFile _instantiate(DecodingData data) {
    return ServerLockFile(
      pid: data.dec(_f$pid),
      port: data.dec(_f$port),
      protocolVersion: data.dec(_f$protocolVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ServerLockFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ServerLockFile>(map);
  }

  static ServerLockFile fromJson(String json) {
    return ensureInitialized().decodeJson<ServerLockFile>(json);
  }
}

mixin ServerLockFileMappable {
  String toJson() {
    return ServerLockFileMapper.ensureInitialized().encodeJson<ServerLockFile>(
      this as ServerLockFile,
    );
  }

  Map<String, dynamic> toMap() {
    return ServerLockFileMapper.ensureInitialized().encodeMap<ServerLockFile>(
      this as ServerLockFile,
    );
  }

  ServerLockFileCopyWith<ServerLockFile, ServerLockFile, ServerLockFile>
  get copyWith => _ServerLockFileCopyWithImpl<ServerLockFile, ServerLockFile>(
    this as ServerLockFile,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ServerLockFileMapper.ensureInitialized().stringifyValue(
      this as ServerLockFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return ServerLockFileMapper.ensureInitialized().equalsValue(
      this as ServerLockFile,
      other,
    );
  }

  @override
  int get hashCode {
    return ServerLockFileMapper.ensureInitialized().hashValue(
      this as ServerLockFile,
    );
  }
}

extension ServerLockFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ServerLockFile, $Out> {
  ServerLockFileCopyWith<$R, ServerLockFile, $Out> get $asServerLockFile =>
      $base.as((v, t, t2) => _ServerLockFileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ServerLockFileCopyWith<$R, $In extends ServerLockFile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? pid, int? port, int? protocolVersion});
  ServerLockFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ServerLockFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ServerLockFile, $Out>
    implements ServerLockFileCopyWith<$R, ServerLockFile, $Out> {
  _ServerLockFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ServerLockFile> $mapper =
      ServerLockFileMapper.ensureInitialized();
  @override
  $R call({int? pid, int? port, int? protocolVersion}) => $apply(
    FieldCopyWithData({
      if (pid != null) #pid: pid,
      if (port != null) #port: port,
      if (protocolVersion != null) #protocolVersion: protocolVersion,
    }),
  );
  @override
  ServerLockFile $make(CopyWithData data) => ServerLockFile(
    pid: data.get(#pid, or: $value.pid),
    port: data.get(#port, or: $value.port),
    protocolVersion: data.get(#protocolVersion, or: $value.protocolVersion),
  );

  @override
  ServerLockFileCopyWith<$R2, ServerLockFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ServerLockFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

