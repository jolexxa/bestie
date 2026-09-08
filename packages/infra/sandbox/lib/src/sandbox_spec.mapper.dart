// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sandbox_spec.dart';

class NetworkTierMapper extends EnumMapper<NetworkTier> {
  NetworkTierMapper._();

  static NetworkTierMapper? _instance;
  static NetworkTierMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NetworkTierMapper._());
    }
    return _instance!;
  }

  static NetworkTier fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  NetworkTier decode(dynamic value) {
    switch (value) {
      case r'none':
        return NetworkTier.none;
      case r'local':
        return NetworkTier.local;
      case r'all':
        return NetworkTier.all;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(NetworkTier self) {
    switch (self) {
      case NetworkTier.none:
        return r'none';
      case NetworkTier.local:
        return r'local';
      case NetworkTier.all:
        return r'all';
    }
  }
}

extension NetworkTierMapperExtension on NetworkTier {
  String toValue() {
    NetworkTierMapper.ensureInitialized();
    return MapperContainer.globals.toValue<NetworkTier>(this) as String;
  }
}

class SandboxSpecMapper extends ClassMapperBase<SandboxSpec> {
  SandboxSpecMapper._();

  static SandboxSpecMapper? _instance;
  static SandboxSpecMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxSpecMapper._());
      NetworkTierMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxSpec';

  static String _$workspaceRoot(SandboxSpec v) => v.workspaceRoot;
  static const Field<SandboxSpec, String> _f$workspaceRoot = Field(
    'workspaceRoot',
    _$workspaceRoot,
  );
  static List<String> _$readableRoots(SandboxSpec v) => v.readableRoots;
  static const Field<SandboxSpec, List<String>> _f$readableRoots = Field(
    'readableRoots',
    _$readableRoots,
    opt: true,
    def: const [],
  );
  static List<String> _$deniedReads(SandboxSpec v) => v.deniedReads;
  static const Field<SandboxSpec, List<String>> _f$deniedReads = Field(
    'deniedReads',
    _$deniedReads,
    opt: true,
    def: const [],
  );
  static List<String> _$writableRoots(SandboxSpec v) => v.writableRoots;
  static const Field<SandboxSpec, List<String>> _f$writableRoots = Field(
    'writableRoots',
    _$writableRoots,
    opt: true,
    def: const [],
  );
  static NetworkTier _$network(SandboxSpec v) => v.network;
  static const Field<SandboxSpec, NetworkTier> _f$network = Field(
    'network',
    _$network,
    opt: true,
    def: NetworkTier.all,
  );

  @override
  final MappableFields<SandboxSpec> fields = const {
    #workspaceRoot: _f$workspaceRoot,
    #readableRoots: _f$readableRoots,
    #deniedReads: _f$deniedReads,
    #writableRoots: _f$writableRoots,
    #network: _f$network,
  };

  static SandboxSpec _instantiate(DecodingData data) {
    return SandboxSpec(
      workspaceRoot: data.dec(_f$workspaceRoot),
      readableRoots: data.dec(_f$readableRoots),
      deniedReads: data.dec(_f$deniedReads),
      writableRoots: data.dec(_f$writableRoots),
      network: data.dec(_f$network),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxSpec fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxSpec>(map);
  }

  static SandboxSpec fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxSpec>(json);
  }
}

mixin SandboxSpecMappable {
  String toJson() {
    return SandboxSpecMapper.ensureInitialized().encodeJson<SandboxSpec>(
      this as SandboxSpec,
    );
  }

  Map<String, dynamic> toMap() {
    return SandboxSpecMapper.ensureInitialized().encodeMap<SandboxSpec>(
      this as SandboxSpec,
    );
  }

  SandboxSpecCopyWith<SandboxSpec, SandboxSpec, SandboxSpec> get copyWith =>
      _SandboxSpecCopyWithImpl<SandboxSpec, SandboxSpec>(
        this as SandboxSpec,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SandboxSpecMapper.ensureInitialized().stringifyValue(
      this as SandboxSpec,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxSpecMapper.ensureInitialized().equalsValue(
      this as SandboxSpec,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxSpecMapper.ensureInitialized().hashValue(this as SandboxSpec);
  }
}

extension SandboxSpecValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxSpec, $Out> {
  SandboxSpecCopyWith<$R, SandboxSpec, $Out> get $asSandboxSpec =>
      $base.as((v, t, t2) => _SandboxSpecCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SandboxSpecCopyWith<$R, $In extends SandboxSpec, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get readableRoots;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get deniedReads;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get writableRoots;
  $R call({
    String? workspaceRoot,
    List<String>? readableRoots,
    List<String>? deniedReads,
    List<String>? writableRoots,
    NetworkTier? network,
  });
  SandboxSpecCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SandboxSpecCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxSpec, $Out>
    implements SandboxSpecCopyWith<$R, SandboxSpec, $Out> {
  _SandboxSpecCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxSpec> $mapper =
      SandboxSpecMapper.ensureInitialized();
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
    String? workspaceRoot,
    List<String>? readableRoots,
    List<String>? deniedReads,
    List<String>? writableRoots,
    NetworkTier? network,
  }) => $apply(
    FieldCopyWithData({
      if (workspaceRoot != null) #workspaceRoot: workspaceRoot,
      if (readableRoots != null) #readableRoots: readableRoots,
      if (deniedReads != null) #deniedReads: deniedReads,
      if (writableRoots != null) #writableRoots: writableRoots,
      if (network != null) #network: network,
    }),
  );
  @override
  SandboxSpec $make(CopyWithData data) => SandboxSpec(
    workspaceRoot: data.get(#workspaceRoot, or: $value.workspaceRoot),
    readableRoots: data.get(#readableRoots, or: $value.readableRoots),
    deniedReads: data.get(#deniedReads, or: $value.deniedReads),
    writableRoots: data.get(#writableRoots, or: $value.writableRoots),
    network: data.get(#network, or: $value.network),
  );

  @override
  SandboxSpecCopyWith<$R2, SandboxSpec, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SandboxSpecCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

