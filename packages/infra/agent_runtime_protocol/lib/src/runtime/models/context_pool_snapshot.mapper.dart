// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'context_pool_snapshot.dart';

class PoolLeaseOccupancyMapper extends ClassMapperBase<PoolLeaseOccupancy> {
  PoolLeaseOccupancyMapper._();

  static PoolLeaseOccupancyMapper? _instance;
  static PoolLeaseOccupancyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PoolLeaseOccupancyMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PoolLeaseOccupancy';

  static AgentHandle _$handle(PoolLeaseOccupancy v) => v.handle;
  static const Field<PoolLeaseOccupancy, AgentHandle> _f$handle = Field(
    'handle',
    _$handle,
  );
  static int _$residentTokens(PoolLeaseOccupancy v) => v.residentTokens;
  static const Field<PoolLeaseOccupancy, int> _f$residentTokens = Field(
    'residentTokens',
    _$residentTokens,
  );
  static int _$claimTokens(PoolLeaseOccupancy v) => v.claimTokens;
  static const Field<PoolLeaseOccupancy, int> _f$claimTokens = Field(
    'claimTokens',
    _$claimTokens,
  );

  @override
  final MappableFields<PoolLeaseOccupancy> fields = const {
    #handle: _f$handle,
    #residentTokens: _f$residentTokens,
    #claimTokens: _f$claimTokens,
  };

  static PoolLeaseOccupancy _instantiate(DecodingData data) {
    return PoolLeaseOccupancy(
      handle: data.dec(_f$handle),
      residentTokens: data.dec(_f$residentTokens),
      claimTokens: data.dec(_f$claimTokens),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PoolLeaseOccupancy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PoolLeaseOccupancy>(map);
  }

  static PoolLeaseOccupancy fromJson(String json) {
    return ensureInitialized().decodeJson<PoolLeaseOccupancy>(json);
  }
}

mixin PoolLeaseOccupancyMappable {
  String toJson() {
    return PoolLeaseOccupancyMapper.ensureInitialized()
        .encodeJson<PoolLeaseOccupancy>(this as PoolLeaseOccupancy);
  }

  Map<String, dynamic> toMap() {
    return PoolLeaseOccupancyMapper.ensureInitialized()
        .encodeMap<PoolLeaseOccupancy>(this as PoolLeaseOccupancy);
  }

  PoolLeaseOccupancyCopyWith<
    PoolLeaseOccupancy,
    PoolLeaseOccupancy,
    PoolLeaseOccupancy
  >
  get copyWith =>
      _PoolLeaseOccupancyCopyWithImpl<PoolLeaseOccupancy, PoolLeaseOccupancy>(
        this as PoolLeaseOccupancy,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PoolLeaseOccupancyMapper.ensureInitialized().stringifyValue(
      this as PoolLeaseOccupancy,
    );
  }

  @override
  bool operator ==(Object other) {
    return PoolLeaseOccupancyMapper.ensureInitialized().equalsValue(
      this as PoolLeaseOccupancy,
      other,
    );
  }

  @override
  int get hashCode {
    return PoolLeaseOccupancyMapper.ensureInitialized().hashValue(
      this as PoolLeaseOccupancy,
    );
  }
}

extension PoolLeaseOccupancyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PoolLeaseOccupancy, $Out> {
  PoolLeaseOccupancyCopyWith<$R, PoolLeaseOccupancy, $Out>
  get $asPoolLeaseOccupancy => $base.as(
    (v, t, t2) => _PoolLeaseOccupancyCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PoolLeaseOccupancyCopyWith<
  $R,
  $In extends PoolLeaseOccupancy,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({AgentHandle? handle, int? residentTokens, int? claimTokens});
  PoolLeaseOccupancyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PoolLeaseOccupancyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PoolLeaseOccupancy, $Out>
    implements PoolLeaseOccupancyCopyWith<$R, PoolLeaseOccupancy, $Out> {
  _PoolLeaseOccupancyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PoolLeaseOccupancy> $mapper =
      PoolLeaseOccupancyMapper.ensureInitialized();
  @override
  $R call({AgentHandle? handle, int? residentTokens, int? claimTokens}) =>
      $apply(
        FieldCopyWithData({
          if (handle != null) #handle: handle,
          if (residentTokens != null) #residentTokens: residentTokens,
          if (claimTokens != null) #claimTokens: claimTokens,
        }),
      );
  @override
  PoolLeaseOccupancy $make(CopyWithData data) => PoolLeaseOccupancy(
    handle: data.get(#handle, or: $value.handle),
    residentTokens: data.get(#residentTokens, or: $value.residentTokens),
    claimTokens: data.get(#claimTokens, or: $value.claimTokens),
  );

  @override
  PoolLeaseOccupancyCopyWith<$R2, PoolLeaseOccupancy, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PoolLeaseOccupancyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ContextPoolSnapshotMapper extends ClassMapperBase<ContextPoolSnapshot> {
  ContextPoolSnapshotMapper._();

  static ContextPoolSnapshotMapper? _instance;
  static ContextPoolSnapshotMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ContextPoolSnapshotMapper._());
      PoolLeaseOccupancyMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ContextPoolSnapshot';

  static int _$contextSize(ContextPoolSnapshot v) => v.contextSize;
  static const Field<ContextPoolSnapshot, int> _f$contextSize = Field(
    'contextSize',
    _$contextSize,
  );
  static int _$reservedClaims(ContextPoolSnapshot v) => v.reservedClaims;
  static const Field<ContextPoolSnapshot, int> _f$reservedClaims = Field(
    'reservedClaims',
    _$reservedClaims,
  );
  static List<PoolLeaseOccupancy> _$leases(ContextPoolSnapshot v) => v.leases;
  static const Field<ContextPoolSnapshot, List<PoolLeaseOccupancy>> _f$leases =
      Field('leases', _$leases);

  @override
  final MappableFields<ContextPoolSnapshot> fields = const {
    #contextSize: _f$contextSize,
    #reservedClaims: _f$reservedClaims,
    #leases: _f$leases,
  };

  static ContextPoolSnapshot _instantiate(DecodingData data) {
    return ContextPoolSnapshot(
      contextSize: data.dec(_f$contextSize),
      reservedClaims: data.dec(_f$reservedClaims),
      leases: data.dec(_f$leases),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ContextPoolSnapshot fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ContextPoolSnapshot>(map);
  }

  static ContextPoolSnapshot fromJson(String json) {
    return ensureInitialized().decodeJson<ContextPoolSnapshot>(json);
  }
}

mixin ContextPoolSnapshotMappable {
  String toJson() {
    return ContextPoolSnapshotMapper.ensureInitialized()
        .encodeJson<ContextPoolSnapshot>(this as ContextPoolSnapshot);
  }

  Map<String, dynamic> toMap() {
    return ContextPoolSnapshotMapper.ensureInitialized()
        .encodeMap<ContextPoolSnapshot>(this as ContextPoolSnapshot);
  }

  ContextPoolSnapshotCopyWith<
    ContextPoolSnapshot,
    ContextPoolSnapshot,
    ContextPoolSnapshot
  >
  get copyWith =>
      _ContextPoolSnapshotCopyWithImpl<
        ContextPoolSnapshot,
        ContextPoolSnapshot
      >(this as ContextPoolSnapshot, $identity, $identity);
  @override
  String toString() {
    return ContextPoolSnapshotMapper.ensureInitialized().stringifyValue(
      this as ContextPoolSnapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    return ContextPoolSnapshotMapper.ensureInitialized().equalsValue(
      this as ContextPoolSnapshot,
      other,
    );
  }

  @override
  int get hashCode {
    return ContextPoolSnapshotMapper.ensureInitialized().hashValue(
      this as ContextPoolSnapshot,
    );
  }
}

extension ContextPoolSnapshotValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ContextPoolSnapshot, $Out> {
  ContextPoolSnapshotCopyWith<$R, ContextPoolSnapshot, $Out>
  get $asContextPoolSnapshot => $base.as(
    (v, t, t2) => _ContextPoolSnapshotCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ContextPoolSnapshotCopyWith<
  $R,
  $In extends ContextPoolSnapshot,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    PoolLeaseOccupancy,
    PoolLeaseOccupancyCopyWith<$R, PoolLeaseOccupancy, PoolLeaseOccupancy>
  >
  get leases;
  $R call({
    int? contextSize,
    int? reservedClaims,
    List<PoolLeaseOccupancy>? leases,
  });
  ContextPoolSnapshotCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ContextPoolSnapshotCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ContextPoolSnapshot, $Out>
    implements ContextPoolSnapshotCopyWith<$R, ContextPoolSnapshot, $Out> {
  _ContextPoolSnapshotCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ContextPoolSnapshot> $mapper =
      ContextPoolSnapshotMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    PoolLeaseOccupancy,
    PoolLeaseOccupancyCopyWith<$R, PoolLeaseOccupancy, PoolLeaseOccupancy>
  >
  get leases => ListCopyWith(
    $value.leases,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(leases: v),
  );
  @override
  $R call({
    int? contextSize,
    int? reservedClaims,
    List<PoolLeaseOccupancy>? leases,
  }) => $apply(
    FieldCopyWithData({
      if (contextSize != null) #contextSize: contextSize,
      if (reservedClaims != null) #reservedClaims: reservedClaims,
      if (leases != null) #leases: leases,
    }),
  );
  @override
  ContextPoolSnapshot $make(CopyWithData data) => ContextPoolSnapshot(
    contextSize: data.get(#contextSize, or: $value.contextSize),
    reservedClaims: data.get(#reservedClaims, or: $value.reservedClaims),
    leases: data.get(#leases, or: $value.leases),
  );

  @override
  ContextPoolSnapshotCopyWith<$R2, ContextPoolSnapshot, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ContextPoolSnapshotCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

