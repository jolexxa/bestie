// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'git.dart';

class GitEntryTypeMapper extends EnumMapper<GitEntryType> {
  GitEntryTypeMapper._();

  static GitEntryTypeMapper? _instance;
  static GitEntryTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GitEntryTypeMapper._());
    }
    return _instance!;
  }

  static GitEntryType fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  GitEntryType decode(dynamic value) {
    switch (value) {
      case r'file':
        return GitEntryType.file;
      case r'directory':
        return GitEntryType.directory;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(GitEntryType self) {
    switch (self) {
      case GitEntryType.file:
        return r'file';
      case GitEntryType.directory:
        return r'directory';
    }
  }
}

extension GitEntryTypeMapperExtension on GitEntryType {
  String toValue() {
    GitEntryTypeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<GitEntryType>(this) as String;
  }
}

class GitTreeEntryMapper extends ClassMapperBase<GitTreeEntry> {
  GitTreeEntryMapper._();

  static GitTreeEntryMapper? _instance;
  static GitTreeEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GitTreeEntryMapper._());
      GitEntryTypeMapper.ensureInitialized();
      GitLastCommitInfoMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GitTreeEntry';

  static String _$path(GitTreeEntry v) => v.path;
  static const Field<GitTreeEntry, String> _f$path = Field('path', _$path);
  static GitEntryType _$type(GitTreeEntry v) => v.type;
  static const Field<GitTreeEntry, GitEntryType> _f$type = Field(
    'type',
    _$type,
  );
  static String? _$oid(GitTreeEntry v) => v.oid;
  static const Field<GitTreeEntry, String> _f$oid = Field(
    'oid',
    _$oid,
    opt: true,
  );
  static int? _$size(GitTreeEntry v) => v.size;
  static const Field<GitTreeEntry, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
  );
  static GitLastCommitInfo? _$lastCommit(GitTreeEntry v) => v.lastCommit;
  static const Field<GitTreeEntry, GitLastCommitInfo> _f$lastCommit = Field(
    'lastCommit',
    _$lastCommit,
    opt: true,
  );

  @override
  final MappableFields<GitTreeEntry> fields = const {
    #path: _f$path,
    #type: _f$type,
    #oid: _f$oid,
    #size: _f$size,
    #lastCommit: _f$lastCommit,
  };

  static GitTreeEntry _instantiate(DecodingData data) {
    return GitTreeEntry(
      path: data.dec(_f$path),
      type: data.dec(_f$type),
      oid: data.dec(_f$oid),
      size: data.dec(_f$size),
      lastCommit: data.dec(_f$lastCommit),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GitTreeEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GitTreeEntry>(map);
  }

  static GitTreeEntry fromJson(String json) {
    return ensureInitialized().decodeJson<GitTreeEntry>(json);
  }
}

mixin GitTreeEntryMappable {
  String toJson() {
    return GitTreeEntryMapper.ensureInitialized().encodeJson<GitTreeEntry>(
      this as GitTreeEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return GitTreeEntryMapper.ensureInitialized().encodeMap<GitTreeEntry>(
      this as GitTreeEntry,
    );
  }

  GitTreeEntryCopyWith<GitTreeEntry, GitTreeEntry, GitTreeEntry> get copyWith =>
      _GitTreeEntryCopyWithImpl<GitTreeEntry, GitTreeEntry>(
        this as GitTreeEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GitTreeEntryMapper.ensureInitialized().stringifyValue(
      this as GitTreeEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return GitTreeEntryMapper.ensureInitialized().equalsValue(
      this as GitTreeEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return GitTreeEntryMapper.ensureInitialized().hashValue(
      this as GitTreeEntry,
    );
  }
}

extension GitTreeEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GitTreeEntry, $Out> {
  GitTreeEntryCopyWith<$R, GitTreeEntry, $Out> get $asGitTreeEntry =>
      $base.as((v, t, t2) => _GitTreeEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GitTreeEntryCopyWith<$R, $In extends GitTreeEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  GitLastCommitInfoCopyWith<$R, GitLastCommitInfo, GitLastCommitInfo>?
  get lastCommit;
  $R call({
    String? path,
    GitEntryType? type,
    String? oid,
    int? size,
    GitLastCommitInfo? lastCommit,
  });
  GitTreeEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GitTreeEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GitTreeEntry, $Out>
    implements GitTreeEntryCopyWith<$R, GitTreeEntry, $Out> {
  _GitTreeEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GitTreeEntry> $mapper =
      GitTreeEntryMapper.ensureInitialized();
  @override
  GitLastCommitInfoCopyWith<$R, GitLastCommitInfo, GitLastCommitInfo>?
  get lastCommit =>
      $value.lastCommit?.copyWith.$chain((v) => call(lastCommit: v));
  @override
  $R call({
    String? path,
    GitEntryType? type,
    Object? oid = $none,
    Object? size = $none,
    Object? lastCommit = $none,
  }) => $apply(
    FieldCopyWithData({
      if (path != null) #path: path,
      if (type != null) #type: type,
      if (oid != $none) #oid: oid,
      if (size != $none) #size: size,
      if (lastCommit != $none) #lastCommit: lastCommit,
    }),
  );
  @override
  GitTreeEntry $make(CopyWithData data) => GitTreeEntry(
    path: data.get(#path, or: $value.path),
    type: data.get(#type, or: $value.type),
    oid: data.get(#oid, or: $value.oid),
    size: data.get(#size, or: $value.size),
    lastCommit: data.get(#lastCommit, or: $value.lastCommit),
  );

  @override
  GitTreeEntryCopyWith<$R2, GitTreeEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GitTreeEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GitLastCommitInfoMapper extends ClassMapperBase<GitLastCommitInfo> {
  GitLastCommitInfoMapper._();

  static GitLastCommitInfoMapper? _instance;
  static GitLastCommitInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GitLastCommitInfoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'GitLastCommitInfo';

  static String _$id(GitLastCommitInfo v) => v.id;
  static const Field<GitLastCommitInfo, String> _f$id = Field('id', _$id);
  static String _$title(GitLastCommitInfo v) => v.title;
  static const Field<GitLastCommitInfo, String> _f$title = Field(
    'title',
    _$title,
  );
  static DateTime _$date(GitLastCommitInfo v) => v.date;
  static const Field<GitLastCommitInfo, DateTime> _f$date = Field(
    'date',
    _$date,
  );

  @override
  final MappableFields<GitLastCommitInfo> fields = const {
    #id: _f$id,
    #title: _f$title,
    #date: _f$date,
  };

  static GitLastCommitInfo _instantiate(DecodingData data) {
    return GitLastCommitInfo(
      id: data.dec(_f$id),
      title: data.dec(_f$title),
      date: data.dec(_f$date),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GitLastCommitInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GitLastCommitInfo>(map);
  }

  static GitLastCommitInfo fromJson(String json) {
    return ensureInitialized().decodeJson<GitLastCommitInfo>(json);
  }
}

mixin GitLastCommitInfoMappable {
  String toJson() {
    return GitLastCommitInfoMapper.ensureInitialized()
        .encodeJson<GitLastCommitInfo>(this as GitLastCommitInfo);
  }

  Map<String, dynamic> toMap() {
    return GitLastCommitInfoMapper.ensureInitialized()
        .encodeMap<GitLastCommitInfo>(this as GitLastCommitInfo);
  }

  GitLastCommitInfoCopyWith<
    GitLastCommitInfo,
    GitLastCommitInfo,
    GitLastCommitInfo
  >
  get copyWith =>
      _GitLastCommitInfoCopyWithImpl<GitLastCommitInfo, GitLastCommitInfo>(
        this as GitLastCommitInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GitLastCommitInfoMapper.ensureInitialized().stringifyValue(
      this as GitLastCommitInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    return GitLastCommitInfoMapper.ensureInitialized().equalsValue(
      this as GitLastCommitInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return GitLastCommitInfoMapper.ensureInitialized().hashValue(
      this as GitLastCommitInfo,
    );
  }
}

extension GitLastCommitInfoValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GitLastCommitInfo, $Out> {
  GitLastCommitInfoCopyWith<$R, GitLastCommitInfo, $Out>
  get $asGitLastCommitInfo => $base.as(
    (v, t, t2) => _GitLastCommitInfoCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class GitLastCommitInfoCopyWith<
  $R,
  $In extends GitLastCommitInfo,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, String? title, DateTime? date});
  GitLastCommitInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _GitLastCommitInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GitLastCommitInfo, $Out>
    implements GitLastCommitInfoCopyWith<$R, GitLastCommitInfo, $Out> {
  _GitLastCommitInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GitLastCommitInfo> $mapper =
      GitLastCommitInfoMapper.ensureInitialized();
  @override
  $R call({String? id, String? title, DateTime? date}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (title != null) #title: title,
      if (date != null) #date: date,
    }),
  );
  @override
  GitLastCommitInfo $make(CopyWithData data) => GitLastCommitInfo(
    id: data.get(#id, or: $value.id),
    title: data.get(#title, or: $value.title),
    date: data.get(#date, or: $value.date),
  );

  @override
  GitLastCommitInfoCopyWith<$R2, GitLastCommitInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GitLastCommitInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

