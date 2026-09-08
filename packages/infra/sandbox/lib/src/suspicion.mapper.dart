// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'suspicion.dart';

class SandboxDimensionMapper extends EnumMapper<SandboxDimension> {
  SandboxDimensionMapper._();

  static SandboxDimensionMapper? _instance;
  static SandboxDimensionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxDimensionMapper._());
    }
    return _instance!;
  }

  static SandboxDimension fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  SandboxDimension decode(dynamic value) {
    switch (value) {
      case r'filesystemRead':
        return SandboxDimension.filesystemRead;
      case r'filesystemWrite':
        return SandboxDimension.filesystemWrite;
      case r'network':
        return SandboxDimension.network;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(SandboxDimension self) {
    switch (self) {
      case SandboxDimension.filesystemRead:
        return r'filesystemRead';
      case SandboxDimension.filesystemWrite:
        return r'filesystemWrite';
      case SandboxDimension.network:
        return r'network';
    }
  }
}

extension SandboxDimensionMapperExtension on SandboxDimension {
  String toValue() {
    SandboxDimensionMapper.ensureInitialized();
    return MapperContainer.globals.toValue<SandboxDimension>(this) as String;
  }
}

class SandboxSuspicionMapper extends ClassMapperBase<SandboxSuspicion> {
  SandboxSuspicionMapper._();

  static SandboxSuspicionMapper? _instance;
  static SandboxSuspicionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SandboxSuspicionMapper._());
      SandboxDimensionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SandboxSuspicion';

  static SandboxDimension _$dimension(SandboxSuspicion v) => v.dimension;
  static const Field<SandboxSuspicion, SandboxDimension> _f$dimension = Field(
    'dimension',
    _$dimension,
  );
  static List<String> _$evidence(SandboxSuspicion v) => v.evidence;
  static const Field<SandboxSuspicion, List<String>> _f$evidence = Field(
    'evidence',
    _$evidence,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<SandboxSuspicion> fields = const {
    #dimension: _f$dimension,
    #evidence: _f$evidence,
  };

  static SandboxSuspicion _instantiate(DecodingData data) {
    return SandboxSuspicion(
      dimension: data.dec(_f$dimension),
      evidence: data.dec(_f$evidence),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SandboxSuspicion fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SandboxSuspicion>(map);
  }

  static SandboxSuspicion fromJson(String json) {
    return ensureInitialized().decodeJson<SandboxSuspicion>(json);
  }
}

mixin SandboxSuspicionMappable {
  String toJson() {
    return SandboxSuspicionMapper.ensureInitialized()
        .encodeJson<SandboxSuspicion>(this as SandboxSuspicion);
  }

  Map<String, dynamic> toMap() {
    return SandboxSuspicionMapper.ensureInitialized()
        .encodeMap<SandboxSuspicion>(this as SandboxSuspicion);
  }

  SandboxSuspicionCopyWith<SandboxSuspicion, SandboxSuspicion, SandboxSuspicion>
  get copyWith =>
      _SandboxSuspicionCopyWithImpl<SandboxSuspicion, SandboxSuspicion>(
        this as SandboxSuspicion,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SandboxSuspicionMapper.ensureInitialized().stringifyValue(
      this as SandboxSuspicion,
    );
  }

  @override
  bool operator ==(Object other) {
    return SandboxSuspicionMapper.ensureInitialized().equalsValue(
      this as SandboxSuspicion,
      other,
    );
  }

  @override
  int get hashCode {
    return SandboxSuspicionMapper.ensureInitialized().hashValue(
      this as SandboxSuspicion,
    );
  }
}

extension SandboxSuspicionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SandboxSuspicion, $Out> {
  SandboxSuspicionCopyWith<$R, SandboxSuspicion, $Out>
  get $asSandboxSuspicion =>
      $base.as((v, t, t2) => _SandboxSuspicionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SandboxSuspicionCopyWith<$R, $In extends SandboxSuspicion, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get evidence;
  $R call({SandboxDimension? dimension, List<String>? evidence});
  SandboxSuspicionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SandboxSuspicionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SandboxSuspicion, $Out>
    implements SandboxSuspicionCopyWith<$R, SandboxSuspicion, $Out> {
  _SandboxSuspicionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SandboxSuspicion> $mapper =
      SandboxSuspicionMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get evidence =>
      ListCopyWith(
        $value.evidence,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(evidence: v),
      );
  @override
  $R call({SandboxDimension? dimension, List<String>? evidence}) => $apply(
    FieldCopyWithData({
      if (dimension != null) #dimension: dimension,
      if (evidence != null) #evidence: evidence,
    }),
  );
  @override
  SandboxSuspicion $make(CopyWithData data) => SandboxSuspicion(
    dimension: data.get(#dimension, or: $value.dimension),
    evidence: data.get(#evidence, or: $value.evidence),
  );

  @override
  SandboxSuspicionCopyWith<$R2, SandboxSuspicion, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SandboxSuspicionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

