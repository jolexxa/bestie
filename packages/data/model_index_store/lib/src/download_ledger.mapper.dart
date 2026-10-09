// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'download_ledger.dart';

class DownloadRecordStatusMapper extends EnumMapper<DownloadRecordStatus> {
  DownloadRecordStatusMapper._();

  static DownloadRecordStatusMapper? _instance;
  static DownloadRecordStatusMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DownloadRecordStatusMapper._());
    }
    return _instance!;
  }

  static DownloadRecordStatus fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DownloadRecordStatus decode(dynamic value) {
    switch (value) {
      case r'pending':
        return DownloadRecordStatus.pending;
      case r'paused':
        return DownloadRecordStatus.paused;
      case r'failed':
        return DownloadRecordStatus.failed;
      case r'completed':
        return DownloadRecordStatus.completed;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(DownloadRecordStatus self) {
    switch (self) {
      case DownloadRecordStatus.pending:
        return r'pending';
      case DownloadRecordStatus.paused:
        return r'paused';
      case DownloadRecordStatus.failed:
        return r'failed';
      case DownloadRecordStatus.completed:
        return r'completed';
    }
  }
}

extension DownloadRecordStatusMapperExtension on DownloadRecordStatus {
  String toValue() {
    DownloadRecordStatusMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DownloadRecordStatus>(this)
        as String;
  }
}

class DownloadLedgerMapper extends ClassMapperBase<DownloadLedger> {
  DownloadLedgerMapper._();

  static DownloadLedgerMapper? _instance;
  static DownloadLedgerMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DownloadLedgerMapper._());
      DownloadRecordMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DownloadLedger';

  static int _$version(DownloadLedger v) => v.version;
  static const Field<DownloadLedger, int> _f$version = Field(
    'version',
    _$version,
  );
  static List<DownloadRecord> _$downloads(DownloadLedger v) => v.downloads;
  static const Field<DownloadLedger, List<DownloadRecord>> _f$downloads = Field(
    'downloads',
    _$downloads,
  );

  @override
  final MappableFields<DownloadLedger> fields = const {
    #version: _f$version,
    #downloads: _f$downloads,
  };

  static DownloadLedger _instantiate(DecodingData data) {
    return DownloadLedger(
      version: data.dec(_f$version),
      downloads: data.dec(_f$downloads),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DownloadLedger fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DownloadLedger>(map);
  }

  static DownloadLedger fromJson(String json) {
    return ensureInitialized().decodeJson<DownloadLedger>(json);
  }
}

mixin DownloadLedgerMappable {
  String toJson() {
    return DownloadLedgerMapper.ensureInitialized().encodeJson<DownloadLedger>(
      this as DownloadLedger,
    );
  }

  Map<String, dynamic> toMap() {
    return DownloadLedgerMapper.ensureInitialized().encodeMap<DownloadLedger>(
      this as DownloadLedger,
    );
  }

  DownloadLedgerCopyWith<DownloadLedger, DownloadLedger, DownloadLedger>
  get copyWith => _DownloadLedgerCopyWithImpl<DownloadLedger, DownloadLedger>(
    this as DownloadLedger,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return DownloadLedgerMapper.ensureInitialized().stringifyValue(
      this as DownloadLedger,
    );
  }

  @override
  bool operator ==(Object other) {
    return DownloadLedgerMapper.ensureInitialized().equalsValue(
      this as DownloadLedger,
      other,
    );
  }

  @override
  int get hashCode {
    return DownloadLedgerMapper.ensureInitialized().hashValue(
      this as DownloadLedger,
    );
  }
}

extension DownloadLedgerValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DownloadLedger, $Out> {
  DownloadLedgerCopyWith<$R, DownloadLedger, $Out> get $asDownloadLedger =>
      $base.as((v, t, t2) => _DownloadLedgerCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DownloadLedgerCopyWith<$R, $In extends DownloadLedger, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    DownloadRecord,
    DownloadRecordCopyWith<$R, DownloadRecord, DownloadRecord>
  >
  get downloads;
  $R call({int? version, List<DownloadRecord>? downloads});
  DownloadLedgerCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DownloadLedgerCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DownloadLedger, $Out>
    implements DownloadLedgerCopyWith<$R, DownloadLedger, $Out> {
  _DownloadLedgerCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DownloadLedger> $mapper =
      DownloadLedgerMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    DownloadRecord,
    DownloadRecordCopyWith<$R, DownloadRecord, DownloadRecord>
  >
  get downloads => ListCopyWith(
    $value.downloads,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(downloads: v),
  );
  @override
  $R call({int? version, List<DownloadRecord>? downloads}) => $apply(
    FieldCopyWithData({
      if (version != null) #version: version,
      if (downloads != null) #downloads: downloads,
    }),
  );
  @override
  DownloadLedger $make(CopyWithData data) => DownloadLedger(
    version: data.get(#version, or: $value.version),
    downloads: data.get(#downloads, or: $value.downloads),
  );

  @override
  DownloadLedgerCopyWith<$R2, DownloadLedger, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DownloadLedgerCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DownloadRecordMapper extends ClassMapperBase<DownloadRecord> {
  DownloadRecordMapper._();

  static DownloadRecordMapper? _instance;
  static DownloadRecordMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DownloadRecordMapper._());
      DownloadRecordFileMapper.ensureInitialized();
      DownloadRecordStatusMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DownloadRecord';

  static String _$id(DownloadRecord v) => v.id;
  static const Field<DownloadRecord, String> _f$id = Field('id', _$id);
  static String _$repo(DownloadRecord v) => v.repo;
  static const Field<DownloadRecord, String> _f$repo = Field('repo', _$repo);
  static String _$quant(DownloadRecord v) => v.quant;
  static const Field<DownloadRecord, String> _f$quant = Field('quant', _$quant);
  static List<DownloadRecordFile> _$files(DownloadRecord v) => v.files;
  static const Field<DownloadRecord, List<DownloadRecordFile>> _f$files = Field(
    'files',
    _$files,
  );
  static DownloadRecordStatus _$status(DownloadRecord v) => v.status;
  static const Field<DownloadRecord, DownloadRecordStatus> _f$status = Field(
    'status',
    _$status,
  );
  static String? _$revision(DownloadRecord v) => v.revision;
  static const Field<DownloadRecord, String> _f$revision = Field(
    'revision',
    _$revision,
    opt: true,
  );
  static int _$receivedBytes(DownloadRecord v) => v.receivedBytes;
  static const Field<DownloadRecord, int> _f$receivedBytes = Field(
    'receivedBytes',
    _$receivedBytes,
    key: r'received_bytes',
    opt: true,
    def: 0,
  );
  static String? _$failure(DownloadRecord v) => v.failure;
  static const Field<DownloadRecord, String> _f$failure = Field(
    'failure',
    _$failure,
    opt: true,
  );

  @override
  final MappableFields<DownloadRecord> fields = const {
    #id: _f$id,
    #repo: _f$repo,
    #quant: _f$quant,
    #files: _f$files,
    #status: _f$status,
    #revision: _f$revision,
    #receivedBytes: _f$receivedBytes,
    #failure: _f$failure,
  };

  static DownloadRecord _instantiate(DecodingData data) {
    return DownloadRecord(
      id: data.dec(_f$id),
      repo: data.dec(_f$repo),
      quant: data.dec(_f$quant),
      files: data.dec(_f$files),
      status: data.dec(_f$status),
      revision: data.dec(_f$revision),
      receivedBytes: data.dec(_f$receivedBytes),
      failure: data.dec(_f$failure),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DownloadRecord fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DownloadRecord>(map);
  }

  static DownloadRecord fromJson(String json) {
    return ensureInitialized().decodeJson<DownloadRecord>(json);
  }
}

mixin DownloadRecordMappable {
  String toJson() {
    return DownloadRecordMapper.ensureInitialized().encodeJson<DownloadRecord>(
      this as DownloadRecord,
    );
  }

  Map<String, dynamic> toMap() {
    return DownloadRecordMapper.ensureInitialized().encodeMap<DownloadRecord>(
      this as DownloadRecord,
    );
  }

  DownloadRecordCopyWith<DownloadRecord, DownloadRecord, DownloadRecord>
  get copyWith => _DownloadRecordCopyWithImpl<DownloadRecord, DownloadRecord>(
    this as DownloadRecord,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return DownloadRecordMapper.ensureInitialized().stringifyValue(
      this as DownloadRecord,
    );
  }

  @override
  bool operator ==(Object other) {
    return DownloadRecordMapper.ensureInitialized().equalsValue(
      this as DownloadRecord,
      other,
    );
  }

  @override
  int get hashCode {
    return DownloadRecordMapper.ensureInitialized().hashValue(
      this as DownloadRecord,
    );
  }
}

extension DownloadRecordValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DownloadRecord, $Out> {
  DownloadRecordCopyWith<$R, DownloadRecord, $Out> get $asDownloadRecord =>
      $base.as((v, t, t2) => _DownloadRecordCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DownloadRecordCopyWith<$R, $In extends DownloadRecord, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    DownloadRecordFile,
    DownloadRecordFileCopyWith<$R, DownloadRecordFile, DownloadRecordFile>
  >
  get files;
  $R call({
    String? id,
    String? repo,
    String? quant,
    List<DownloadRecordFile>? files,
    DownloadRecordStatus? status,
    String? revision,
    int? receivedBytes,
    String? failure,
  });
  DownloadRecordCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DownloadRecordCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DownloadRecord, $Out>
    implements DownloadRecordCopyWith<$R, DownloadRecord, $Out> {
  _DownloadRecordCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DownloadRecord> $mapper =
      DownloadRecordMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    DownloadRecordFile,
    DownloadRecordFileCopyWith<$R, DownloadRecordFile, DownloadRecordFile>
  >
  get files => ListCopyWith(
    $value.files,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(files: v),
  );
  @override
  $R call({
    String? id,
    String? repo,
    String? quant,
    List<DownloadRecordFile>? files,
    DownloadRecordStatus? status,
    Object? revision = $none,
    int? receivedBytes,
    Object? failure = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (repo != null) #repo: repo,
      if (quant != null) #quant: quant,
      if (files != null) #files: files,
      if (status != null) #status: status,
      if (revision != $none) #revision: revision,
      if (receivedBytes != null) #receivedBytes: receivedBytes,
      if (failure != $none) #failure: failure,
    }),
  );
  @override
  DownloadRecord $make(CopyWithData data) => DownloadRecord(
    id: data.get(#id, or: $value.id),
    repo: data.get(#repo, or: $value.repo),
    quant: data.get(#quant, or: $value.quant),
    files: data.get(#files, or: $value.files),
    status: data.get(#status, or: $value.status),
    revision: data.get(#revision, or: $value.revision),
    receivedBytes: data.get(#receivedBytes, or: $value.receivedBytes),
    failure: data.get(#failure, or: $value.failure),
  );

  @override
  DownloadRecordCopyWith<$R2, DownloadRecord, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DownloadRecordCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DownloadRecordFileMapper extends ClassMapperBase<DownloadRecordFile> {
  DownloadRecordFileMapper._();

  static DownloadRecordFileMapper? _instance;
  static DownloadRecordFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DownloadRecordFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DownloadRecordFile';

  static String _$path(DownloadRecordFile v) => v.path;
  static const Field<DownloadRecordFile, String> _f$path = Field(
    'path',
    _$path,
  );
  static String _$url(DownloadRecordFile v) => v.url;
  static const Field<DownloadRecordFile, String> _f$url = Field('url', _$url);
  static int _$bytes(DownloadRecordFile v) => v.bytes;
  static const Field<DownloadRecordFile, int> _f$bytes = Field(
    'bytes',
    _$bytes,
  );
  static String? _$sha256(DownloadRecordFile v) => v.sha256;
  static const Field<DownloadRecordFile, String> _f$sha256 = Field(
    'sha256',
    _$sha256,
    opt: true,
  );

  @override
  final MappableFields<DownloadRecordFile> fields = const {
    #path: _f$path,
    #url: _f$url,
    #bytes: _f$bytes,
    #sha256: _f$sha256,
  };

  static DownloadRecordFile _instantiate(DecodingData data) {
    return DownloadRecordFile(
      path: data.dec(_f$path),
      url: data.dec(_f$url),
      bytes: data.dec(_f$bytes),
      sha256: data.dec(_f$sha256),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DownloadRecordFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DownloadRecordFile>(map);
  }

  static DownloadRecordFile fromJson(String json) {
    return ensureInitialized().decodeJson<DownloadRecordFile>(json);
  }
}

mixin DownloadRecordFileMappable {
  String toJson() {
    return DownloadRecordFileMapper.ensureInitialized()
        .encodeJson<DownloadRecordFile>(this as DownloadRecordFile);
  }

  Map<String, dynamic> toMap() {
    return DownloadRecordFileMapper.ensureInitialized()
        .encodeMap<DownloadRecordFile>(this as DownloadRecordFile);
  }

  DownloadRecordFileCopyWith<
    DownloadRecordFile,
    DownloadRecordFile,
    DownloadRecordFile
  >
  get copyWith =>
      _DownloadRecordFileCopyWithImpl<DownloadRecordFile, DownloadRecordFile>(
        this as DownloadRecordFile,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DownloadRecordFileMapper.ensureInitialized().stringifyValue(
      this as DownloadRecordFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return DownloadRecordFileMapper.ensureInitialized().equalsValue(
      this as DownloadRecordFile,
      other,
    );
  }

  @override
  int get hashCode {
    return DownloadRecordFileMapper.ensureInitialized().hashValue(
      this as DownloadRecordFile,
    );
  }
}

extension DownloadRecordFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DownloadRecordFile, $Out> {
  DownloadRecordFileCopyWith<$R, DownloadRecordFile, $Out>
  get $asDownloadRecordFile => $base.as(
    (v, t, t2) => _DownloadRecordFileCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DownloadRecordFileCopyWith<
  $R,
  $In extends DownloadRecordFile,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? path, String? url, int? bytes, String? sha256});
  DownloadRecordFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DownloadRecordFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DownloadRecordFile, $Out>
    implements DownloadRecordFileCopyWith<$R, DownloadRecordFile, $Out> {
  _DownloadRecordFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DownloadRecordFile> $mapper =
      DownloadRecordFileMapper.ensureInitialized();
  @override
  $R call({String? path, String? url, int? bytes, Object? sha256 = $none}) =>
      $apply(
        FieldCopyWithData({
          if (path != null) #path: path,
          if (url != null) #url: url,
          if (bytes != null) #bytes: bytes,
          if (sha256 != $none) #sha256: sha256,
        }),
      );
  @override
  DownloadRecordFile $make(CopyWithData data) => DownloadRecordFile(
    path: data.get(#path, or: $value.path),
    url: data.get(#url, or: $value.url),
    bytes: data.get(#bytes, or: $value.bytes),
    sha256: data.get(#sha256, or: $value.sha256),
  );

  @override
  DownloadRecordFileCopyWith<$R2, DownloadRecordFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DownloadRecordFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

