// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sandbox_enforcement.dart';

class SandboxCapabilityMapper extends EnumMapper<SandboxCapability> {
  SandboxCapabilityMapper._();

  static SandboxCapabilityMapper? _instance;
  static SandboxCapabilityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxCapabilityMapper._());
    }
    return _instance!;
  }

  static SandboxCapability fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  SandboxCapability decode(dynamic value) {
    switch (value) {
      case r'filesystemRead':
        return SandboxCapability.filesystemRead;
      case r'filesystemWrite':
        return SandboxCapability.filesystemWrite;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(SandboxCapability self) {
    switch (self) {
      case SandboxCapability.filesystemRead:
        return r'filesystemRead';
      case SandboxCapability.filesystemWrite:
        return r'filesystemWrite';
    }
  }
}

extension SandboxCapabilityMapperExtension on SandboxCapability {
  String toValue() {
    SandboxCapabilityMapper.ensureInitialized();
    return MapperContainer.globals.toValue<SandboxCapability>(this) as String;
  }
}

class NetworkEnforcementMapper extends ClassMapperBase<NetworkEnforcement> {
  NetworkEnforcementMapper._();

  static NetworkEnforcementMapper? _instance;
  static NetworkEnforcementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NetworkEnforcementMapper._());
      NetworkConfinedMapper.ensureInitialized();
      NetworkIneligibleForConfinementMapper.ensureInitialized();
      NetworkPartiallyConfinedMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NetworkEnforcement';

  @override
  final MappableFields<NetworkEnforcement> fields = const {};

  static NetworkEnforcement _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'NetworkEnforcement',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NetworkEnforcement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NetworkEnforcement>(map);
  }

  static NetworkEnforcement fromJson(String json) {
    return ensureInitialized().decodeJson<NetworkEnforcement>(json);
  }
}

mixin NetworkEnforcementMappable {
  String toJson();
  Map<String, dynamic> toMap();
  NetworkEnforcementCopyWith<
    NetworkEnforcement,
    NetworkEnforcement,
    NetworkEnforcement
  >
  get copyWith;
}

abstract class NetworkEnforcementCopyWith<
  $R,
  $In extends NetworkEnforcement,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  NetworkEnforcementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class NetworkConfinedMapper extends SubClassMapperBase<NetworkConfined> {
  NetworkConfinedMapper._();

  static NetworkConfinedMapper? _instance;
  static NetworkConfinedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NetworkConfinedMapper._());
      NetworkEnforcementMapper.ensureInitialized().addSubMapper(_instance!);
      NetworkTierMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NetworkConfined';

  static NetworkTier _$tier(NetworkConfined v) => v.tier;
  static const Field<NetworkConfined, NetworkTier> _f$tier = Field(
    'tier',
    _$tier,
  );

  @override
  final MappableFields<NetworkConfined> fields = const {#tier: _f$tier};

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'confined';
  @override
  late final ClassMapperBase superMapper =
      NetworkEnforcementMapper.ensureInitialized();

  static NetworkConfined _instantiate(DecodingData data) {
    return NetworkConfined(data.dec(_f$tier));
  }

  @override
  final Function instantiate = _instantiate;

  static NetworkConfined fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NetworkConfined>(map);
  }

  static NetworkConfined fromJson(String json) {
    return ensureInitialized().decodeJson<NetworkConfined>(json);
  }
}

mixin NetworkConfinedMappable {
  String toJson() {
    return NetworkConfinedMapper.ensureInitialized()
        .encodeJson<NetworkConfined>(this as NetworkConfined);
  }

  Map<String, dynamic> toMap() {
    return NetworkConfinedMapper.ensureInitialized().encodeMap<NetworkConfined>(
      this as NetworkConfined,
    );
  }

  NetworkConfinedCopyWith<NetworkConfined, NetworkConfined, NetworkConfined>
  get copyWith =>
      _NetworkConfinedCopyWithImpl<NetworkConfined, NetworkConfined>(
        this as NetworkConfined,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return NetworkConfinedMapper.ensureInitialized().stringifyValue(
      this as NetworkConfined,
    );
  }

  @override
  bool operator ==(Object other) {
    return NetworkConfinedMapper.ensureInitialized().equalsValue(
      this as NetworkConfined,
      other,
    );
  }

  @override
  int get hashCode {
    return NetworkConfinedMapper.ensureInitialized().hashValue(
      this as NetworkConfined,
    );
  }
}

extension NetworkConfinedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NetworkConfined, $Out> {
  NetworkConfinedCopyWith<$R, NetworkConfined, $Out> get $asNetworkConfined =>
      $base.as((v, t, t2) => _NetworkConfinedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class NetworkConfinedCopyWith<$R, $In extends NetworkConfined, $Out>
    implements NetworkEnforcementCopyWith<$R, $In, $Out> {
  @override
  $R call({NetworkTier? tier});
  NetworkConfinedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _NetworkConfinedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NetworkConfined, $Out>
    implements NetworkConfinedCopyWith<$R, NetworkConfined, $Out> {
  _NetworkConfinedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NetworkConfined> $mapper =
      NetworkConfinedMapper.ensureInitialized();
  @override
  $R call({NetworkTier? tier}) =>
      $apply(FieldCopyWithData({if (tier != null) #tier: tier}));
  @override
  NetworkConfined $make(CopyWithData data) =>
      NetworkConfined(data.get(#tier, or: $value.tier));

  @override
  NetworkConfinedCopyWith<$R2, NetworkConfined, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _NetworkConfinedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class NetworkIneligibleForConfinementMapper
    extends SubClassMapperBase<NetworkIneligibleForConfinement> {
  NetworkIneligibleForConfinementMapper._();

  static NetworkIneligibleForConfinementMapper? _instance;
  static NetworkIneligibleForConfinementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = NetworkIneligibleForConfinementMapper._(),
      );
      NetworkEnforcementMapper.ensureInitialized().addSubMapper(_instance!);
      NetworkTierMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NetworkIneligibleForConfinement';

  static NetworkTier _$requested(NetworkIneligibleForConfinement v) =>
      v.requested;
  static const Field<NetworkIneligibleForConfinement, NetworkTier>
  _f$requested = Field('requested', _$requested);
  static String _$reason(NetworkIneligibleForConfinement v) => v.reason;
  static const Field<NetworkIneligibleForConfinement, String> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<NetworkIneligibleForConfinement> fields = const {
    #requested: _f$requested,
    #reason: _f$reason,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'unconfinable';
  @override
  late final ClassMapperBase superMapper =
      NetworkEnforcementMapper.ensureInitialized();

  static NetworkIneligibleForConfinement _instantiate(DecodingData data) {
    return NetworkIneligibleForConfinement(
      data.dec(_f$requested),
      data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NetworkIneligibleForConfinement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NetworkIneligibleForConfinement>(map);
  }

  static NetworkIneligibleForConfinement fromJson(String json) {
    return ensureInitialized().decodeJson<NetworkIneligibleForConfinement>(
      json,
    );
  }
}

mixin NetworkIneligibleForConfinementMappable {
  String toJson() {
    return NetworkIneligibleForConfinementMapper.ensureInitialized()
        .encodeJson<NetworkIneligibleForConfinement>(
          this as NetworkIneligibleForConfinement,
        );
  }

  Map<String, dynamic> toMap() {
    return NetworkIneligibleForConfinementMapper.ensureInitialized()
        .encodeMap<NetworkIneligibleForConfinement>(
          this as NetworkIneligibleForConfinement,
        );
  }

  NetworkIneligibleForConfinementCopyWith<
    NetworkIneligibleForConfinement,
    NetworkIneligibleForConfinement,
    NetworkIneligibleForConfinement
  >
  get copyWith =>
      _NetworkIneligibleForConfinementCopyWithImpl<
        NetworkIneligibleForConfinement,
        NetworkIneligibleForConfinement
      >(this as NetworkIneligibleForConfinement, $identity, $identity);
  @override
  String toString() {
    return NetworkIneligibleForConfinementMapper.ensureInitialized()
        .stringifyValue(this as NetworkIneligibleForConfinement);
  }

  @override
  bool operator ==(Object other) {
    return NetworkIneligibleForConfinementMapper.ensureInitialized()
        .equalsValue(this as NetworkIneligibleForConfinement, other);
  }

  @override
  int get hashCode {
    return NetworkIneligibleForConfinementMapper.ensureInitialized().hashValue(
      this as NetworkIneligibleForConfinement,
    );
  }
}

extension NetworkIneligibleForConfinementValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NetworkIneligibleForConfinement, $Out> {
  NetworkIneligibleForConfinementCopyWith<
    $R,
    NetworkIneligibleForConfinement,
    $Out
  >
  get $asNetworkIneligibleForConfinement => $base.as(
    (v, t, t2) =>
        _NetworkIneligibleForConfinementCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class NetworkIneligibleForConfinementCopyWith<
  $R,
  $In extends NetworkIneligibleForConfinement,
  $Out
>
    implements NetworkEnforcementCopyWith<$R, $In, $Out> {
  @override
  $R call({NetworkTier? requested, String? reason});
  NetworkIneligibleForConfinementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _NetworkIneligibleForConfinementCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NetworkIneligibleForConfinement, $Out>
    implements
        NetworkIneligibleForConfinementCopyWith<
          $R,
          NetworkIneligibleForConfinement,
          $Out
        > {
  _NetworkIneligibleForConfinementCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<NetworkIneligibleForConfinement> $mapper =
      NetworkIneligibleForConfinementMapper.ensureInitialized();
  @override
  $R call({NetworkTier? requested, String? reason}) => $apply(
    FieldCopyWithData({
      if (requested != null) #requested: requested,
      if (reason != null) #reason: reason,
    }),
  );
  @override
  NetworkIneligibleForConfinement $make(CopyWithData data) =>
      NetworkIneligibleForConfinement(
        data.get(#requested, or: $value.requested),
        data.get(#reason, or: $value.reason),
      );

  @override
  NetworkIneligibleForConfinementCopyWith<
    $R2,
    NetworkIneligibleForConfinement,
    $Out2
  >
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _NetworkIneligibleForConfinementCopyWithImpl<$R2, $Out2>(
        $value,
        $cast,
        t,
      );
}

class NetworkPartiallyConfinedMapper
    extends SubClassMapperBase<NetworkPartiallyConfined> {
  NetworkPartiallyConfinedMapper._();

  static NetworkPartiallyConfinedMapper? _instance;
  static NetworkPartiallyConfinedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = NetworkPartiallyConfinedMapper._(),
      );
      NetworkEnforcementMapper.ensureInitialized().addSubMapper(_instance!);
      NetworkTierMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NetworkPartiallyConfined';

  static NetworkTier _$requested(NetworkPartiallyConfined v) => v.requested;
  static const Field<NetworkPartiallyConfined, NetworkTier> _f$requested =
      Field('requested', _$requested);
  static String _$unavailable(NetworkPartiallyConfined v) => v.unavailable;
  static const Field<NetworkPartiallyConfined, String> _f$unavailable = Field(
    'unavailable',
    _$unavailable,
  );
  static String _$reason(NetworkPartiallyConfined v) => v.reason;
  static const Field<NetworkPartiallyConfined, String> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<NetworkPartiallyConfined> fields = const {
    #requested: _f$requested,
    #unavailable: _f$unavailable,
    #reason: _f$reason,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'partial';
  @override
  late final ClassMapperBase superMapper =
      NetworkEnforcementMapper.ensureInitialized();

  static NetworkPartiallyConfined _instantiate(DecodingData data) {
    return NetworkPartiallyConfined(
      data.dec(_f$requested),
      data.dec(_f$unavailable),
      data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NetworkPartiallyConfined fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NetworkPartiallyConfined>(map);
  }

  static NetworkPartiallyConfined fromJson(String json) {
    return ensureInitialized().decodeJson<NetworkPartiallyConfined>(json);
  }
}

mixin NetworkPartiallyConfinedMappable {
  String toJson() {
    return NetworkPartiallyConfinedMapper.ensureInitialized()
        .encodeJson<NetworkPartiallyConfined>(this as NetworkPartiallyConfined);
  }

  Map<String, dynamic> toMap() {
    return NetworkPartiallyConfinedMapper.ensureInitialized()
        .encodeMap<NetworkPartiallyConfined>(this as NetworkPartiallyConfined);
  }

  NetworkPartiallyConfinedCopyWith<
    NetworkPartiallyConfined,
    NetworkPartiallyConfined,
    NetworkPartiallyConfined
  >
  get copyWith =>
      _NetworkPartiallyConfinedCopyWithImpl<
        NetworkPartiallyConfined,
        NetworkPartiallyConfined
      >(this as NetworkPartiallyConfined, $identity, $identity);
  @override
  String toString() {
    return NetworkPartiallyConfinedMapper.ensureInitialized().stringifyValue(
      this as NetworkPartiallyConfined,
    );
  }

  @override
  bool operator ==(Object other) {
    return NetworkPartiallyConfinedMapper.ensureInitialized().equalsValue(
      this as NetworkPartiallyConfined,
      other,
    );
  }

  @override
  int get hashCode {
    return NetworkPartiallyConfinedMapper.ensureInitialized().hashValue(
      this as NetworkPartiallyConfined,
    );
  }
}

extension NetworkPartiallyConfinedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NetworkPartiallyConfined, $Out> {
  NetworkPartiallyConfinedCopyWith<$R, NetworkPartiallyConfined, $Out>
  get $asNetworkPartiallyConfined => $base.as(
    (v, t, t2) => _NetworkPartiallyConfinedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class NetworkPartiallyConfinedCopyWith<
  $R,
  $In extends NetworkPartiallyConfined,
  $Out
>
    implements NetworkEnforcementCopyWith<$R, $In, $Out> {
  @override
  $R call({NetworkTier? requested, String? unavailable, String? reason});
  NetworkPartiallyConfinedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _NetworkPartiallyConfinedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NetworkPartiallyConfined, $Out>
    implements
        NetworkPartiallyConfinedCopyWith<$R, NetworkPartiallyConfined, $Out> {
  _NetworkPartiallyConfinedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NetworkPartiallyConfined> $mapper =
      NetworkPartiallyConfinedMapper.ensureInitialized();
  @override
  $R call({NetworkTier? requested, String? unavailable, String? reason}) =>
      $apply(
        FieldCopyWithData({
          if (requested != null) #requested: requested,
          if (unavailable != null) #unavailable: unavailable,
          if (reason != null) #reason: reason,
        }),
      );
  @override
  NetworkPartiallyConfined $make(CopyWithData data) => NetworkPartiallyConfined(
    data.get(#requested, or: $value.requested),
    data.get(#unavailable, or: $value.unavailable),
    data.get(#reason, or: $value.reason),
  );

  @override
  NetworkPartiallyConfinedCopyWith<$R2, NetworkPartiallyConfined, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _NetworkPartiallyConfinedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SandboxEnforcementMapper extends ClassMapperBase<SandboxEnforcement> {
  SandboxEnforcementMapper._();

  static SandboxEnforcementMapper? _instance;
  static SandboxEnforcementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxEnforcementMapper._());
      SandboxCapabilityMapper.ensureInitialized();
      NetworkEnforcementMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxEnforcement';

  static Set<SandboxCapability> _$enforced(SandboxEnforcement v) => v.enforced;
  static const Field<SandboxEnforcement, Set<SandboxCapability>> _f$enforced =
      Field('enforced', _$enforced);
  static NetworkEnforcement _$network(SandboxEnforcement v) => v.network;
  static const Field<SandboxEnforcement, NetworkEnforcement> _f$network = Field(
    'network',
    _$network,
  );
  static String _$backend(SandboxEnforcement v) => v.backend;
  static const Field<SandboxEnforcement, String> _f$backend = Field(
    'backend',
    _$backend,
  );
  static List<String> _$readableRoots(SandboxEnforcement v) => v.readableRoots;
  static const Field<SandboxEnforcement, List<String>> _f$readableRoots = Field(
    'readableRoots',
    _$readableRoots,
    opt: true,
    def: const [],
  );
  static List<String> _$deniedReads(SandboxEnforcement v) => v.deniedReads;
  static const Field<SandboxEnforcement, List<String>> _f$deniedReads = Field(
    'deniedReads',
    _$deniedReads,
    opt: true,
    def: const [],
  );
  static List<String> _$writableRoots(SandboxEnforcement v) => v.writableRoots;
  static const Field<SandboxEnforcement, List<String>> _f$writableRoots = Field(
    'writableRoots',
    _$writableRoots,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<SandboxEnforcement> fields = const {
    #enforced: _f$enforced,
    #network: _f$network,
    #backend: _f$backend,
    #readableRoots: _f$readableRoots,
    #deniedReads: _f$deniedReads,
    #writableRoots: _f$writableRoots,
  };

  static SandboxEnforcement _instantiate(DecodingData data) {
    return SandboxEnforcement(
      enforced: data.dec(_f$enforced),
      network: data.dec(_f$network),
      backend: data.dec(_f$backend),
      readableRoots: data.dec(_f$readableRoots),
      deniedReads: data.dec(_f$deniedReads),
      writableRoots: data.dec(_f$writableRoots),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxEnforcement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxEnforcement>(map);
  }

  static SandboxEnforcement fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxEnforcement>(json);
  }
}

mixin SandboxEnforcementMappable {
  String toJson() {
    return SandboxEnforcementMapper.ensureInitialized()
        .encodeJson<SandboxEnforcement>(this as SandboxEnforcement);
  }

  Map<String, dynamic> toMap() {
    return SandboxEnforcementMapper.ensureInitialized()
        .encodeMap<SandboxEnforcement>(this as SandboxEnforcement);
  }

  SandboxEnforcementCopyWith<
    SandboxEnforcement,
    SandboxEnforcement,
    SandboxEnforcement
  >
  get copyWith =>
      _SandboxEnforcementCopyWithImpl<SandboxEnforcement, SandboxEnforcement>(
        this as SandboxEnforcement,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SandboxEnforcementMapper.ensureInitialized().stringifyValue(
      this as SandboxEnforcement,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxEnforcementMapper.ensureInitialized().equalsValue(
      this as SandboxEnforcement,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxEnforcementMapper.ensureInitialized().hashValue(
      this as SandboxEnforcement,
    );
  }
}

extension SandboxEnforcementValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxEnforcement, $Out> {
  SandboxEnforcementCopyWith<$R, SandboxEnforcement, $Out>
  get $asSandboxEnforcement => $base.as(
    (v, t, t2) => _SandboxEnforcementCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SandboxEnforcementCopyWith<
  $R,
  $In extends SandboxEnforcement,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  NetworkEnforcementCopyWith<$R, NetworkEnforcement, NetworkEnforcement>
  get network;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get readableRoots;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get deniedReads;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get writableRoots;
  $R call({
    Set<SandboxCapability>? enforced,
    NetworkEnforcement? network,
    String? backend,
    List<String>? readableRoots,
    List<String>? deniedReads,
    List<String>? writableRoots,
  });
  SandboxEnforcementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SandboxEnforcementCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxEnforcement, $Out>
    implements SandboxEnforcementCopyWith<$R, SandboxEnforcement, $Out> {
  _SandboxEnforcementCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxEnforcement> $mapper =
      SandboxEnforcementMapper.ensureInitialized();
  @override
  NetworkEnforcementCopyWith<$R, NetworkEnforcement, NetworkEnforcement>
  get network => $value.network.copyWith.$chain((v) => call(network: v));
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get readableRoots => ListCopyWith(
    $value.readableRoots,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(readableRoots: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get deniedReads => ListCopyWith(
    $value.deniedReads,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(deniedReads: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get writableRoots => ListCopyWith(
    $value.writableRoots,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(writableRoots: v),
  );
  @override
  $R call({
    Set<SandboxCapability>? enforced,
    NetworkEnforcement? network,
    String? backend,
    List<String>? readableRoots,
    List<String>? deniedReads,
    List<String>? writableRoots,
  }) => $apply(
    FieldCopyWithData({
      if (enforced != null) #enforced: enforced,
      if (network != null) #network: network,
      if (backend != null) #backend: backend,
      if (readableRoots != null) #readableRoots: readableRoots,
      if (deniedReads != null) #deniedReads: deniedReads,
      if (writableRoots != null) #writableRoots: writableRoots,
    }),
  );
  @override
  SandboxEnforcement $make(CopyWithData data) => SandboxEnforcement(
    enforced: data.get(#enforced, or: $value.enforced),
    network: data.get(#network, or: $value.network),
    backend: data.get(#backend, or: $value.backend),
    readableRoots: data.get(#readableRoots, or: $value.readableRoots),
    deniedReads: data.get(#deniedReads, or: $value.deniedReads),
    writableRoots: data.get(#writableRoots, or: $value.writableRoots),
  );

  @override
  SandboxEnforcementCopyWith<$R2, SandboxEnforcement, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SandboxEnforcementCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

