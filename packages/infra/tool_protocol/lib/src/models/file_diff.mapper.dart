// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'file_diff.dart';

class DiffLineKindMapper extends EnumMapper<DiffLineKind> {
  DiffLineKindMapper._();

  static DiffLineKindMapper? _instance;
  static DiffLineKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiffLineKindMapper._());
    }
    return _instance!;
  }

  static DiffLineKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DiffLineKind decode(dynamic value) {
    switch (value) {
      case r'context':
        return DiffLineKind.context;
      case r'added':
        return DiffLineKind.added;
      case r'removed':
        return DiffLineKind.removed;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(DiffLineKind self) {
    switch (self) {
      case DiffLineKind.context:
        return r'context';
      case DiffLineKind.added:
        return r'added';
      case DiffLineKind.removed:
        return r'removed';
    }
  }
}

extension DiffLineKindMapperExtension on DiffLineKind {
  String toValue() {
    DiffLineKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DiffLineKind>(this) as String;
  }
}

class DiffLineMapper extends ClassMapperBase<DiffLine> {
  DiffLineMapper._();

  static DiffLineMapper? _instance;
  static DiffLineMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiffLineMapper._());
      DiffLineKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiffLine';

  static DiffLineKind _$kind(DiffLine v) => v.kind;
  static const Field<DiffLine, DiffLineKind> _f$kind = Field('kind', _$kind);
  static String _$text(DiffLine v) => v.text;
  static const Field<DiffLine, String> _f$text = Field('text', _$text);

  @override
  final MappableFields<DiffLine> fields = const {
    #kind: _f$kind,
    #text: _f$text,
  };

  static DiffLine _instantiate(DecodingData data) {
    return DiffLine(kind: data.dec(_f$kind), text: data.dec(_f$text));
  }

  @override
  final Function instantiate = _instantiate;

  static DiffLine fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiffLine>(map);
  }

  static DiffLine fromJson(String json) {
    return ensureInitialized().decodeJson<DiffLine>(json);
  }
}

mixin DiffLineMappable {
  String toJson() {
    return DiffLineMapper.ensureInitialized().encodeJson<DiffLine>(
      this as DiffLine,
    );
  }

  Map<String, dynamic> toMap() {
    return DiffLineMapper.ensureInitialized().encodeMap<DiffLine>(
      this as DiffLine,
    );
  }

  DiffLineCopyWith<DiffLine, DiffLine, DiffLine> get copyWith =>
      _DiffLineCopyWithImpl<DiffLine, DiffLine>(
        this as DiffLine,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiffLineMapper.ensureInitialized().stringifyValue(this as DiffLine);
  }

  @override
  bool operator ==(Object other) {
    return DiffLineMapper.ensureInitialized().equalsValue(
      this as DiffLine,
      other,
    );
  }

  @override
  int get hashCode {
    return DiffLineMapper.ensureInitialized().hashValue(this as DiffLine);
  }
}

extension DiffLineValueCopy<$R, $Out> on ObjectCopyWith<$R, DiffLine, $Out> {
  DiffLineCopyWith<$R, DiffLine, $Out> get $asDiffLine =>
      $base.as((v, t, t2) => _DiffLineCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DiffLineCopyWith<$R, $In extends DiffLine, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({DiffLineKind? kind, String? text});
  DiffLineCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DiffLineCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiffLine, $Out>
    implements DiffLineCopyWith<$R, DiffLine, $Out> {
  _DiffLineCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiffLine> $mapper =
      DiffLineMapper.ensureInitialized();
  @override
  $R call({DiffLineKind? kind, String? text}) => $apply(
    FieldCopyWithData({
      if (kind != null) #kind: kind,
      if (text != null) #text: text,
    }),
  );
  @override
  DiffLine $make(CopyWithData data) => DiffLine(
    kind: data.get(#kind, or: $value.kind),
    text: data.get(#text, or: $value.text),
  );

  @override
  DiffLineCopyWith<$R2, DiffLine, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiffLineCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DiffHunkMapper extends ClassMapperBase<DiffHunk> {
  DiffHunkMapper._();

  static DiffHunkMapper? _instance;
  static DiffHunkMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiffHunkMapper._());
      DiffLineMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiffHunk';

  static int _$oldStart(DiffHunk v) => v.oldStart;
  static const Field<DiffHunk, int> _f$oldStart = Field('oldStart', _$oldStart);
  static int _$oldCount(DiffHunk v) => v.oldCount;
  static const Field<DiffHunk, int> _f$oldCount = Field('oldCount', _$oldCount);
  static int _$newStart(DiffHunk v) => v.newStart;
  static const Field<DiffHunk, int> _f$newStart = Field('newStart', _$newStart);
  static int _$newCount(DiffHunk v) => v.newCount;
  static const Field<DiffHunk, int> _f$newCount = Field('newCount', _$newCount);
  static List<DiffLine> _$lines(DiffHunk v) => v.lines;
  static const Field<DiffHunk, List<DiffLine>> _f$lines = Field(
    'lines',
    _$lines,
  );

  @override
  final MappableFields<DiffHunk> fields = const {
    #oldStart: _f$oldStart,
    #oldCount: _f$oldCount,
    #newStart: _f$newStart,
    #newCount: _f$newCount,
    #lines: _f$lines,
  };

  static DiffHunk _instantiate(DecodingData data) {
    return DiffHunk(
      oldStart: data.dec(_f$oldStart),
      oldCount: data.dec(_f$oldCount),
      newStart: data.dec(_f$newStart),
      newCount: data.dec(_f$newCount),
      lines: data.dec(_f$lines),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DiffHunk fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiffHunk>(map);
  }

  static DiffHunk fromJson(String json) {
    return ensureInitialized().decodeJson<DiffHunk>(json);
  }
}

mixin DiffHunkMappable {
  String toJson() {
    return DiffHunkMapper.ensureInitialized().encodeJson<DiffHunk>(
      this as DiffHunk,
    );
  }

  Map<String, dynamic> toMap() {
    return DiffHunkMapper.ensureInitialized().encodeMap<DiffHunk>(
      this as DiffHunk,
    );
  }

  DiffHunkCopyWith<DiffHunk, DiffHunk, DiffHunk> get copyWith =>
      _DiffHunkCopyWithImpl<DiffHunk, DiffHunk>(
        this as DiffHunk,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiffHunkMapper.ensureInitialized().stringifyValue(this as DiffHunk);
  }

  @override
  bool operator ==(Object other) {
    return DiffHunkMapper.ensureInitialized().equalsValue(
      this as DiffHunk,
      other,
    );
  }

  @override
  int get hashCode {
    return DiffHunkMapper.ensureInitialized().hashValue(this as DiffHunk);
  }
}

extension DiffHunkValueCopy<$R, $Out> on ObjectCopyWith<$R, DiffHunk, $Out> {
  DiffHunkCopyWith<$R, DiffHunk, $Out> get $asDiffHunk =>
      $base.as((v, t, t2) => _DiffHunkCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DiffHunkCopyWith<$R, $In extends DiffHunk, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, DiffLine, DiffLineCopyWith<$R, DiffLine, DiffLine>>
  get lines;
  $R call({
    int? oldStart,
    int? oldCount,
    int? newStart,
    int? newCount,
    List<DiffLine>? lines,
  });
  DiffHunkCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DiffHunkCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiffHunk, $Out>
    implements DiffHunkCopyWith<$R, DiffHunk, $Out> {
  _DiffHunkCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiffHunk> $mapper =
      DiffHunkMapper.ensureInitialized();
  @override
  ListCopyWith<$R, DiffLine, DiffLineCopyWith<$R, DiffLine, DiffLine>>
  get lines => ListCopyWith(
    $value.lines,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(lines: v),
  );
  @override
  $R call({
    int? oldStart,
    int? oldCount,
    int? newStart,
    int? newCount,
    List<DiffLine>? lines,
  }) => $apply(
    FieldCopyWithData({
      if (oldStart != null) #oldStart: oldStart,
      if (oldCount != null) #oldCount: oldCount,
      if (newStart != null) #newStart: newStart,
      if (newCount != null) #newCount: newCount,
      if (lines != null) #lines: lines,
    }),
  );
  @override
  DiffHunk $make(CopyWithData data) => DiffHunk(
    oldStart: data.get(#oldStart, or: $value.oldStart),
    oldCount: data.get(#oldCount, or: $value.oldCount),
    newStart: data.get(#newStart, or: $value.newStart),
    newCount: data.get(#newCount, or: $value.newCount),
    lines: data.get(#lines, or: $value.lines),
  );

  @override
  DiffHunkCopyWith<$R2, DiffHunk, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiffHunkCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class FileDiffMapper extends ClassMapperBase<FileDiff> {
  FileDiffMapper._();

  static FileDiffMapper? _instance;
  static FileDiffMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FileDiffMapper._());
      DiffHunkMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'FileDiff';

  static List<DiffHunk> _$hunks(FileDiff v) => v.hunks;
  static const Field<FileDiff, List<DiffHunk>> _f$hunks = Field(
    'hunks',
    _$hunks,
  );
  static int _$added(FileDiff v) => v.added;
  static const Field<FileDiff, int> _f$added = Field('added', _$added);
  static int _$removed(FileDiff v) => v.removed;
  static const Field<FileDiff, int> _f$removed = Field('removed', _$removed);
  static bool _$truncated(FileDiff v) => v.truncated;
  static const Field<FileDiff, bool> _f$truncated = Field(
    'truncated',
    _$truncated,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<FileDiff> fields = const {
    #hunks: _f$hunks,
    #added: _f$added,
    #removed: _f$removed,
    #truncated: _f$truncated,
  };

  static FileDiff _instantiate(DecodingData data) {
    return FileDiff(
      hunks: data.dec(_f$hunks),
      added: data.dec(_f$added),
      removed: data.dec(_f$removed),
      truncated: data.dec(_f$truncated),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FileDiff fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FileDiff>(map);
  }

  static FileDiff fromJson(String json) {
    return ensureInitialized().decodeJson<FileDiff>(json);
  }
}

mixin FileDiffMappable {
  String toJson() {
    return FileDiffMapper.ensureInitialized().encodeJson<FileDiff>(
      this as FileDiff,
    );
  }

  Map<String, dynamic> toMap() {
    return FileDiffMapper.ensureInitialized().encodeMap<FileDiff>(
      this as FileDiff,
    );
  }

  FileDiffCopyWith<FileDiff, FileDiff, FileDiff> get copyWith =>
      _FileDiffCopyWithImpl<FileDiff, FileDiff>(
        this as FileDiff,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FileDiffMapper.ensureInitialized().stringifyValue(this as FileDiff);
  }

  @override
  bool operator ==(Object other) {
    return FileDiffMapper.ensureInitialized().equalsValue(
      this as FileDiff,
      other,
    );
  }

  @override
  int get hashCode {
    return FileDiffMapper.ensureInitialized().hashValue(this as FileDiff);
  }
}

extension FileDiffValueCopy<$R, $Out> on ObjectCopyWith<$R, FileDiff, $Out> {
  FileDiffCopyWith<$R, FileDiff, $Out> get $asFileDiff =>
      $base.as((v, t, t2) => _FileDiffCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FileDiffCopyWith<$R, $In extends FileDiff, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, DiffHunk, DiffHunkCopyWith<$R, DiffHunk, DiffHunk>>
  get hunks;
  $R call({List<DiffHunk>? hunks, int? added, int? removed, bool? truncated});
  FileDiffCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FileDiffCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FileDiff, $Out>
    implements FileDiffCopyWith<$R, FileDiff, $Out> {
  _FileDiffCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FileDiff> $mapper =
      FileDiffMapper.ensureInitialized();
  @override
  ListCopyWith<$R, DiffHunk, DiffHunkCopyWith<$R, DiffHunk, DiffHunk>>
  get hunks => ListCopyWith(
    $value.hunks,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(hunks: v),
  );
  @override
  $R call({List<DiffHunk>? hunks, int? added, int? removed, bool? truncated}) =>
      $apply(
        FieldCopyWithData({
          if (hunks != null) #hunks: hunks,
          if (added != null) #added: added,
          if (removed != null) #removed: removed,
          if (truncated != null) #truncated: truncated,
        }),
      );
  @override
  FileDiff $make(CopyWithData data) => FileDiff(
    hunks: data.get(#hunks, or: $value.hunks),
    added: data.get(#added, or: $value.added),
    removed: data.get(#removed, or: $value.removed),
    truncated: data.get(#truncated, or: $value.truncated),
  );

  @override
  FileDiffCopyWith<$R2, FileDiff, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FileDiffCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

