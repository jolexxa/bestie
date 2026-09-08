// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'contribution.dart';

class ContributionMapper extends ClassMapperBase<Contribution> {
  ContributionMapper._();

  static ContributionMapper? _instance;
  static ContributionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ContributionMapper._());
      SourceContributionMapper.ensureInitialized();
      DiffContributionMapper.ensureInitialized();
      CreatedFileContributionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Contribution';

  @override
  final MappableFields<Contribution> fields = const {};

  static Contribution _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'Contribution',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Contribution fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Contribution>(map);
  }

  static Contribution fromJson(String json) {
    return ensureInitialized().decodeJson<Contribution>(json);
  }
}

mixin ContributionMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ContributionCopyWith<Contribution, Contribution, Contribution> get copyWith;
}

abstract class ContributionCopyWith<$R, $In extends Contribution, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ContributionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class SourceContributionMapper extends SubClassMapperBase<SourceContribution> {
  SourceContributionMapper._();

  static SourceContributionMapper? _instance;
  static SourceContributionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SourceContributionMapper._());
      ContributionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'SourceContribution';

  static String _$url(SourceContribution v) => v.url;
  static const Field<SourceContribution, String> _f$url = Field('url', _$url);
  static String? _$title(SourceContribution v) => v.title;
  static const Field<SourceContribution, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );

  @override
  final MappableFields<SourceContribution> fields = const {
    #url: _f$url,
    #title: _f$title,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'source';
  @override
  late final ClassMapperBase superMapper =
      ContributionMapper.ensureInitialized();

  static SourceContribution _instantiate(DecodingData data) {
    return SourceContribution(url: data.dec(_f$url), title: data.dec(_f$title));
  }

  @override
  final Function instantiate = _instantiate;

  static SourceContribution fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SourceContribution>(map);
  }

  static SourceContribution fromJson(String json) {
    return ensureInitialized().decodeJson<SourceContribution>(json);
  }
}

mixin SourceContributionMappable {
  String toJson() {
    return SourceContributionMapper.ensureInitialized()
        .encodeJson<SourceContribution>(this as SourceContribution);
  }

  Map<String, dynamic> toMap() {
    return SourceContributionMapper.ensureInitialized()
        .encodeMap<SourceContribution>(this as SourceContribution);
  }

  SourceContributionCopyWith<
    SourceContribution,
    SourceContribution,
    SourceContribution
  >
  get copyWith =>
      _SourceContributionCopyWithImpl<SourceContribution, SourceContribution>(
        this as SourceContribution,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SourceContributionMapper.ensureInitialized().stringifyValue(
      this as SourceContribution,
    );
  }

  @override
  bool operator ==(Object other) {
    return SourceContributionMapper.ensureInitialized().equalsValue(
      this as SourceContribution,
      other,
    );
  }

  @override
  int get hashCode {
    return SourceContributionMapper.ensureInitialized().hashValue(
      this as SourceContribution,
    );
  }
}

extension SourceContributionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SourceContribution, $Out> {
  SourceContributionCopyWith<$R, SourceContribution, $Out>
  get $asSourceContribution => $base.as(
    (v, t, t2) => _SourceContributionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SourceContributionCopyWith<
  $R,
  $In extends SourceContribution,
  $Out
>
    implements ContributionCopyWith<$R, $In, $Out> {
  @override
  $R call({String? url, String? title});
  SourceContributionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SourceContributionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SourceContribution, $Out>
    implements SourceContributionCopyWith<$R, SourceContribution, $Out> {
  _SourceContributionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SourceContribution> $mapper =
      SourceContributionMapper.ensureInitialized();
  @override
  $R call({String? url, Object? title = $none}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (title != $none) #title: title,
    }),
  );
  @override
  SourceContribution $make(CopyWithData data) => SourceContribution(
    url: data.get(#url, or: $value.url),
    title: data.get(#title, or: $value.title),
  );

  @override
  SourceContributionCopyWith<$R2, SourceContribution, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SourceContributionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DiffContributionMapper extends SubClassMapperBase<DiffContribution> {
  DiffContributionMapper._();

  static DiffContributionMapper? _instance;
  static DiffContributionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiffContributionMapper._());
      ContributionMapper.ensureInitialized().addSubMapper(_instance!);
      FileDiffMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiffContribution';

  static String _$path(DiffContribution v) => v.path;
  static const Field<DiffContribution, String> _f$path = Field('path', _$path);
  static FileDiff _$diff(DiffContribution v) => v.diff;
  static const Field<DiffContribution, FileDiff> _f$diff = Field(
    'diff',
    _$diff,
  );

  @override
  final MappableFields<DiffContribution> fields = const {
    #path: _f$path,
    #diff: _f$diff,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'diff';
  @override
  late final ClassMapperBase superMapper =
      ContributionMapper.ensureInitialized();

  static DiffContribution _instantiate(DecodingData data) {
    return DiffContribution(path: data.dec(_f$path), diff: data.dec(_f$diff));
  }

  @override
  final Function instantiate = _instantiate;

  static DiffContribution fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiffContribution>(map);
  }

  static DiffContribution fromJson(String json) {
    return ensureInitialized().decodeJson<DiffContribution>(json);
  }
}

mixin DiffContributionMappable {
  String toJson() {
    return DiffContributionMapper.ensureInitialized()
        .encodeJson<DiffContribution>(this as DiffContribution);
  }

  Map<String, dynamic> toMap() {
    return DiffContributionMapper.ensureInitialized()
        .encodeMap<DiffContribution>(this as DiffContribution);
  }

  DiffContributionCopyWith<DiffContribution, DiffContribution, DiffContribution>
  get copyWith =>
      _DiffContributionCopyWithImpl<DiffContribution, DiffContribution>(
        this as DiffContribution,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DiffContributionMapper.ensureInitialized().stringifyValue(
      this as DiffContribution,
    );
  }

  @override
  bool operator ==(Object other) {
    return DiffContributionMapper.ensureInitialized().equalsValue(
      this as DiffContribution,
      other,
    );
  }

  @override
  int get hashCode {
    return DiffContributionMapper.ensureInitialized().hashValue(
      this as DiffContribution,
    );
  }
}

extension DiffContributionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DiffContribution, $Out> {
  DiffContributionCopyWith<$R, DiffContribution, $Out>
  get $asDiffContribution =>
      $base.as((v, t, t2) => _DiffContributionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DiffContributionCopyWith<$R, $In extends DiffContribution, $Out>
    implements ContributionCopyWith<$R, $In, $Out> {
  FileDiffCopyWith<$R, FileDiff, FileDiff> get diff;
  @override
  $R call({String? path, FileDiff? diff});
  DiffContributionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DiffContributionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DiffContribution, $Out>
    implements DiffContributionCopyWith<$R, DiffContribution, $Out> {
  _DiffContributionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DiffContribution> $mapper =
      DiffContributionMapper.ensureInitialized();
  @override
  FileDiffCopyWith<$R, FileDiff, FileDiff> get diff =>
      $value.diff.copyWith.$chain((v) => call(diff: v));
  @override
  $R call({String? path, FileDiff? diff}) => $apply(
    FieldCopyWithData({
      if (path != null) #path: path,
      if (diff != null) #diff: diff,
    }),
  );
  @override
  DiffContribution $make(CopyWithData data) => DiffContribution(
    path: data.get(#path, or: $value.path),
    diff: data.get(#diff, or: $value.diff),
  );

  @override
  DiffContributionCopyWith<$R2, DiffContribution, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DiffContributionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CreatedFileContributionMapper
    extends SubClassMapperBase<CreatedFileContribution> {
  CreatedFileContributionMapper._();

  static CreatedFileContributionMapper? _instance;
  static CreatedFileContributionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = CreatedFileContributionMapper._(),
      );
      ContributionMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CreatedFileContribution';

  static String _$path(CreatedFileContribution v) => v.path;
  static const Field<CreatedFileContribution, String> _f$path = Field(
    'path',
    _$path,
  );
  static String _$text(CreatedFileContribution v) => v.text;
  static const Field<CreatedFileContribution, String> _f$text = Field(
    'text',
    _$text,
  );
  static int _$lines(CreatedFileContribution v) => v.lines;
  static const Field<CreatedFileContribution, int> _f$lines = Field(
    'lines',
    _$lines,
  );
  static bool _$truncated(CreatedFileContribution v) => v.truncated;
  static const Field<CreatedFileContribution, bool> _f$truncated = Field(
    'truncated',
    _$truncated,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<CreatedFileContribution> fields = const {
    #path: _f$path,
    #text: _f$text,
    #lines: _f$lines,
    #truncated: _f$truncated,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'created';
  @override
  late final ClassMapperBase superMapper =
      ContributionMapper.ensureInitialized();

  static CreatedFileContribution _instantiate(DecodingData data) {
    return CreatedFileContribution(
      path: data.dec(_f$path),
      text: data.dec(_f$text),
      lines: data.dec(_f$lines),
      truncated: data.dec(_f$truncated),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreatedFileContribution fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreatedFileContribution>(map);
  }

  static CreatedFileContribution fromJson(String json) {
    return ensureInitialized().decodeJson<CreatedFileContribution>(json);
  }
}

mixin CreatedFileContributionMappable {
  String toJson() {
    return CreatedFileContributionMapper.ensureInitialized()
        .encodeJson<CreatedFileContribution>(this as CreatedFileContribution);
  }

  Map<String, dynamic> toMap() {
    return CreatedFileContributionMapper.ensureInitialized()
        .encodeMap<CreatedFileContribution>(this as CreatedFileContribution);
  }

  CreatedFileContributionCopyWith<
    CreatedFileContribution,
    CreatedFileContribution,
    CreatedFileContribution
  >
  get copyWith =>
      _CreatedFileContributionCopyWithImpl<
        CreatedFileContribution,
        CreatedFileContribution
      >(this as CreatedFileContribution, $identity, $identity);
  @override
  String toString() {
    return CreatedFileContributionMapper.ensureInitialized().stringifyValue(
      this as CreatedFileContribution,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreatedFileContributionMapper.ensureInitialized().equalsValue(
      this as CreatedFileContribution,
      other,
    );
  }

  @override
  int get hashCode {
    return CreatedFileContributionMapper.ensureInitialized().hashValue(
      this as CreatedFileContribution,
    );
  }
}

extension CreatedFileContributionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreatedFileContribution, $Out> {
  CreatedFileContributionCopyWith<$R, CreatedFileContribution, $Out>
  get $asCreatedFileContribution => $base.as(
    (v, t, t2) => _CreatedFileContributionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreatedFileContributionCopyWith<
  $R,
  $In extends CreatedFileContribution,
  $Out
>
    implements ContributionCopyWith<$R, $In, $Out> {
  @override
  $R call({String? path, String? text, int? lines, bool? truncated});
  CreatedFileContributionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreatedFileContributionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreatedFileContribution, $Out>
    implements
        CreatedFileContributionCopyWith<$R, CreatedFileContribution, $Out> {
  _CreatedFileContributionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreatedFileContribution> $mapper =
      CreatedFileContributionMapper.ensureInitialized();
  @override
  $R call({String? path, String? text, int? lines, bool? truncated}) => $apply(
    FieldCopyWithData({
      if (path != null) #path: path,
      if (text != null) #text: text,
      if (lines != null) #lines: lines,
      if (truncated != null) #truncated: truncated,
    }),
  );
  @override
  CreatedFileContribution $make(CopyWithData data) => CreatedFileContribution(
    path: data.get(#path, or: $value.path),
    text: data.get(#text, or: $value.text),
    lines: data.get(#lines, or: $value.lines),
    truncated: data.get(#truncated, or: $value.truncated),
  );

  @override
  CreatedFileContributionCopyWith<$R2, CreatedFileContribution, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CreatedFileContributionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

