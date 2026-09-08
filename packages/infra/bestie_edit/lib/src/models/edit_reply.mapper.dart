// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'edit_reply.dart';

class EditReplyMapper extends ClassMapperBase<EditReply> {
  EditReplyMapper._();

  static EditReplyMapper? _instance;
  static EditReplyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditReplyMapper._());
      EditSucceededMapper.ensureInitialized();
      EditCreatedMapper.ensureInitialized();
      EditTargetMissingMapper.ensureInitialized();
      EditAmbiguousMapper.ensureInitialized();
      EditNoChangeMapper.ensureInitialized();
      EditPathMissingMapper.ensureInitialized();
      EditPathExistsMapper.ensureInitialized();
      EditIsDirectoryMapper.ensureInitialized();
      EditDeniedMapper.ensureInitialized();
      EditNotTextMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'EditReply';

  @override
  final MappableFields<EditReply> fields = const {};

  static EditReply _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'EditReply',
      'outcome',
      '${data.value['outcome']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EditReply fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditReply>(map);
  }

  static EditReply fromJson(String json) {
    return ensureInitialized().decodeJson<EditReply>(json);
  }
}

mixin EditReplyMappable {
  String toJson();
  Map<String, dynamic> toMap();
  EditReplyCopyWith<EditReply, EditReply, EditReply> get copyWith;
}

abstract class EditReplyCopyWith<$R, $In extends EditReply, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  EditReplyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class EditSucceededMapper extends SubClassMapperBase<EditSucceeded> {
  EditSucceededMapper._();

  static EditSucceededMapper? _instance;
  static EditSucceededMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditSucceededMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
      FileDiffMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'EditSucceeded';

  static int _$replacements(EditSucceeded v) => v.replacements;
  static const Field<EditSucceeded, int> _f$replacements = Field(
    'replacements',
    _$replacements,
  );
  static String _$snippet(EditSucceeded v) => v.snippet;
  static const Field<EditSucceeded, String> _f$snippet = Field(
    'snippet',
    _$snippet,
  );
  static FileDiff _$diff(EditSucceeded v) => v.diff;
  static const Field<EditSucceeded, FileDiff> _f$diff = Field('diff', _$diff);

  @override
  final MappableFields<EditSucceeded> fields = const {
    #replacements: _f$replacements,
    #snippet: _f$snippet,
    #diff: _f$diff,
  };

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'succeeded';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditSucceeded _instantiate(DecodingData data) {
    return EditSucceeded(
      replacements: data.dec(_f$replacements),
      snippet: data.dec(_f$snippet),
      diff: data.dec(_f$diff),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EditSucceeded fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditSucceeded>(map);
  }

  static EditSucceeded fromJson(String json) {
    return ensureInitialized().decodeJson<EditSucceeded>(json);
  }
}

mixin EditSucceededMappable {
  String toJson() {
    return EditSucceededMapper.ensureInitialized().encodeJson<EditSucceeded>(
      this as EditSucceeded,
    );
  }

  Map<String, dynamic> toMap() {
    return EditSucceededMapper.ensureInitialized().encodeMap<EditSucceeded>(
      this as EditSucceeded,
    );
  }

  EditSucceededCopyWith<EditSucceeded, EditSucceeded, EditSucceeded>
  get copyWith => _EditSucceededCopyWithImpl<EditSucceeded, EditSucceeded>(
    this as EditSucceeded,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return EditSucceededMapper.ensureInitialized().stringifyValue(
      this as EditSucceeded,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditSucceededMapper.ensureInitialized().equalsValue(
      this as EditSucceeded,
      other,
    );
  }

  @override
  int get hashCode {
    return EditSucceededMapper.ensureInitialized().hashValue(
      this as EditSucceeded,
    );
  }
}

extension EditSucceededValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditSucceeded, $Out> {
  EditSucceededCopyWith<$R, EditSucceeded, $Out> get $asEditSucceeded =>
      $base.as((v, t, t2) => _EditSucceededCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditSucceededCopyWith<$R, $In extends EditSucceeded, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  FileDiffCopyWith<$R, FileDiff, FileDiff> get diff;
  @override
  $R call({int? replacements, String? snippet, FileDiff? diff});
  EditSucceededCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditSucceededCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditSucceeded, $Out>
    implements EditSucceededCopyWith<$R, EditSucceeded, $Out> {
  _EditSucceededCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditSucceeded> $mapper =
      EditSucceededMapper.ensureInitialized();
  @override
  FileDiffCopyWith<$R, FileDiff, FileDiff> get diff =>
      $value.diff.copyWith.$chain((v) => call(diff: v));
  @override
  $R call({int? replacements, String? snippet, FileDiff? diff}) => $apply(
    FieldCopyWithData({
      if (replacements != null) #replacements: replacements,
      if (snippet != null) #snippet: snippet,
      if (diff != null) #diff: diff,
    }),
  );
  @override
  EditSucceeded $make(CopyWithData data) => EditSucceeded(
    replacements: data.get(#replacements, or: $value.replacements),
    snippet: data.get(#snippet, or: $value.snippet),
    diff: data.get(#diff, or: $value.diff),
  );

  @override
  EditSucceededCopyWith<$R2, EditSucceeded, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditSucceededCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditCreatedMapper extends SubClassMapperBase<EditCreated> {
  EditCreatedMapper._();

  static EditCreatedMapper? _instance;
  static EditCreatedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditCreatedMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditCreated';

  @override
  final MappableFields<EditCreated> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'created';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditCreated _instantiate(DecodingData data) {
    return EditCreated();
  }

  @override
  final Function instantiate = _instantiate;

  static EditCreated fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditCreated>(map);
  }

  static EditCreated fromJson(String json) {
    return ensureInitialized().decodeJson<EditCreated>(json);
  }
}

mixin EditCreatedMappable {
  String toJson() {
    return EditCreatedMapper.ensureInitialized().encodeJson<EditCreated>(
      this as EditCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return EditCreatedMapper.ensureInitialized().encodeMap<EditCreated>(
      this as EditCreated,
    );
  }

  EditCreatedCopyWith<EditCreated, EditCreated, EditCreated> get copyWith =>
      _EditCreatedCopyWithImpl<EditCreated, EditCreated>(
        this as EditCreated,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditCreatedMapper.ensureInitialized().stringifyValue(
      this as EditCreated,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditCreatedMapper.ensureInitialized().equalsValue(
      this as EditCreated,
      other,
    );
  }

  @override
  int get hashCode {
    return EditCreatedMapper.ensureInitialized().hashValue(this as EditCreated);
  }
}

extension EditCreatedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditCreated, $Out> {
  EditCreatedCopyWith<$R, EditCreated, $Out> get $asEditCreated =>
      $base.as((v, t, t2) => _EditCreatedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditCreatedCopyWith<$R, $In extends EditCreated, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditCreatedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditCreatedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditCreated, $Out>
    implements EditCreatedCopyWith<$R, EditCreated, $Out> {
  _EditCreatedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditCreated> $mapper =
      EditCreatedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditCreated $make(CopyWithData data) => EditCreated();

  @override
  EditCreatedCopyWith<$R2, EditCreated, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditCreatedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditTargetMissingMapper extends SubClassMapperBase<EditTargetMissing> {
  EditTargetMissingMapper._();

  static EditTargetMissingMapper? _instance;
  static EditTargetMissingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditTargetMissingMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditTargetMissing';

  @override
  final MappableFields<EditTargetMissing> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'targetMissing';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditTargetMissing _instantiate(DecodingData data) {
    return EditTargetMissing();
  }

  @override
  final Function instantiate = _instantiate;

  static EditTargetMissing fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditTargetMissing>(map);
  }

  static EditTargetMissing fromJson(String json) {
    return ensureInitialized().decodeJson<EditTargetMissing>(json);
  }
}

mixin EditTargetMissingMappable {
  String toJson() {
    return EditTargetMissingMapper.ensureInitialized()
        .encodeJson<EditTargetMissing>(this as EditTargetMissing);
  }

  Map<String, dynamic> toMap() {
    return EditTargetMissingMapper.ensureInitialized()
        .encodeMap<EditTargetMissing>(this as EditTargetMissing);
  }

  EditTargetMissingCopyWith<
    EditTargetMissing,
    EditTargetMissing,
    EditTargetMissing
  >
  get copyWith =>
      _EditTargetMissingCopyWithImpl<EditTargetMissing, EditTargetMissing>(
        this as EditTargetMissing,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditTargetMissingMapper.ensureInitialized().stringifyValue(
      this as EditTargetMissing,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditTargetMissingMapper.ensureInitialized().equalsValue(
      this as EditTargetMissing,
      other,
    );
  }

  @override
  int get hashCode {
    return EditTargetMissingMapper.ensureInitialized().hashValue(
      this as EditTargetMissing,
    );
  }
}

extension EditTargetMissingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditTargetMissing, $Out> {
  EditTargetMissingCopyWith<$R, EditTargetMissing, $Out>
  get $asEditTargetMissing => $base.as(
    (v, t, t2) => _EditTargetMissingCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class EditTargetMissingCopyWith<
  $R,
  $In extends EditTargetMissing,
  $Out
>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditTargetMissingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EditTargetMissingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditTargetMissing, $Out>
    implements EditTargetMissingCopyWith<$R, EditTargetMissing, $Out> {
  _EditTargetMissingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditTargetMissing> $mapper =
      EditTargetMissingMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditTargetMissing $make(CopyWithData data) => EditTargetMissing();

  @override
  EditTargetMissingCopyWith<$R2, EditTargetMissing, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditTargetMissingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditAmbiguousMapper extends SubClassMapperBase<EditAmbiguous> {
  EditAmbiguousMapper._();

  static EditAmbiguousMapper? _instance;
  static EditAmbiguousMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditAmbiguousMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditAmbiguous';

  static int _$occurrences(EditAmbiguous v) => v.occurrences;
  static const Field<EditAmbiguous, int> _f$occurrences = Field(
    'occurrences',
    _$occurrences,
  );

  @override
  final MappableFields<EditAmbiguous> fields = const {
    #occurrences: _f$occurrences,
  };

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'ambiguous';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditAmbiguous _instantiate(DecodingData data) {
    return EditAmbiguous(occurrences: data.dec(_f$occurrences));
  }

  @override
  final Function instantiate = _instantiate;

  static EditAmbiguous fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditAmbiguous>(map);
  }

  static EditAmbiguous fromJson(String json) {
    return ensureInitialized().decodeJson<EditAmbiguous>(json);
  }
}

mixin EditAmbiguousMappable {
  String toJson() {
    return EditAmbiguousMapper.ensureInitialized().encodeJson<EditAmbiguous>(
      this as EditAmbiguous,
    );
  }

  Map<String, dynamic> toMap() {
    return EditAmbiguousMapper.ensureInitialized().encodeMap<EditAmbiguous>(
      this as EditAmbiguous,
    );
  }

  EditAmbiguousCopyWith<EditAmbiguous, EditAmbiguous, EditAmbiguous>
  get copyWith => _EditAmbiguousCopyWithImpl<EditAmbiguous, EditAmbiguous>(
    this as EditAmbiguous,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return EditAmbiguousMapper.ensureInitialized().stringifyValue(
      this as EditAmbiguous,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditAmbiguousMapper.ensureInitialized().equalsValue(
      this as EditAmbiguous,
      other,
    );
  }

  @override
  int get hashCode {
    return EditAmbiguousMapper.ensureInitialized().hashValue(
      this as EditAmbiguous,
    );
  }
}

extension EditAmbiguousValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditAmbiguous, $Out> {
  EditAmbiguousCopyWith<$R, EditAmbiguous, $Out> get $asEditAmbiguous =>
      $base.as((v, t, t2) => _EditAmbiguousCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditAmbiguousCopyWith<$R, $In extends EditAmbiguous, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call({int? occurrences});
  EditAmbiguousCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditAmbiguousCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditAmbiguous, $Out>
    implements EditAmbiguousCopyWith<$R, EditAmbiguous, $Out> {
  _EditAmbiguousCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditAmbiguous> $mapper =
      EditAmbiguousMapper.ensureInitialized();
  @override
  $R call({int? occurrences}) => $apply(
    FieldCopyWithData({if (occurrences != null) #occurrences: occurrences}),
  );
  @override
  EditAmbiguous $make(CopyWithData data) => EditAmbiguous(
    occurrences: data.get(#occurrences, or: $value.occurrences),
  );

  @override
  EditAmbiguousCopyWith<$R2, EditAmbiguous, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditAmbiguousCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditNoChangeMapper extends SubClassMapperBase<EditNoChange> {
  EditNoChangeMapper._();

  static EditNoChangeMapper? _instance;
  static EditNoChangeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditNoChangeMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditNoChange';

  @override
  final MappableFields<EditNoChange> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'noChange';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditNoChange _instantiate(DecodingData data) {
    return EditNoChange();
  }

  @override
  final Function instantiate = _instantiate;

  static EditNoChange fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditNoChange>(map);
  }

  static EditNoChange fromJson(String json) {
    return ensureInitialized().decodeJson<EditNoChange>(json);
  }
}

mixin EditNoChangeMappable {
  String toJson() {
    return EditNoChangeMapper.ensureInitialized().encodeJson<EditNoChange>(
      this as EditNoChange,
    );
  }

  Map<String, dynamic> toMap() {
    return EditNoChangeMapper.ensureInitialized().encodeMap<EditNoChange>(
      this as EditNoChange,
    );
  }

  EditNoChangeCopyWith<EditNoChange, EditNoChange, EditNoChange> get copyWith =>
      _EditNoChangeCopyWithImpl<EditNoChange, EditNoChange>(
        this as EditNoChange,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditNoChangeMapper.ensureInitialized().stringifyValue(
      this as EditNoChange,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditNoChangeMapper.ensureInitialized().equalsValue(
      this as EditNoChange,
      other,
    );
  }

  @override
  int get hashCode {
    return EditNoChangeMapper.ensureInitialized().hashValue(
      this as EditNoChange,
    );
  }
}

extension EditNoChangeValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditNoChange, $Out> {
  EditNoChangeCopyWith<$R, EditNoChange, $Out> get $asEditNoChange =>
      $base.as((v, t, t2) => _EditNoChangeCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditNoChangeCopyWith<$R, $In extends EditNoChange, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditNoChangeCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditNoChangeCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditNoChange, $Out>
    implements EditNoChangeCopyWith<$R, EditNoChange, $Out> {
  _EditNoChangeCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditNoChange> $mapper =
      EditNoChangeMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditNoChange $make(CopyWithData data) => EditNoChange();

  @override
  EditNoChangeCopyWith<$R2, EditNoChange, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditNoChangeCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditPathMissingMapper extends SubClassMapperBase<EditPathMissing> {
  EditPathMissingMapper._();

  static EditPathMissingMapper? _instance;
  static EditPathMissingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditPathMissingMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditPathMissing';

  @override
  final MappableFields<EditPathMissing> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'pathMissing';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditPathMissing _instantiate(DecodingData data) {
    return EditPathMissing();
  }

  @override
  final Function instantiate = _instantiate;

  static EditPathMissing fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditPathMissing>(map);
  }

  static EditPathMissing fromJson(String json) {
    return ensureInitialized().decodeJson<EditPathMissing>(json);
  }
}

mixin EditPathMissingMappable {
  String toJson() {
    return EditPathMissingMapper.ensureInitialized()
        .encodeJson<EditPathMissing>(this as EditPathMissing);
  }

  Map<String, dynamic> toMap() {
    return EditPathMissingMapper.ensureInitialized().encodeMap<EditPathMissing>(
      this as EditPathMissing,
    );
  }

  EditPathMissingCopyWith<EditPathMissing, EditPathMissing, EditPathMissing>
  get copyWith =>
      _EditPathMissingCopyWithImpl<EditPathMissing, EditPathMissing>(
        this as EditPathMissing,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditPathMissingMapper.ensureInitialized().stringifyValue(
      this as EditPathMissing,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditPathMissingMapper.ensureInitialized().equalsValue(
      this as EditPathMissing,
      other,
    );
  }

  @override
  int get hashCode {
    return EditPathMissingMapper.ensureInitialized().hashValue(
      this as EditPathMissing,
    );
  }
}

extension EditPathMissingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditPathMissing, $Out> {
  EditPathMissingCopyWith<$R, EditPathMissing, $Out> get $asEditPathMissing =>
      $base.as((v, t, t2) => _EditPathMissingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditPathMissingCopyWith<$R, $In extends EditPathMissing, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditPathMissingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EditPathMissingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditPathMissing, $Out>
    implements EditPathMissingCopyWith<$R, EditPathMissing, $Out> {
  _EditPathMissingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditPathMissing> $mapper =
      EditPathMissingMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditPathMissing $make(CopyWithData data) => EditPathMissing();

  @override
  EditPathMissingCopyWith<$R2, EditPathMissing, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditPathMissingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditPathExistsMapper extends SubClassMapperBase<EditPathExists> {
  EditPathExistsMapper._();

  static EditPathExistsMapper? _instance;
  static EditPathExistsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditPathExistsMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditPathExists';

  @override
  final MappableFields<EditPathExists> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'pathExists';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditPathExists _instantiate(DecodingData data) {
    return EditPathExists();
  }

  @override
  final Function instantiate = _instantiate;

  static EditPathExists fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditPathExists>(map);
  }

  static EditPathExists fromJson(String json) {
    return ensureInitialized().decodeJson<EditPathExists>(json);
  }
}

mixin EditPathExistsMappable {
  String toJson() {
    return EditPathExistsMapper.ensureInitialized().encodeJson<EditPathExists>(
      this as EditPathExists,
    );
  }

  Map<String, dynamic> toMap() {
    return EditPathExistsMapper.ensureInitialized().encodeMap<EditPathExists>(
      this as EditPathExists,
    );
  }

  EditPathExistsCopyWith<EditPathExists, EditPathExists, EditPathExists>
  get copyWith => _EditPathExistsCopyWithImpl<EditPathExists, EditPathExists>(
    this as EditPathExists,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return EditPathExistsMapper.ensureInitialized().stringifyValue(
      this as EditPathExists,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditPathExistsMapper.ensureInitialized().equalsValue(
      this as EditPathExists,
      other,
    );
  }

  @override
  int get hashCode {
    return EditPathExistsMapper.ensureInitialized().hashValue(
      this as EditPathExists,
    );
  }
}

extension EditPathExistsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditPathExists, $Out> {
  EditPathExistsCopyWith<$R, EditPathExists, $Out> get $asEditPathExists =>
      $base.as((v, t, t2) => _EditPathExistsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditPathExistsCopyWith<$R, $In extends EditPathExists, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditPathExistsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EditPathExistsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditPathExists, $Out>
    implements EditPathExistsCopyWith<$R, EditPathExists, $Out> {
  _EditPathExistsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditPathExists> $mapper =
      EditPathExistsMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditPathExists $make(CopyWithData data) => EditPathExists();

  @override
  EditPathExistsCopyWith<$R2, EditPathExists, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditPathExistsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditIsDirectoryMapper extends SubClassMapperBase<EditIsDirectory> {
  EditIsDirectoryMapper._();

  static EditIsDirectoryMapper? _instance;
  static EditIsDirectoryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditIsDirectoryMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditIsDirectory';

  @override
  final MappableFields<EditIsDirectory> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'isDirectory';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditIsDirectory _instantiate(DecodingData data) {
    return EditIsDirectory();
  }

  @override
  final Function instantiate = _instantiate;

  static EditIsDirectory fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditIsDirectory>(map);
  }

  static EditIsDirectory fromJson(String json) {
    return ensureInitialized().decodeJson<EditIsDirectory>(json);
  }
}

mixin EditIsDirectoryMappable {
  String toJson() {
    return EditIsDirectoryMapper.ensureInitialized()
        .encodeJson<EditIsDirectory>(this as EditIsDirectory);
  }

  Map<String, dynamic> toMap() {
    return EditIsDirectoryMapper.ensureInitialized().encodeMap<EditIsDirectory>(
      this as EditIsDirectory,
    );
  }

  EditIsDirectoryCopyWith<EditIsDirectory, EditIsDirectory, EditIsDirectory>
  get copyWith =>
      _EditIsDirectoryCopyWithImpl<EditIsDirectory, EditIsDirectory>(
        this as EditIsDirectory,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditIsDirectoryMapper.ensureInitialized().stringifyValue(
      this as EditIsDirectory,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditIsDirectoryMapper.ensureInitialized().equalsValue(
      this as EditIsDirectory,
      other,
    );
  }

  @override
  int get hashCode {
    return EditIsDirectoryMapper.ensureInitialized().hashValue(
      this as EditIsDirectory,
    );
  }
}

extension EditIsDirectoryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditIsDirectory, $Out> {
  EditIsDirectoryCopyWith<$R, EditIsDirectory, $Out> get $asEditIsDirectory =>
      $base.as((v, t, t2) => _EditIsDirectoryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditIsDirectoryCopyWith<$R, $In extends EditIsDirectory, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditIsDirectoryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EditIsDirectoryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditIsDirectory, $Out>
    implements EditIsDirectoryCopyWith<$R, EditIsDirectory, $Out> {
  _EditIsDirectoryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditIsDirectory> $mapper =
      EditIsDirectoryMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditIsDirectory $make(CopyWithData data) => EditIsDirectory();

  @override
  EditIsDirectoryCopyWith<$R2, EditIsDirectory, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditIsDirectoryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditDeniedMapper extends SubClassMapperBase<EditDenied> {
  EditDeniedMapper._();

  static EditDeniedMapper? _instance;
  static EditDeniedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditDeniedMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditDenied';

  @override
  final MappableFields<EditDenied> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'denied';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditDenied _instantiate(DecodingData data) {
    return EditDenied();
  }

  @override
  final Function instantiate = _instantiate;

  static EditDenied fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditDenied>(map);
  }

  static EditDenied fromJson(String json) {
    return ensureInitialized().decodeJson<EditDenied>(json);
  }
}

mixin EditDeniedMappable {
  String toJson() {
    return EditDeniedMapper.ensureInitialized().encodeJson<EditDenied>(
      this as EditDenied,
    );
  }

  Map<String, dynamic> toMap() {
    return EditDeniedMapper.ensureInitialized().encodeMap<EditDenied>(
      this as EditDenied,
    );
  }

  EditDeniedCopyWith<EditDenied, EditDenied, EditDenied> get copyWith =>
      _EditDeniedCopyWithImpl<EditDenied, EditDenied>(
        this as EditDenied,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditDeniedMapper.ensureInitialized().stringifyValue(
      this as EditDenied,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditDeniedMapper.ensureInitialized().equalsValue(
      this as EditDenied,
      other,
    );
  }

  @override
  int get hashCode {
    return EditDeniedMapper.ensureInitialized().hashValue(this as EditDenied);
  }
}

extension EditDeniedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditDenied, $Out> {
  EditDeniedCopyWith<$R, EditDenied, $Out> get $asEditDenied =>
      $base.as((v, t, t2) => _EditDeniedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditDeniedCopyWith<$R, $In extends EditDenied, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditDeniedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditDeniedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditDenied, $Out>
    implements EditDeniedCopyWith<$R, EditDenied, $Out> {
  _EditDeniedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditDenied> $mapper =
      EditDeniedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditDenied $make(CopyWithData data) => EditDenied();

  @override
  EditDeniedCopyWith<$R2, EditDenied, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditDeniedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class EditNotTextMapper extends SubClassMapperBase<EditNotText> {
  EditNotTextMapper._();

  static EditNotTextMapper? _instance;
  static EditNotTextMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditNotTextMapper._());
      EditReplyMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'EditNotText';

  @override
  final MappableFields<EditNotText> fields = const {};

  @override
  final String discriminatorKey = 'outcome';
  @override
  final dynamic discriminatorValue = 'notText';
  @override
  late final ClassMapperBase superMapper = EditReplyMapper.ensureInitialized();

  static EditNotText _instantiate(DecodingData data) {
    return EditNotText();
  }

  @override
  final Function instantiate = _instantiate;

  static EditNotText fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditNotText>(map);
  }

  static EditNotText fromJson(String json) {
    return ensureInitialized().decodeJson<EditNotText>(json);
  }
}

mixin EditNotTextMappable {
  String toJson() {
    return EditNotTextMapper.ensureInitialized().encodeJson<EditNotText>(
      this as EditNotText,
    );
  }

  Map<String, dynamic> toMap() {
    return EditNotTextMapper.ensureInitialized().encodeMap<EditNotText>(
      this as EditNotText,
    );
  }

  EditNotTextCopyWith<EditNotText, EditNotText, EditNotText> get copyWith =>
      _EditNotTextCopyWithImpl<EditNotText, EditNotText>(
        this as EditNotText,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EditNotTextMapper.ensureInitialized().stringifyValue(
      this as EditNotText,
    );
  }

  @override
  bool operator ==(Object other) {
    return EditNotTextMapper.ensureInitialized().equalsValue(
      this as EditNotText,
      other,
    );
  }

  @override
  int get hashCode {
    return EditNotTextMapper.ensureInitialized().hashValue(this as EditNotText);
  }
}

extension EditNotTextValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EditNotText, $Out> {
  EditNotTextCopyWith<$R, EditNotText, $Out> get $asEditNotText =>
      $base.as((v, t, t2) => _EditNotTextCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EditNotTextCopyWith<$R, $In extends EditNotText, $Out>
    implements EditReplyCopyWith<$R, $In, $Out> {
  @override
  $R call();
  EditNotTextCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _EditNotTextCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EditNotText, $Out>
    implements EditNotTextCopyWith<$R, EditNotText, $Out> {
  _EditNotTextCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EditNotText> $mapper =
      EditNotTextMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  EditNotText $make(CopyWithData data) => EditNotText();

  @override
  EditNotTextCopyWith<$R2, EditNotText, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EditNotTextCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

