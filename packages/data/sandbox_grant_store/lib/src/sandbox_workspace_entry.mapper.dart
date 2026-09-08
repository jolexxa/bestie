// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sandbox_workspace_entry.dart';

class SandboxWorkspaceEntryMapper
    extends ClassMapperBase<SandboxWorkspaceEntry> {
  SandboxWorkspaceEntryMapper._();

  static SandboxWorkspaceEntryMapper? _instance;
  static SandboxWorkspaceEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxWorkspaceEntryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxWorkspaceEntry';

  static String _$workspaceRoot(SandboxWorkspaceEntry v) => v.workspaceRoot;
  static const Field<SandboxWorkspaceEntry, String> _f$workspaceRoot = Field(
    'workspaceRoot',
    _$workspaceRoot,
  );
  static String _$profileName(SandboxWorkspaceEntry v) => v.profileName;
  static const Field<SandboxWorkspaceEntry, String> _f$profileName = Field(
    'profileName',
    _$profileName,
  );
  static String _$containerSid(SandboxWorkspaceEntry v) => v.containerSid;
  static const Field<SandboxWorkspaceEntry, String> _f$containerSid = Field(
    'containerSid',
    _$containerSid,
  );
  static DateTime _$lastSeen(SandboxWorkspaceEntry v) => v.lastSeen;
  static const Field<SandboxWorkspaceEntry, DateTime> _f$lastSeen = Field(
    'lastSeen',
    _$lastSeen,
  );
  static List<String> _$widenedRoots(SandboxWorkspaceEntry v) => v.widenedRoots;
  static const Field<SandboxWorkspaceEntry, List<String>> _f$widenedRoots =
      Field('widenedRoots', _$widenedRoots, opt: true, def: const []);

  @override
  final MappableFields<SandboxWorkspaceEntry> fields = const {
    #workspaceRoot: _f$workspaceRoot,
    #profileName: _f$profileName,
    #containerSid: _f$containerSid,
    #lastSeen: _f$lastSeen,
    #widenedRoots: _f$widenedRoots,
  };

  static SandboxWorkspaceEntry _instantiate(DecodingData data) {
    return SandboxWorkspaceEntry(
      workspaceRoot: data.dec(_f$workspaceRoot),
      profileName: data.dec(_f$profileName),
      containerSid: data.dec(_f$containerSid),
      lastSeen: data.dec(_f$lastSeen),
      widenedRoots: data.dec(_f$widenedRoots),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxWorkspaceEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxWorkspaceEntry>(map);
  }

  static SandboxWorkspaceEntry fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxWorkspaceEntry>(json);
  }
}

mixin SandboxWorkspaceEntryMappable {
  String toJson() {
    return SandboxWorkspaceEntryMapper.ensureInitialized()
        .encodeJson<SandboxWorkspaceEntry>(this as SandboxWorkspaceEntry);
  }

  Map<String, dynamic> toMap() {
    return SandboxWorkspaceEntryMapper.ensureInitialized()
        .encodeMap<SandboxWorkspaceEntry>(this as SandboxWorkspaceEntry);
  }

  SandboxWorkspaceEntryCopyWith<
    SandboxWorkspaceEntry,
    SandboxWorkspaceEntry,
    SandboxWorkspaceEntry
  >
  get copyWith =>
      _SandboxWorkspaceEntryCopyWithImpl<
        SandboxWorkspaceEntry,
        SandboxWorkspaceEntry
      >(this as SandboxWorkspaceEntry, $identity, $identity);
  @override
  String toString() {
    return SandboxWorkspaceEntryMapper.ensureInitialized().stringifyValue(
      this as SandboxWorkspaceEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxWorkspaceEntryMapper.ensureInitialized().equalsValue(
      this as SandboxWorkspaceEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxWorkspaceEntryMapper.ensureInitialized().hashValue(
      this as SandboxWorkspaceEntry,
    );
  }
}

extension SandboxWorkspaceEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxWorkspaceEntry, $Out> {
  SandboxWorkspaceEntryCopyWith<$R, SandboxWorkspaceEntry, $Out>
  get $asSandboxWorkspaceEntry => $base.as(
    (v, t, t2) => _SandboxWorkspaceEntryCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SandboxWorkspaceEntryCopyWith<
  $R,
  $In extends SandboxWorkspaceEntry,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get widenedRoots;
  $R call({
    String? workspaceRoot,
    String? profileName,
    String? containerSid,
    DateTime? lastSeen,
    List<String>? widenedRoots,
  });
  SandboxWorkspaceEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SandboxWorkspaceEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxWorkspaceEntry, $Out>
    implements SandboxWorkspaceEntryCopyWith<$R, SandboxWorkspaceEntry, $Out> {
  _SandboxWorkspaceEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxWorkspaceEntry> $mapper =
      SandboxWorkspaceEntryMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get widenedRoots => ListCopyWith(
    $value.widenedRoots,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(widenedRoots: v),
  );
  @override
  $R call({
    String? workspaceRoot,
    String? profileName,
    String? containerSid,
    DateTime? lastSeen,
    List<String>? widenedRoots,
  }) => $apply(
    FieldCopyWithData({
      if (workspaceRoot != null) #workspaceRoot: workspaceRoot,
      if (profileName != null) #profileName: profileName,
      if (containerSid != null) #containerSid: containerSid,
      if (lastSeen != null) #lastSeen: lastSeen,
      if (widenedRoots != null) #widenedRoots: widenedRoots,
    }),
  );
  @override
  SandboxWorkspaceEntry $make(CopyWithData data) => SandboxWorkspaceEntry(
    workspaceRoot: data.get(#workspaceRoot, or: $value.workspaceRoot),
    profileName: data.get(#profileName, or: $value.profileName),
    containerSid: data.get(#containerSid, or: $value.containerSid),
    lastSeen: data.get(#lastSeen, or: $value.lastSeen),
    widenedRoots: data.get(#widenedRoots, or: $value.widenedRoots),
  );

  @override
  SandboxWorkspaceEntryCopyWith<$R2, SandboxWorkspaceEntry, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _SandboxWorkspaceEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

