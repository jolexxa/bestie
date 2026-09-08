// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'lowered_policy.dart';

class GrantAccessMapper extends EnumMapper<GrantAccess> {
  GrantAccessMapper._();

  static GrantAccessMapper? _instance;
  static GrantAccessMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GrantAccessMapper._());
    }
    return _instance!;
  }

  static GrantAccess fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  GrantAccess decode(dynamic value) {
    switch (value) {
      case r'read':
        return GrantAccess.read;
      case r'readWrite':
        return GrantAccess.readWrite;
      case r'listDir':
        return GrantAccess.listDir;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(GrantAccess self) {
    switch (self) {
      case GrantAccess.read:
        return r'read';
      case GrantAccess.readWrite:
        return r'readWrite';
      case GrantAccess.listDir:
        return r'listDir';
    }
  }
}

extension GrantAccessMapperExtension on GrantAccess {
  String toValue() {
    GrantAccessMapper.ensureInitialized();
    return MapperContainer.globals.toValue<GrantAccess>(this) as String;
  }
}

class GrantMapper extends ClassMapperBase<Grant> {
  GrantMapper._();

  static GrantMapper? _instance;
  static GrantMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GrantMapper._());
      GrantAccessMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Grant';

  static String _$path(Grant v) => v.path;
  static const Field<Grant, String> _f$path = Field('path', _$path);
  static GrantAccess _$access(Grant v) => v.access;
  static const Field<Grant, GrantAccess> _f$access = Field('access', _$access);

  @override
  final MappableFields<Grant> fields = const {
    #path: _f$path,
    #access: _f$access,
  };

  static Grant _instantiate(DecodingData data) {
    return Grant(data.dec(_f$path), data.dec(_f$access));
  }

  @override
  final Function instantiate = _instantiate;

  static Grant fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Grant>(map);
  }

  static Grant fromJson(String json) {
    return ensureInitialized().decodeJson<Grant>(json);
  }
}

mixin GrantMappable {
  String toJson() {
    return GrantMapper.ensureInitialized().encodeJson<Grant>(this as Grant);
  }

  Map<String, dynamic> toMap() {
    return GrantMapper.ensureInitialized().encodeMap<Grant>(this as Grant);
  }

  GrantCopyWith<Grant, Grant, Grant> get copyWith =>
      _GrantCopyWithImpl<Grant, Grant>(this as Grant, $identity, $identity);
  @override
  String toString() {
    return GrantMapper.ensureInitialized().stringifyValue(this as Grant);
  }

  @override
  bool operator ==(Object other) {
    return GrantMapper.ensureInitialized().equalsValue(this as Grant, other);
  }

  @override
  int get hashCode {
    return GrantMapper.ensureInitialized().hashValue(this as Grant);
  }
}

extension GrantValueCopy<$R, $Out> on ObjectCopyWith<$R, Grant, $Out> {
  GrantCopyWith<$R, Grant, $Out> get $asGrant =>
      $base.as((v, t, t2) => _GrantCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GrantCopyWith<$R, $In extends Grant, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? path, GrantAccess? access});
  GrantCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GrantCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Grant, $Out>
    implements GrantCopyWith<$R, Grant, $Out> {
  _GrantCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Grant> $mapper = GrantMapper.ensureInitialized();
  @override
  $R call({String? path, GrantAccess? access}) => $apply(
    FieldCopyWithData({
      if (path != null) #path: path,
      if (access != null) #access: access,
    }),
  );
  @override
  Grant $make(CopyWithData data) => Grant(
    data.get(#path, or: $value.path),
    data.get(#access, or: $value.access),
  );

  @override
  GrantCopyWith<$R2, Grant, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _GrantCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DenyMapper extends ClassMapperBase<Deny> {
  DenyMapper._();

  static DenyMapper? _instance;
  static DenyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DenyMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Deny';

  static String _$path(Deny v) => v.path;
  static const Field<Deny, String> _f$path = Field('path', _$path);

  @override
  final MappableFields<Deny> fields = const {#path: _f$path};

  static Deny _instantiate(DecodingData data) {
    return Deny(data.dec(_f$path));
  }

  @override
  final Function instantiate = _instantiate;

  static Deny fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Deny>(map);
  }

  static Deny fromJson(String json) {
    return ensureInitialized().decodeJson<Deny>(json);
  }
}

mixin DenyMappable {
  String toJson() {
    return DenyMapper.ensureInitialized().encodeJson<Deny>(this as Deny);
  }

  Map<String, dynamic> toMap() {
    return DenyMapper.ensureInitialized().encodeMap<Deny>(this as Deny);
  }

  DenyCopyWith<Deny, Deny, Deny> get copyWith =>
      _DenyCopyWithImpl<Deny, Deny>(this as Deny, $identity, $identity);
  @override
  String toString() {
    return DenyMapper.ensureInitialized().stringifyValue(this as Deny);
  }

  @override
  bool operator ==(Object other) {
    return DenyMapper.ensureInitialized().equalsValue(this as Deny, other);
  }

  @override
  int get hashCode {
    return DenyMapper.ensureInitialized().hashValue(this as Deny);
  }
}

extension DenyValueCopy<$R, $Out> on ObjectCopyWith<$R, Deny, $Out> {
  DenyCopyWith<$R, Deny, $Out> get $asDeny =>
      $base.as((v, t, t2) => _DenyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DenyCopyWith<$R, $In extends Deny, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? path});
  DenyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DenyCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Deny, $Out>
    implements DenyCopyWith<$R, Deny, $Out> {
  _DenyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Deny> $mapper = DenyMapper.ensureInitialized();
  @override
  $R call({String? path}) =>
      $apply(FieldCopyWithData({if (path != null) #path: path}));
  @override
  Deny $make(CopyWithData data) => Deny(data.get(#path, or: $value.path));

  @override
  DenyCopyWith<$R2, Deny, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DenyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LoweredPolicyMapper extends ClassMapperBase<LoweredPolicy> {
  LoweredPolicyMapper._();

  static LoweredPolicyMapper? _instance;
  static LoweredPolicyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LoweredPolicyMapper._());
      GrantProgramMapper.ensureInitialized();
      MaskedProgramMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LoweredPolicy';

  @override
  final MappableFields<LoweredPolicy> fields = const {};

  static LoweredPolicy _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'LoweredPolicy',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LoweredPolicy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LoweredPolicy>(map);
  }

  static LoweredPolicy fromJson(String json) {
    return ensureInitialized().decodeJson<LoweredPolicy>(json);
  }
}

mixin LoweredPolicyMappable {
  String toJson();
  Map<String, dynamic> toMap();
  LoweredPolicyCopyWith<LoweredPolicy, LoweredPolicy, LoweredPolicy>
  get copyWith;
}

abstract class LoweredPolicyCopyWith<$R, $In extends LoweredPolicy, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  LoweredPolicyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class GrantProgramMapper extends SubClassMapperBase<GrantProgram> {
  GrantProgramMapper._();

  static GrantProgramMapper? _instance;
  static GrantProgramMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GrantProgramMapper._());
      LoweredPolicyMapper.ensureInitialized().addSubMapper(_instance!);
      GrantMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GrantProgram';

  static List<Grant> _$grants(GrantProgram v) => v.grants;
  static const Field<GrantProgram, List<Grant>> _f$grants = Field(
    'grants',
    _$grants,
  );

  @override
  final MappableFields<GrantProgram> fields = const {#grants: _f$grants};

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'grant';
  @override
  late final ClassMapperBase superMapper =
      LoweredPolicyMapper.ensureInitialized();

  static GrantProgram _instantiate(DecodingData data) {
    return GrantProgram(data.dec(_f$grants));
  }

  @override
  final Function instantiate = _instantiate;

  static GrantProgram fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GrantProgram>(map);
  }

  static GrantProgram fromJson(String json) {
    return ensureInitialized().decodeJson<GrantProgram>(json);
  }
}

mixin GrantProgramMappable {
  String toJson() {
    return GrantProgramMapper.ensureInitialized().encodeJson<GrantProgram>(
      this as GrantProgram,
    );
  }

  Map<String, dynamic> toMap() {
    return GrantProgramMapper.ensureInitialized().encodeMap<GrantProgram>(
      this as GrantProgram,
    );
  }

  GrantProgramCopyWith<GrantProgram, GrantProgram, GrantProgram> get copyWith =>
      _GrantProgramCopyWithImpl<GrantProgram, GrantProgram>(
        this as GrantProgram,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return GrantProgramMapper.ensureInitialized().stringifyValue(
      this as GrantProgram,
    );
  }

  @override
  bool operator ==(Object other) {
    return GrantProgramMapper.ensureInitialized().equalsValue(
      this as GrantProgram,
      other,
    );
  }

  @override
  int get hashCode {
    return GrantProgramMapper.ensureInitialized().hashValue(
      this as GrantProgram,
    );
  }
}

extension GrantProgramValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GrantProgram, $Out> {
  GrantProgramCopyWith<$R, GrantProgram, $Out> get $asGrantProgram =>
      $base.as((v, t, t2) => _GrantProgramCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class GrantProgramCopyWith<$R, $In extends GrantProgram, $Out>
    implements LoweredPolicyCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Grant, GrantCopyWith<$R, Grant, Grant>> get grants;
  @override
  $R call({List<Grant>? grants});
  GrantProgramCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _GrantProgramCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GrantProgram, $Out>
    implements GrantProgramCopyWith<$R, GrantProgram, $Out> {
  _GrantProgramCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GrantProgram> $mapper =
      GrantProgramMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Grant, GrantCopyWith<$R, Grant, Grant>> get grants =>
      ListCopyWith(
        $value.grants,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(grants: v),
      );
  @override
  $R call({List<Grant>? grants}) =>
      $apply(FieldCopyWithData({if (grants != null) #grants: grants}));
  @override
  GrantProgram $make(CopyWithData data) =>
      GrantProgram(data.get(#grants, or: $value.grants));

  @override
  GrantProgramCopyWith<$R2, GrantProgram, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _GrantProgramCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class MaskedProgramMapper extends SubClassMapperBase<MaskedProgram> {
  MaskedProgramMapper._();

  static MaskedProgramMapper? _instance;
  static MaskedProgramMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MaskedProgramMapper._());
      LoweredPolicyMapper.ensureInitialized().addSubMapper(_instance!);
      GrantMapper.ensureInitialized();
      DenyMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MaskedProgram';

  static List<Grant> _$grants(MaskedProgram v) => v.grants;
  static const Field<MaskedProgram, List<Grant>> _f$grants = Field(
    'grants',
    _$grants,
  );
  static List<Deny> _$denies(MaskedProgram v) => v.denies;
  static const Field<MaskedProgram, List<Deny>> _f$denies = Field(
    'denies',
    _$denies,
  );

  @override
  final MappableFields<MaskedProgram> fields = const {
    #grants: _f$grants,
    #denies: _f$denies,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'masked';
  @override
  late final ClassMapperBase superMapper =
      LoweredPolicyMapper.ensureInitialized();

  static MaskedProgram _instantiate(DecodingData data) {
    return MaskedProgram(data.dec(_f$grants), data.dec(_f$denies));
  }

  @override
  final Function instantiate = _instantiate;

  static MaskedProgram fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MaskedProgram>(map);
  }

  static MaskedProgram fromJson(String json) {
    return ensureInitialized().decodeJson<MaskedProgram>(json);
  }
}

mixin MaskedProgramMappable {
  String toJson() {
    return MaskedProgramMapper.ensureInitialized().encodeJson<MaskedProgram>(
      this as MaskedProgram,
    );
  }

  Map<String, dynamic> toMap() {
    return MaskedProgramMapper.ensureInitialized().encodeMap<MaskedProgram>(
      this as MaskedProgram,
    );
  }

  MaskedProgramCopyWith<MaskedProgram, MaskedProgram, MaskedProgram>
  get copyWith => _MaskedProgramCopyWithImpl<MaskedProgram, MaskedProgram>(
    this as MaskedProgram,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return MaskedProgramMapper.ensureInitialized().stringifyValue(
      this as MaskedProgram,
    );
  }

  @override
  bool operator ==(Object other) {
    return MaskedProgramMapper.ensureInitialized().equalsValue(
      this as MaskedProgram,
      other,
    );
  }

  @override
  int get hashCode {
    return MaskedProgramMapper.ensureInitialized().hashValue(
      this as MaskedProgram,
    );
  }
}

extension MaskedProgramValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MaskedProgram, $Out> {
  MaskedProgramCopyWith<$R, MaskedProgram, $Out> get $asMaskedProgram =>
      $base.as((v, t, t2) => _MaskedProgramCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MaskedProgramCopyWith<$R, $In extends MaskedProgram, $Out>
    implements LoweredPolicyCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Grant, GrantCopyWith<$R, Grant, Grant>> get grants;
  ListCopyWith<$R, Deny, DenyCopyWith<$R, Deny, Deny>> get denies;
  @override
  $R call({List<Grant>? grants, List<Deny>? denies});
  MaskedProgramCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MaskedProgramCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MaskedProgram, $Out>
    implements MaskedProgramCopyWith<$R, MaskedProgram, $Out> {
  _MaskedProgramCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MaskedProgram> $mapper =
      MaskedProgramMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Grant, GrantCopyWith<$R, Grant, Grant>> get grants =>
      ListCopyWith(
        $value.grants,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(grants: v),
      );
  @override
  ListCopyWith<$R, Deny, DenyCopyWith<$R, Deny, Deny>> get denies =>
      ListCopyWith(
        $value.denies,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(denies: v),
      );
  @override
  $R call({List<Grant>? grants, List<Deny>? denies}) => $apply(
    FieldCopyWithData({
      if (grants != null) #grants: grants,
      if (denies != null) #denies: denies,
    }),
  );
  @override
  MaskedProgram $make(CopyWithData data) => MaskedProgram(
    data.get(#grants, or: $value.grants),
    data.get(#denies, or: $value.denies),
  );

  @override
  MaskedProgramCopyWith<$R2, MaskedProgram, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MaskedProgramCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

