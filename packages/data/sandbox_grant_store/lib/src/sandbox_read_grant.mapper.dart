// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sandbox_read_grant.dart';

class SandboxReadGrantMapper extends ClassMapperBase<SandboxReadGrant> {
  SandboxReadGrantMapper._();

  static SandboxReadGrantMapper? _instance;
  static SandboxReadGrantMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxReadGrantMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxReadGrant';

  static String _$capabilitySid(SandboxReadGrant v) => v.capabilitySid;
  static const Field<SandboxReadGrant, String> _f$capabilitySid = Field(
    'capabilitySid',
    _$capabilitySid,
  );
  static List<String> _$readRoots(SandboxReadGrant v) => v.readRoots;
  static const Field<SandboxReadGrant, List<String>> _f$readRoots = Field(
    'readRoots',
    _$readRoots,
  );
  static List<String> _$holes(SandboxReadGrant v) => v.holes;
  static const Field<SandboxReadGrant, List<String>> _f$holes = Field(
    'holes',
    _$holes,
  );
  static int _$policyVersion(SandboxReadGrant v) => v.policyVersion;
  static const Field<SandboxReadGrant, int> _f$policyVersion = Field(
    'policyVersion',
    _$policyVersion,
  );

  @override
  final MappableFields<SandboxReadGrant> fields = const {
    #capabilitySid: _f$capabilitySid,
    #readRoots: _f$readRoots,
    #holes: _f$holes,
    #policyVersion: _f$policyVersion,
  };

  static SandboxReadGrant _instantiate(DecodingData data) {
    return SandboxReadGrant(
      capabilitySid: data.dec(_f$capabilitySid),
      readRoots: data.dec(_f$readRoots),
      holes: data.dec(_f$holes),
      policyVersion: data.dec(_f$policyVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxReadGrant fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxReadGrant>(map);
  }

  static SandboxReadGrant fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxReadGrant>(json);
  }
}

mixin SandboxReadGrantMappable {
  String toJson() {
    return SandboxReadGrantMapper.ensureInitialized()
        .encodeJson<SandboxReadGrant>(this as SandboxReadGrant);
  }

  Map<String, dynamic> toMap() {
    return SandboxReadGrantMapper.ensureInitialized()
        .encodeMap<SandboxReadGrant>(this as SandboxReadGrant);
  }

  SandboxReadGrantCopyWith<SandboxReadGrant, SandboxReadGrant, SandboxReadGrant>
  get copyWith =>
      _SandboxReadGrantCopyWithImpl<SandboxReadGrant, SandboxReadGrant>(
        this as SandboxReadGrant,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SandboxReadGrantMapper.ensureInitialized().stringifyValue(
      this as SandboxReadGrant,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxReadGrantMapper.ensureInitialized().equalsValue(
      this as SandboxReadGrant,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxReadGrantMapper.ensureInitialized().hashValue(
      this as SandboxReadGrant,
    );
  }
}

extension SandboxReadGrantValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxReadGrant, $Out> {
  SandboxReadGrantCopyWith<$R, SandboxReadGrant, $Out>
  get $asSandboxReadGrant =>
      $base.as((v, t, t2) => _SandboxReadGrantCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SandboxReadGrantCopyWith<$R, $In extends SandboxReadGrant, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get readRoots;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get holes;
  $R call({
    String? capabilitySid,
    List<String>? readRoots,
    List<String>? holes,
    int? policyVersion,
  });
  SandboxReadGrantCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SandboxReadGrantCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxReadGrant, $Out>
    implements SandboxReadGrantCopyWith<$R, SandboxReadGrant, $Out> {
  _SandboxReadGrantCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxReadGrant> $mapper =
      SandboxReadGrantMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get readRoots =>
      ListCopyWith(
        $value.readRoots,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(readRoots: v),
      );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get holes =>
      ListCopyWith(
        $value.holes,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(holes: v),
      );
  @override
  $R call({
    String? capabilitySid,
    List<String>? readRoots,
    List<String>? holes,
    int? policyVersion,
  }) => $apply(
    FieldCopyWithData({
      if (capabilitySid != null) #capabilitySid: capabilitySid,
      if (readRoots != null) #readRoots: readRoots,
      if (holes != null) #holes: holes,
      if (policyVersion != null) #policyVersion: policyVersion,
    }),
  );
  @override
  SandboxReadGrant $make(CopyWithData data) => SandboxReadGrant(
    capabilitySid: data.get(#capabilitySid, or: $value.capabilitySid),
    readRoots: data.get(#readRoots, or: $value.readRoots),
    holes: data.get(#holes, or: $value.holes),
    policyVersion: data.get(#policyVersion, or: $value.policyVersion),
  );

  @override
  SandboxReadGrantCopyWith<$R2, SandboxReadGrant, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SandboxReadGrantCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

