// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'inference_lock_file.dart';

class InferenceLockFileMapper extends ClassMapperBase<InferenceLockFile> {
  InferenceLockFileMapper._();

  static InferenceLockFileMapper? _instance;
  static InferenceLockFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = InferenceLockFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'InferenceLockFile';

  static int _$pid(InferenceLockFile v) => v.pid;
  static const Field<InferenceLockFile, int> _f$pid = Field('pid', _$pid);
  static int _$port(InferenceLockFile v) => v.port;
  static const Field<InferenceLockFile, int> _f$port = Field('port', _$port);
  static int _$protocolVersion(InferenceLockFile v) => v.protocolVersion;
  static const Field<InferenceLockFile, int> _f$protocolVersion = Field(
    'protocolVersion',
    _$protocolVersion,
    key: r'protocol_version',
  );

  @override
  final MappableFields<InferenceLockFile> fields = const {
    #pid: _f$pid,
    #port: _f$port,
    #protocolVersion: _f$protocolVersion,
  };

  static InferenceLockFile _instantiate(DecodingData data) {
    return InferenceLockFile(
      pid: data.dec(_f$pid),
      port: data.dec(_f$port),
      protocolVersion: data.dec(_f$protocolVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static InferenceLockFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<InferenceLockFile>(map);
  }

  static InferenceLockFile fromJson(String json) {
    return ensureInitialized().decodeJson<InferenceLockFile>(json);
  }
}

mixin InferenceLockFileMappable {
  String toJson() {
    return InferenceLockFileMapper.ensureInitialized()
        .encodeJson<InferenceLockFile>(this as InferenceLockFile);
  }

  Map<String, dynamic> toMap() {
    return InferenceLockFileMapper.ensureInitialized()
        .encodeMap<InferenceLockFile>(this as InferenceLockFile);
  }

  InferenceLockFileCopyWith<
    InferenceLockFile,
    InferenceLockFile,
    InferenceLockFile
  >
  get copyWith =>
      _InferenceLockFileCopyWithImpl<InferenceLockFile, InferenceLockFile>(
        this as InferenceLockFile,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return InferenceLockFileMapper.ensureInitialized().stringifyValue(
      this as InferenceLockFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return InferenceLockFileMapper.ensureInitialized().equalsValue(
      this as InferenceLockFile,
      other,
    );
  }

  @override
  int get hashCode {
    return InferenceLockFileMapper.ensureInitialized().hashValue(
      this as InferenceLockFile,
    );
  }
}

extension InferenceLockFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, InferenceLockFile, $Out> {
  InferenceLockFileCopyWith<$R, InferenceLockFile, $Out>
  get $asInferenceLockFile => $base.as(
    (v, t, t2) => _InferenceLockFileCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class InferenceLockFileCopyWith<
  $R,
  $In extends InferenceLockFile,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? pid, int? port, int? protocolVersion});
  InferenceLockFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _InferenceLockFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, InferenceLockFile, $Out>
    implements InferenceLockFileCopyWith<$R, InferenceLockFile, $Out> {
  _InferenceLockFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<InferenceLockFile> $mapper =
      InferenceLockFileMapper.ensureInitialized();
  @override
  $R call({int? pid, int? port, int? protocolVersion}) => $apply(
    FieldCopyWithData({
      if (pid != null) #pid: pid,
      if (port != null) #port: port,
      if (protocolVersion != null) #protocolVersion: protocolVersion,
    }),
  );
  @override
  InferenceLockFile $make(CopyWithData data) => InferenceLockFile(
    pid: data.get(#pid, or: $value.pid),
    port: data.get(#port, or: $value.port),
    protocolVersion: data.get(#protocolVersion, or: $value.protocolVersion),
  );

  @override
  InferenceLockFileCopyWith<$R2, InferenceLockFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _InferenceLockFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

