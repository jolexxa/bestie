// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sandbox_grants.dart';

class SandboxGrantsMapper extends ClassMapperBase<SandboxGrants> {
  SandboxGrantsMapper._();

  static SandboxGrantsMapper? _instance;
  static SandboxGrantsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxGrantsMapper._());
      SandboxReadGrantMapper.ensureInitialized();
      SandboxWorkspaceEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxGrants';

  static SandboxReadGrant? _$read(SandboxGrants v) => v.read;
  static const Field<SandboxGrants, SandboxReadGrant> _f$read = Field(
    'read',
    _$read,
    opt: true,
  );
  static List<SandboxWorkspaceEntry> _$workspaces(SandboxGrants v) =>
      v.workspaces;
  static const Field<SandboxGrants, List<SandboxWorkspaceEntry>> _f$workspaces =
      Field('workspaces', _$workspaces, opt: true, def: const []);

  @override
  final MappableFields<SandboxGrants> fields = const {
    #read: _f$read,
    #workspaces: _f$workspaces,
  };

  static SandboxGrants _instantiate(DecodingData data) {
    return SandboxGrants(
      read: data.dec(_f$read),
      workspaces: data.dec(_f$workspaces),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxGrants fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxGrants>(map);
  }

  static SandboxGrants fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxGrants>(json);
  }
}

mixin SandboxGrantsMappable {
  String toJson() {
    return SandboxGrantsMapper.ensureInitialized().encodeJson<SandboxGrants>(
      this as SandboxGrants,
    );
  }

  Map<String, dynamic> toMap() {
    return SandboxGrantsMapper.ensureInitialized().encodeMap<SandboxGrants>(
      this as SandboxGrants,
    );
  }

  SandboxGrantsCopyWith<SandboxGrants, SandboxGrants, SandboxGrants>
  get copyWith => _SandboxGrantsCopyWithImpl<SandboxGrants, SandboxGrants>(
    this as SandboxGrants,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SandboxGrantsMapper.ensureInitialized().stringifyValue(
      this as SandboxGrants,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxGrantsMapper.ensureInitialized().equalsValue(
      this as SandboxGrants,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxGrantsMapper.ensureInitialized().hashValue(
      this as SandboxGrants,
    );
  }
}

extension SandboxGrantsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxGrants, $Out> {
  SandboxGrantsCopyWith<$R, SandboxGrants, $Out> get $asSandboxGrants =>
      $base.as((v, t, t2) => _SandboxGrantsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SandboxGrantsCopyWith<$R, $In extends SandboxGrants, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  SandboxReadGrantCopyWith<$R, SandboxReadGrant, SandboxReadGrant>? get read;
  ListCopyWith<
    $R,
    SandboxWorkspaceEntry,
    SandboxWorkspaceEntryCopyWith<
      $R,
      SandboxWorkspaceEntry,
      SandboxWorkspaceEntry
    >
  >
  get workspaces;
  $R call({SandboxReadGrant? read, List<SandboxWorkspaceEntry>? workspaces});
  SandboxGrantsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SandboxGrantsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxGrants, $Out>
    implements SandboxGrantsCopyWith<$R, SandboxGrants, $Out> {
  _SandboxGrantsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxGrants> $mapper =
      SandboxGrantsMapper.ensureInitialized();
  @override
  SandboxReadGrantCopyWith<$R, SandboxReadGrant, SandboxReadGrant>? get read =>
      $value.read?.copyWith.$chain((v) => call(read: v));
  @override
  ListCopyWith<
    $R,
    SandboxWorkspaceEntry,
    SandboxWorkspaceEntryCopyWith<
      $R,
      SandboxWorkspaceEntry,
      SandboxWorkspaceEntry
    >
  >
  get workspaces => ListCopyWith(
    $value.workspaces,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(workspaces: v),
  );
  @override
  $R call({Object? read = $none, List<SandboxWorkspaceEntry>? workspaces}) =>
      $apply(
        FieldCopyWithData({
          if (read != $none) #read: read,
          if (workspaces != null) #workspaces: workspaces,
        }),
      );
  @override
  SandboxGrants $make(CopyWithData data) => SandboxGrants(
    read: data.get(#read, or: $value.read),
    workspaces: data.get(#workspaces, or: $value.workspaces),
  );

  @override
  SandboxGrantsCopyWith<$R2, SandboxGrants, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SandboxGrantsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

