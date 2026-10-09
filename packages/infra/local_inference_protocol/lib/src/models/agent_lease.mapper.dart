// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'agent_lease.dart';

class AgentLeaseKindMapper extends EnumMapper<AgentLeaseKind> {
  AgentLeaseKindMapper._();

  static AgentLeaseKindMapper? _instance;
  static AgentLeaseKindMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentLeaseKindMapper._());
    }
    return _instance!;
  }

  static AgentLeaseKind fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  AgentLeaseKind decode(dynamic value) {
    switch (value) {
      case r'primary':
        return AgentLeaseKind.primary;
      case r'subagent':
        return AgentLeaseKind.subagent;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(AgentLeaseKind self) {
    switch (self) {
      case AgentLeaseKind.primary:
        return r'primary';
      case AgentLeaseKind.subagent:
        return r'subagent';
    }
  }
}

extension AgentLeaseKindMapperExtension on AgentLeaseKind {
  String toValue() {
    AgentLeaseKindMapper.ensureInitialized();
    return MapperContainer.globals.toValue<AgentLeaseKind>(this) as String;
  }
}

class AgentOpenRequestMapper extends ClassMapperBase<AgentOpenRequest> {
  AgentOpenRequestMapper._();

  static AgentOpenRequestMapper? _instance;
  static AgentOpenRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentOpenRequestMapper._());
      AgentLeaseKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AgentOpenRequest';

  static AgentLeaseKind _$kind(AgentOpenRequest v) => v.kind;
  static const Field<AgentOpenRequest, AgentLeaseKind> _f$kind = Field(
    'kind',
    _$kind,
  );

  @override
  final MappableFields<AgentOpenRequest> fields = const {#kind: _f$kind};

  static AgentOpenRequest _instantiate(DecodingData data) {
    return AgentOpenRequest(kind: data.dec(_f$kind));
  }

  @override
  final Function instantiate = _instantiate;

  static AgentOpenRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentOpenRequest>(map);
  }

  static AgentOpenRequest fromJson(String json) {
    return ensureInitialized().decodeJson<AgentOpenRequest>(json);
  }
}

mixin AgentOpenRequestMappable {
  String toJson() {
    return AgentOpenRequestMapper.ensureInitialized()
        .encodeJson<AgentOpenRequest>(this as AgentOpenRequest);
  }

  Map<String, dynamic> toMap() {
    return AgentOpenRequestMapper.ensureInitialized()
        .encodeMap<AgentOpenRequest>(this as AgentOpenRequest);
  }

  AgentOpenRequestCopyWith<AgentOpenRequest, AgentOpenRequest, AgentOpenRequest>
  get copyWith =>
      _AgentOpenRequestCopyWithImpl<AgentOpenRequest, AgentOpenRequest>(
        this as AgentOpenRequest,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AgentOpenRequestMapper.ensureInitialized().stringifyValue(
      this as AgentOpenRequest,
    );
  }

  @override
  bool operator ==(Object other) {
    return AgentOpenRequestMapper.ensureInitialized().equalsValue(
      this as AgentOpenRequest,
      other,
    );
  }

  @override
  int get hashCode {
    return AgentOpenRequestMapper.ensureInitialized().hashValue(
      this as AgentOpenRequest,
    );
  }
}

extension AgentOpenRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentOpenRequest, $Out> {
  AgentOpenRequestCopyWith<$R, AgentOpenRequest, $Out>
  get $asAgentOpenRequest =>
      $base.as((v, t, t2) => _AgentOpenRequestCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AgentOpenRequestCopyWith<$R, $In extends AgentOpenRequest, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({AgentLeaseKind? kind});
  AgentOpenRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AgentOpenRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentOpenRequest, $Out>
    implements AgentOpenRequestCopyWith<$R, AgentOpenRequest, $Out> {
  _AgentOpenRequestCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentOpenRequest> $mapper =
      AgentOpenRequestMapper.ensureInitialized();
  @override
  $R call({AgentLeaseKind? kind}) =>
      $apply(FieldCopyWithData({if (kind != null) #kind: kind}));
  @override
  AgentOpenRequest $make(CopyWithData data) =>
      AgentOpenRequest(kind: data.get(#kind, or: $value.kind));

  @override
  AgentOpenRequestCopyWith<$R2, AgentOpenRequest, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AgentOpenRequestCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AgentOpenResultMapper extends ClassMapperBase<AgentOpenResult> {
  AgentOpenResultMapper._();

  static AgentOpenResultMapper? _instance;
  static AgentOpenResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentOpenResultMapper._());
      AgentOpenedMapper.ensureInitialized();
      AgentNoCapacityMapper.ensureInitialized();
      AgentInsufficientClaimMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AgentOpenResult';

  @override
  final MappableFields<AgentOpenResult> fields = const {};

  static AgentOpenResult _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'AgentOpenResult',
      'result',
      '${data.value['result']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AgentOpenResult fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentOpenResult>(map);
  }

  static AgentOpenResult fromJson(String json) {
    return ensureInitialized().decodeJson<AgentOpenResult>(json);
  }
}

mixin AgentOpenResultMappable {
  String toJson();
  Map<String, dynamic> toMap();
  AgentOpenResultCopyWith<AgentOpenResult, AgentOpenResult, AgentOpenResult>
  get copyWith;
}

abstract class AgentOpenResultCopyWith<$R, $In extends AgentOpenResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  AgentOpenResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class AgentOpenedMapper extends SubClassMapperBase<AgentOpened> {
  AgentOpenedMapper._();

  static AgentOpenedMapper? _instance;
  static AgentOpenedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentOpenedMapper._());
      AgentOpenResultMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'AgentOpened';

  static int _$claimedTokens(AgentOpened v) => v.claimedTokens;
  static const Field<AgentOpened, int> _f$claimedTokens = Field(
    'claimedTokens',
    _$claimedTokens,
    key: r'claimed_tokens',
  );

  @override
  final MappableFields<AgentOpened> fields = const {
    #claimedTokens: _f$claimedTokens,
  };

  @override
  final String discriminatorKey = 'result';
  @override
  final dynamic discriminatorValue = 'opened';
  @override
  late final ClassMapperBase superMapper =
      AgentOpenResultMapper.ensureInitialized();

  static AgentOpened _instantiate(DecodingData data) {
    return AgentOpened(claimedTokens: data.dec(_f$claimedTokens));
  }

  @override
  final Function instantiate = _instantiate;

  static AgentOpened fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentOpened>(map);
  }

  static AgentOpened fromJson(String json) {
    return ensureInitialized().decodeJson<AgentOpened>(json);
  }
}

mixin AgentOpenedMappable {
  String toJson() {
    return AgentOpenedMapper.ensureInitialized().encodeJson<AgentOpened>(
      this as AgentOpened,
    );
  }

  Map<String, dynamic> toMap() {
    return AgentOpenedMapper.ensureInitialized().encodeMap<AgentOpened>(
      this as AgentOpened,
    );
  }

  AgentOpenedCopyWith<AgentOpened, AgentOpened, AgentOpened> get copyWith =>
      _AgentOpenedCopyWithImpl<AgentOpened, AgentOpened>(
        this as AgentOpened,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AgentOpenedMapper.ensureInitialized().stringifyValue(
      this as AgentOpened,
    );
  }

  @override
  bool operator ==(Object other) {
    return AgentOpenedMapper.ensureInitialized().equalsValue(
      this as AgentOpened,
      other,
    );
  }

  @override
  int get hashCode {
    return AgentOpenedMapper.ensureInitialized().hashValue(this as AgentOpened);
  }
}

extension AgentOpenedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentOpened, $Out> {
  AgentOpenedCopyWith<$R, AgentOpened, $Out> get $asAgentOpened =>
      $base.as((v, t, t2) => _AgentOpenedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AgentOpenedCopyWith<$R, $In extends AgentOpened, $Out>
    implements AgentOpenResultCopyWith<$R, $In, $Out> {
  @override
  $R call({int? claimedTokens});
  AgentOpenedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AgentOpenedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentOpened, $Out>
    implements AgentOpenedCopyWith<$R, AgentOpened, $Out> {
  _AgentOpenedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentOpened> $mapper =
      AgentOpenedMapper.ensureInitialized();
  @override
  $R call({int? claimedTokens}) => $apply(
    FieldCopyWithData({
      if (claimedTokens != null) #claimedTokens: claimedTokens,
    }),
  );
  @override
  AgentOpened $make(CopyWithData data) => AgentOpened(
    claimedTokens: data.get(#claimedTokens, or: $value.claimedTokens),
  );

  @override
  AgentOpenedCopyWith<$R2, AgentOpened, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AgentOpenedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AgentNoCapacityMapper extends SubClassMapperBase<AgentNoCapacity> {
  AgentNoCapacityMapper._();

  static AgentNoCapacityMapper? _instance;
  static AgentNoCapacityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentNoCapacityMapper._());
      AgentOpenResultMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'AgentNoCapacity';

  @override
  final MappableFields<AgentNoCapacity> fields = const {};

  @override
  final String discriminatorKey = 'result';
  @override
  final dynamic discriminatorValue = 'no_capacity';
  @override
  late final ClassMapperBase superMapper =
      AgentOpenResultMapper.ensureInitialized();

  static AgentNoCapacity _instantiate(DecodingData data) {
    return AgentNoCapacity();
  }

  @override
  final Function instantiate = _instantiate;

  static AgentNoCapacity fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentNoCapacity>(map);
  }

  static AgentNoCapacity fromJson(String json) {
    return ensureInitialized().decodeJson<AgentNoCapacity>(json);
  }
}

mixin AgentNoCapacityMappable {
  String toJson() {
    return AgentNoCapacityMapper.ensureInitialized()
        .encodeJson<AgentNoCapacity>(this as AgentNoCapacity);
  }

  Map<String, dynamic> toMap() {
    return AgentNoCapacityMapper.ensureInitialized().encodeMap<AgentNoCapacity>(
      this as AgentNoCapacity,
    );
  }

  AgentNoCapacityCopyWith<AgentNoCapacity, AgentNoCapacity, AgentNoCapacity>
  get copyWith =>
      _AgentNoCapacityCopyWithImpl<AgentNoCapacity, AgentNoCapacity>(
        this as AgentNoCapacity,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AgentNoCapacityMapper.ensureInitialized().stringifyValue(
      this as AgentNoCapacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return AgentNoCapacityMapper.ensureInitialized().equalsValue(
      this as AgentNoCapacity,
      other,
    );
  }

  @override
  int get hashCode {
    return AgentNoCapacityMapper.ensureInitialized().hashValue(
      this as AgentNoCapacity,
    );
  }
}

extension AgentNoCapacityValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentNoCapacity, $Out> {
  AgentNoCapacityCopyWith<$R, AgentNoCapacity, $Out> get $asAgentNoCapacity =>
      $base.as((v, t, t2) => _AgentNoCapacityCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AgentNoCapacityCopyWith<$R, $In extends AgentNoCapacity, $Out>
    implements AgentOpenResultCopyWith<$R, $In, $Out> {
  @override
  $R call();
  AgentNoCapacityCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AgentNoCapacityCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentNoCapacity, $Out>
    implements AgentNoCapacityCopyWith<$R, AgentNoCapacity, $Out> {
  _AgentNoCapacityCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentNoCapacity> $mapper =
      AgentNoCapacityMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  AgentNoCapacity $make(CopyWithData data) => AgentNoCapacity();

  @override
  AgentNoCapacityCopyWith<$R2, AgentNoCapacity, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AgentNoCapacityCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AgentInsufficientClaimMapper
    extends SubClassMapperBase<AgentInsufficientClaim> {
  AgentInsufficientClaimMapper._();

  static AgentInsufficientClaimMapper? _instance;
  static AgentInsufficientClaimMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentInsufficientClaimMapper._());
      AgentOpenResultMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'AgentInsufficientClaim';

  @override
  final MappableFields<AgentInsufficientClaim> fields = const {};

  @override
  final String discriminatorKey = 'result';
  @override
  final dynamic discriminatorValue = 'insufficient_claim';
  @override
  late final ClassMapperBase superMapper =
      AgentOpenResultMapper.ensureInitialized();

  static AgentInsufficientClaim _instantiate(DecodingData data) {
    return AgentInsufficientClaim();
  }

  @override
  final Function instantiate = _instantiate;

  static AgentInsufficientClaim fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentInsufficientClaim>(map);
  }

  static AgentInsufficientClaim fromJson(String json) {
    return ensureInitialized().decodeJson<AgentInsufficientClaim>(json);
  }
}

mixin AgentInsufficientClaimMappable {
  String toJson() {
    return AgentInsufficientClaimMapper.ensureInitialized()
        .encodeJson<AgentInsufficientClaim>(this as AgentInsufficientClaim);
  }

  Map<String, dynamic> toMap() {
    return AgentInsufficientClaimMapper.ensureInitialized()
        .encodeMap<AgentInsufficientClaim>(this as AgentInsufficientClaim);
  }

  AgentInsufficientClaimCopyWith<
    AgentInsufficientClaim,
    AgentInsufficientClaim,
    AgentInsufficientClaim
  >
  get copyWith =>
      _AgentInsufficientClaimCopyWithImpl<
        AgentInsufficientClaim,
        AgentInsufficientClaim
      >(this as AgentInsufficientClaim, $identity, $identity);
  @override
  String toString() {
    return AgentInsufficientClaimMapper.ensureInitialized().stringifyValue(
      this as AgentInsufficientClaim,
    );
  }

  @override
  bool operator ==(Object other) {
    return AgentInsufficientClaimMapper.ensureInitialized().equalsValue(
      this as AgentInsufficientClaim,
      other,
    );
  }

  @override
  int get hashCode {
    return AgentInsufficientClaimMapper.ensureInitialized().hashValue(
      this as AgentInsufficientClaim,
    );
  }
}

extension AgentInsufficientClaimValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentInsufficientClaim, $Out> {
  AgentInsufficientClaimCopyWith<$R, AgentInsufficientClaim, $Out>
  get $asAgentInsufficientClaim => $base.as(
    (v, t, t2) => _AgentInsufficientClaimCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class AgentInsufficientClaimCopyWith<
  $R,
  $In extends AgentInsufficientClaim,
  $Out
>
    implements AgentOpenResultCopyWith<$R, $In, $Out> {
  @override
  $R call();
  AgentInsufficientClaimCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AgentInsufficientClaimCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentInsufficientClaim, $Out>
    implements
        AgentInsufficientClaimCopyWith<$R, AgentInsufficientClaim, $Out> {
  _AgentInsufficientClaimCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentInsufficientClaim> $mapper =
      AgentInsufficientClaimMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  AgentInsufficientClaim $make(CopyWithData data) => AgentInsufficientClaim();

  @override
  AgentInsufficientClaimCopyWith<$R2, AgentInsufficientClaim, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AgentInsufficientClaimCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

