// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'sampling_options.dart';

class SamplingOptionsMapper extends ClassMapperBase<SamplingOptions> {
  SamplingOptionsMapper._();

  static SamplingOptionsMapper? _instance;
  static SamplingOptionsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SamplingOptionsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SamplingOptions';

  static int _$seed(SamplingOptions v) => v.seed;
  static const Field<SamplingOptions, int> _f$seed = Field('seed', _$seed);
  static int? _$topK(SamplingOptions v) => v.topK;
  static const Field<SamplingOptions, int> _f$topK = Field(
    'topK',
    _$topK,
    opt: true,
  );
  static double? _$topP(SamplingOptions v) => v.topP;
  static const Field<SamplingOptions, double> _f$topP = Field(
    'topP',
    _$topP,
    opt: true,
  );
  static double? _$minP(SamplingOptions v) => v.minP;
  static const Field<SamplingOptions, double> _f$minP = Field(
    'minP',
    _$minP,
    opt: true,
  );
  static double? _$temperature(SamplingOptions v) => v.temperature;
  static const Field<SamplingOptions, double> _f$temperature = Field(
    'temperature',
    _$temperature,
    opt: true,
  );
  static double? _$typicalP(SamplingOptions v) => v.typicalP;
  static const Field<SamplingOptions, double> _f$typicalP = Field(
    'typicalP',
    _$typicalP,
    opt: true,
  );
  static double? _$penaltyRepeat(SamplingOptions v) => v.penaltyRepeat;
  static const Field<SamplingOptions, double> _f$penaltyRepeat = Field(
    'penaltyRepeat',
    _$penaltyRepeat,
    opt: true,
  );
  static int? _$penaltyLastN(SamplingOptions v) => v.penaltyLastN;
  static const Field<SamplingOptions, int> _f$penaltyLastN = Field(
    'penaltyLastN',
    _$penaltyLastN,
    opt: true,
  );
  static double? _$penaltyFreq(SamplingOptions v) => v.penaltyFreq;
  static const Field<SamplingOptions, double> _f$penaltyFreq = Field(
    'penaltyFreq',
    _$penaltyFreq,
    opt: true,
  );
  static double? _$penaltyPresent(SamplingOptions v) => v.penaltyPresent;
  static const Field<SamplingOptions, double> _f$penaltyPresent = Field(
    'penaltyPresent',
    _$penaltyPresent,
    opt: true,
  );

  @override
  final MappableFields<SamplingOptions> fields = const {
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

  static SamplingOptions _instantiate(DecodingData data) {
    return SamplingOptions(
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

  static SamplingOptions fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SamplingOptions>(map);
  }

  static SamplingOptions fromJson(String json) {
    return ensureInitialized().decodeJson<SamplingOptions>(json);
  }
}

mixin SamplingOptionsMappable {
  String toJson() {
    return SamplingOptionsMapper.ensureInitialized()
        .encodeJson<SamplingOptions>(this as SamplingOptions);
  }

  Map<String, dynamic> toMap() {
    return SamplingOptionsMapper.ensureInitialized().encodeMap<SamplingOptions>(
      this as SamplingOptions,
    );
  }

  SamplingOptionsCopyWith<SamplingOptions, SamplingOptions, SamplingOptions>
  get copyWith =>
      _SamplingOptionsCopyWithImpl<SamplingOptions, SamplingOptions>(
        this as SamplingOptions,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SamplingOptionsMapper.ensureInitialized().stringifyValue(
      this as SamplingOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    return SamplingOptionsMapper.ensureInitialized().equalsValue(
      this as SamplingOptions,
      other,
    );
  }

  @override
  int get hashCode {
    return SamplingOptionsMapper.ensureInitialized().hashValue(
      this as SamplingOptions,
    );
  }
}

extension SamplingOptionsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SamplingOptions, $Out> {
  SamplingOptionsCopyWith<$R, SamplingOptions, $Out> get $asSamplingOptions =>
      $base.as((v, t, t2) => _SamplingOptionsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SamplingOptionsCopyWith<$R, $In extends SamplingOptions, $Out>
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
  SamplingOptionsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SamplingOptionsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SamplingOptions, $Out>
    implements SamplingOptionsCopyWith<$R, SamplingOptions, $Out> {
  _SamplingOptionsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SamplingOptions> $mapper =
      SamplingOptionsMapper.ensureInitialized();
  @override
  $R call({
    int? seed,
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
      if (seed != null) #seed: seed,
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
  SamplingOptions $make(CopyWithData data) => SamplingOptions(
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
  SamplingOptionsCopyWith<$R2, SamplingOptions, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SamplingOptionsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

