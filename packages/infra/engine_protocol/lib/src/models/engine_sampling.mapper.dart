// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'engine_sampling.dart';

class EngineSamplingMapper extends ClassMapperBase<EngineSampling> {
  EngineSamplingMapper._();

  static EngineSamplingMapper? _instance;
  static EngineSamplingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EngineSamplingMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'EngineSampling';

  static int? _$seed(EngineSampling v) => v.seed;
  static const Field<EngineSampling, int> _f$seed = Field(
    'seed',
    _$seed,
    opt: true,
  );
  static int? _$topK(EngineSampling v) => v.topK;
  static const Field<EngineSampling, int> _f$topK = Field(
    'topK',
    _$topK,
    opt: true,
  );
  static double? _$topP(EngineSampling v) => v.topP;
  static const Field<EngineSampling, double> _f$topP = Field(
    'topP',
    _$topP,
    opt: true,
  );
  static double? _$minP(EngineSampling v) => v.minP;
  static const Field<EngineSampling, double> _f$minP = Field(
    'minP',
    _$minP,
    opt: true,
  );
  static double? _$temperature(EngineSampling v) => v.temperature;
  static const Field<EngineSampling, double> _f$temperature = Field(
    'temperature',
    _$temperature,
    opt: true,
  );
  static double? _$typicalP(EngineSampling v) => v.typicalP;
  static const Field<EngineSampling, double> _f$typicalP = Field(
    'typicalP',
    _$typicalP,
    opt: true,
  );
  static double? _$penaltyRepeat(EngineSampling v) => v.penaltyRepeat;
  static const Field<EngineSampling, double> _f$penaltyRepeat = Field(
    'penaltyRepeat',
    _$penaltyRepeat,
    opt: true,
  );
  static int? _$penaltyLastN(EngineSampling v) => v.penaltyLastN;
  static const Field<EngineSampling, int> _f$penaltyLastN = Field(
    'penaltyLastN',
    _$penaltyLastN,
    opt: true,
  );
  static double? _$penaltyFreq(EngineSampling v) => v.penaltyFreq;
  static const Field<EngineSampling, double> _f$penaltyFreq = Field(
    'penaltyFreq',
    _$penaltyFreq,
    opt: true,
  );
  static double? _$penaltyPresent(EngineSampling v) => v.penaltyPresent;
  static const Field<EngineSampling, double> _f$penaltyPresent = Field(
    'penaltyPresent',
    _$penaltyPresent,
    opt: true,
  );

  @override
  final MappableFields<EngineSampling> fields = const {
    #seed: _f$seed,
    #topK: _f$topK,
    #topP: _f$topP,
    #minP: _f$minP,
    #temperature: _f$temperature,
    #typicalP: _f$typicalP,
    #penaltyRepeat: _f$penaltyRepeat,
    #penaltyLastN: _f$penaltyLastN,
    #penaltyFreq: _f$penaltyFreq,
    #penaltyPresent: _f$penaltyPresent,
  };

  static EngineSampling _instantiate(DecodingData data) {
    return EngineSampling(
      seed: data.dec(_f$seed),
      topK: data.dec(_f$topK),
      topP: data.dec(_f$topP),
      minP: data.dec(_f$minP),
      temperature: data.dec(_f$temperature),
      typicalP: data.dec(_f$typicalP),
      penaltyRepeat: data.dec(_f$penaltyRepeat),
      penaltyLastN: data.dec(_f$penaltyLastN),
      penaltyFreq: data.dec(_f$penaltyFreq),
      penaltyPresent: data.dec(_f$penaltyPresent),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EngineSampling fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EngineSampling>(map);
  }

  static EngineSampling fromJson(String json) {
    return ensureInitialized().decodeJson<EngineSampling>(json);
  }
}

mixin EngineSamplingMappable {
  String toJson() {
    return EngineSamplingMapper.ensureInitialized().encodeJson<EngineSampling>(
      this as EngineSampling,
    );
  }

  Map<String, dynamic> toMap() {
    return EngineSamplingMapper.ensureInitialized().encodeMap<EngineSampling>(
      this as EngineSampling,
    );
  }

  EngineSamplingCopyWith<EngineSampling, EngineSampling, EngineSampling>
  get copyWith => _EngineSamplingCopyWithImpl<EngineSampling, EngineSampling>(
    this as EngineSampling,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return EngineSamplingMapper.ensureInitialized().stringifyValue(
      this as EngineSampling,
    );
  }

  @override
  bool operator ==(Object other) {
    return EngineSamplingMapper.ensureInitialized().equalsValue(
      this as EngineSampling,
      other,
    );
  }

  @override
  int get hashCode {
    return EngineSamplingMapper.ensureInitialized().hashValue(
      this as EngineSampling,
    );
  }
}

extension EngineSamplingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EngineSampling, $Out> {
  EngineSamplingCopyWith<$R, EngineSampling, $Out> get $asEngineSampling =>
      $base.as((v, t, t2) => _EngineSamplingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EngineSamplingCopyWith<$R, $In extends EngineSampling, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? seed,
    int? topK,
    double? topP,
    double? minP,
    double? temperature,
    double? typicalP,
    double? penaltyRepeat,
    int? penaltyLastN,
    double? penaltyFreq,
    double? penaltyPresent,
  });
  EngineSamplingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EngineSamplingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EngineSampling, $Out>
    implements EngineSamplingCopyWith<$R, EngineSampling, $Out> {
  _EngineSamplingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EngineSampling> $mapper =
      EngineSamplingMapper.ensureInitialized();
  @override
  $R call({
    Object? seed = $none,
    Object? topK = $none,
    Object? topP = $none,
    Object? minP = $none,
    Object? temperature = $none,
    Object? typicalP = $none,
    Object? penaltyRepeat = $none,
    Object? penaltyLastN = $none,
    Object? penaltyFreq = $none,
    Object? penaltyPresent = $none,
  }) => $apply(
    FieldCopyWithData({
      if (seed != $none) #seed: seed,
      if (topK != $none) #topK: topK,
      if (topP != $none) #topP: topP,
      if (minP != $none) #minP: minP,
      if (temperature != $none) #temperature: temperature,
      if (typicalP != $none) #typicalP: typicalP,
      if (penaltyRepeat != $none) #penaltyRepeat: penaltyRepeat,
      if (penaltyLastN != $none) #penaltyLastN: penaltyLastN,
      if (penaltyFreq != $none) #penaltyFreq: penaltyFreq,
      if (penaltyPresent != $none) #penaltyPresent: penaltyPresent,
    }),
  );
  @override
  EngineSampling $make(CopyWithData data) => EngineSampling(
    seed: data.get(#seed, or: $value.seed),
    topK: data.get(#topK, or: $value.topK),
    topP: data.get(#topP, or: $value.topP),
    minP: data.get(#minP, or: $value.minP),
    temperature: data.get(#temperature, or: $value.temperature),
    typicalP: data.get(#typicalP, or: $value.typicalP),
    penaltyRepeat: data.get(#penaltyRepeat, or: $value.penaltyRepeat),
    penaltyLastN: data.get(#penaltyLastN, or: $value.penaltyLastN),
    penaltyFreq: data.get(#penaltyFreq, or: $value.penaltyFreq),
    penaltyPresent: data.get(#penaltyPresent, or: $value.penaltyPresent),
  );

  @override
  EngineSamplingCopyWith<$R2, EngineSampling, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EngineSamplingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

