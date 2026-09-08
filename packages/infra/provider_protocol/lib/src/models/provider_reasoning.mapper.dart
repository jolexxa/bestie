// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_reasoning.dart';

class ProviderReasoningMapper extends ClassMapperBase<ProviderReasoning> {
  ProviderReasoningMapper._();

  static ProviderReasoningMapper? _instance;
  static ProviderReasoningMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderReasoningMapper._());
      ProviderReasoningFixedMapper.ensureInitialized();
      ProviderReasoningToggleMapper.ensureInitialized();
      ProviderReasoningEffortsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderReasoning';

  @override
  final MappableFields<ProviderReasoning> fields = const {};

  static ProviderReasoning _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ProviderReasoning',
      'kind',
      '${data.value['kind']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderReasoning fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderReasoning>(map);
  }

  static ProviderReasoning fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderReasoning>(json);
  }
}

mixin ProviderReasoningMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ProviderReasoningCopyWith<
    ProviderReasoning,
    ProviderReasoning,
    ProviderReasoning
  >
  get copyWith;
}

abstract class ProviderReasoningCopyWith<
  $R,
  $In extends ProviderReasoning,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ProviderReasoningCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class ProviderReasoningFixedMapper
    extends SubClassMapperBase<ProviderReasoningFixed> {
  ProviderReasoningFixedMapper._();

  static ProviderReasoningFixedMapper? _instance;
  static ProviderReasoningFixedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderReasoningFixedMapper._());
      ProviderReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderReasoningFixed';

  @override
  final MappableFields<ProviderReasoningFixed> fields = const {};

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'fixed';
  @override
  late final ClassMapperBase superMapper =
      ProviderReasoningMapper.ensureInitialized();

  static ProviderReasoningFixed _instantiate(DecodingData data) {
    return ProviderReasoningFixed();
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderReasoningFixed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderReasoningFixed>(map);
  }

  static ProviderReasoningFixed fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderReasoningFixed>(json);
  }
}

mixin ProviderReasoningFixedMappable {
  String toJson() {
    return ProviderReasoningFixedMapper.ensureInitialized()
        .encodeJson<ProviderReasoningFixed>(this as ProviderReasoningFixed);
  }

  Map<String, dynamic> toMap() {
    return ProviderReasoningFixedMapper.ensureInitialized()
        .encodeMap<ProviderReasoningFixed>(this as ProviderReasoningFixed);
  }

  ProviderReasoningFixedCopyWith<
    ProviderReasoningFixed,
    ProviderReasoningFixed,
    ProviderReasoningFixed
  >
  get copyWith =>
      _ProviderReasoningFixedCopyWithImpl<
        ProviderReasoningFixed,
        ProviderReasoningFixed
      >(this as ProviderReasoningFixed, $identity, $identity);
  @override
  String toString() {
    return ProviderReasoningFixedMapper.ensureInitialized().stringifyValue(
      this as ProviderReasoningFixed,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderReasoningFixedMapper.ensureInitialized().equalsValue(
      this as ProviderReasoningFixed,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderReasoningFixedMapper.ensureInitialized().hashValue(
      this as ProviderReasoningFixed,
    );
  }
}

extension ProviderReasoningFixedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderReasoningFixed, $Out> {
  ProviderReasoningFixedCopyWith<$R, ProviderReasoningFixed, $Out>
  get $asProviderReasoningFixed => $base.as(
    (v, t, t2) => _ProviderReasoningFixedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProviderReasoningFixedCopyWith<
  $R,
  $In extends ProviderReasoningFixed,
  $Out
>
    implements ProviderReasoningCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ProviderReasoningFixedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderReasoningFixedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderReasoningFixed, $Out>
    implements
        ProviderReasoningFixedCopyWith<$R, ProviderReasoningFixed, $Out> {
  _ProviderReasoningFixedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderReasoningFixed> $mapper =
      ProviderReasoningFixedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ProviderReasoningFixed $make(CopyWithData data) => ProviderReasoningFixed();

  @override
  ProviderReasoningFixedCopyWith<$R2, ProviderReasoningFixed, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProviderReasoningFixedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ProviderReasoningToggleMapper
    extends SubClassMapperBase<ProviderReasoningToggle> {
  ProviderReasoningToggleMapper._();

  static ProviderReasoningToggleMapper? _instance;
  static ProviderReasoningToggleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ProviderReasoningToggleMapper._(),
      );
      ProviderReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderReasoningToggle';

  static bool? _$enabledByDefault(ProviderReasoningToggle v) =>
      v.enabledByDefault;
  static const Field<ProviderReasoningToggle, bool> _f$enabledByDefault = Field(
    'enabledByDefault',
    _$enabledByDefault,
    opt: true,
  );

  @override
  final MappableFields<ProviderReasoningToggle> fields = const {
    #enabledByDefault: _f$enabledByDefault,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'toggle';
  @override
  late final ClassMapperBase superMapper =
      ProviderReasoningMapper.ensureInitialized();

  static ProviderReasoningToggle _instantiate(DecodingData data) {
    return ProviderReasoningToggle(
      enabledByDefault: data.dec(_f$enabledByDefault),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderReasoningToggle fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderReasoningToggle>(map);
  }

  static ProviderReasoningToggle fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderReasoningToggle>(json);
  }
}

mixin ProviderReasoningToggleMappable {
  String toJson() {
    return ProviderReasoningToggleMapper.ensureInitialized()
        .encodeJson<ProviderReasoningToggle>(this as ProviderReasoningToggle);
  }

  Map<String, dynamic> toMap() {
    return ProviderReasoningToggleMapper.ensureInitialized()
        .encodeMap<ProviderReasoningToggle>(this as ProviderReasoningToggle);
  }

  ProviderReasoningToggleCopyWith<
    ProviderReasoningToggle,
    ProviderReasoningToggle,
    ProviderReasoningToggle
  >
  get copyWith =>
      _ProviderReasoningToggleCopyWithImpl<
        ProviderReasoningToggle,
        ProviderReasoningToggle
      >(this as ProviderReasoningToggle, $identity, $identity);
  @override
  String toString() {
    return ProviderReasoningToggleMapper.ensureInitialized().stringifyValue(
      this as ProviderReasoningToggle,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderReasoningToggleMapper.ensureInitialized().equalsValue(
      this as ProviderReasoningToggle,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderReasoningToggleMapper.ensureInitialized().hashValue(
      this as ProviderReasoningToggle,
    );
  }
}

extension ProviderReasoningToggleValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderReasoningToggle, $Out> {
  ProviderReasoningToggleCopyWith<$R, ProviderReasoningToggle, $Out>
  get $asProviderReasoningToggle => $base.as(
    (v, t, t2) => _ProviderReasoningToggleCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProviderReasoningToggleCopyWith<
  $R,
  $In extends ProviderReasoningToggle,
  $Out
>
    implements ProviderReasoningCopyWith<$R, $In, $Out> {
  @override
  $R call({bool? enabledByDefault});
  ProviderReasoningToggleCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderReasoningToggleCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderReasoningToggle, $Out>
    implements
        ProviderReasoningToggleCopyWith<$R, ProviderReasoningToggle, $Out> {
  _ProviderReasoningToggleCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderReasoningToggle> $mapper =
      ProviderReasoningToggleMapper.ensureInitialized();
  @override
  $R call({Object? enabledByDefault = $none}) => $apply(
    FieldCopyWithData({
      if (enabledByDefault != $none) #enabledByDefault: enabledByDefault,
    }),
  );
  @override
  ProviderReasoningToggle $make(CopyWithData data) => ProviderReasoningToggle(
    enabledByDefault: data.get(#enabledByDefault, or: $value.enabledByDefault),
  );

  @override
  ProviderReasoningToggleCopyWith<$R2, ProviderReasoningToggle, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProviderReasoningToggleCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ProviderReasoningEffortsMapper
    extends SubClassMapperBase<ProviderReasoningEfforts> {
  ProviderReasoningEffortsMapper._();

  static ProviderReasoningEffortsMapper? _instance;
  static ProviderReasoningEffortsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ProviderReasoningEffortsMapper._(),
      );
      ProviderReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderReasoningEfforts';

  static List<String> _$efforts(ProviderReasoningEfforts v) => v.efforts;
  static const Field<ProviderReasoningEfforts, List<String>> _f$efforts = Field(
    'efforts',
    _$efforts,
  );
  static bool _$canDisable(ProviderReasoningEfforts v) => v.canDisable;
  static const Field<ProviderReasoningEfforts, bool> _f$canDisable = Field(
    'canDisable',
    _$canDisable,
  );
  static String? _$defaultEffort(ProviderReasoningEfforts v) => v.defaultEffort;
  static const Field<ProviderReasoningEfforts, String> _f$defaultEffort = Field(
    'defaultEffort',
    _$defaultEffort,
    opt: true,
  );

  @override
  final MappableFields<ProviderReasoningEfforts> fields = const {
    #efforts: _f$efforts,
    #canDisable: _f$canDisable,
    #defaultEffort: _f$defaultEffort,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'efforts';
  @override
  late final ClassMapperBase superMapper =
      ProviderReasoningMapper.ensureInitialized();

  static ProviderReasoningEfforts _instantiate(DecodingData data) {
    return ProviderReasoningEfforts(
      efforts: data.dec(_f$efforts),
      canDisable: data.dec(_f$canDisable),
      defaultEffort: data.dec(_f$defaultEffort),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProviderReasoningEfforts fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProviderReasoningEfforts>(map);
  }

  static ProviderReasoningEfforts fromJson(String json) {
    return ensureInitialized().decodeJson<ProviderReasoningEfforts>(json);
  }
}

mixin ProviderReasoningEffortsMappable {
  String toJson() {
    return ProviderReasoningEffortsMapper.ensureInitialized()
        .encodeJson<ProviderReasoningEfforts>(this as ProviderReasoningEfforts);
  }

  Map<String, dynamic> toMap() {
    return ProviderReasoningEffortsMapper.ensureInitialized()
        .encodeMap<ProviderReasoningEfforts>(this as ProviderReasoningEfforts);
  }

  ProviderReasoningEffortsCopyWith<
    ProviderReasoningEfforts,
    ProviderReasoningEfforts,
    ProviderReasoningEfforts
  >
  get copyWith =>
      _ProviderReasoningEffortsCopyWithImpl<
        ProviderReasoningEfforts,
        ProviderReasoningEfforts
      >(this as ProviderReasoningEfforts, $identity, $identity);
  @override
  String toString() {
    return ProviderReasoningEffortsMapper.ensureInitialized().stringifyValue(
      this as ProviderReasoningEfforts,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProviderReasoningEffortsMapper.ensureInitialized().equalsValue(
      this as ProviderReasoningEfforts,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderReasoningEffortsMapper.ensureInitialized().hashValue(
      this as ProviderReasoningEfforts,
    );
  }
}

extension ProviderReasoningEffortsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderReasoningEfforts, $Out> {
  ProviderReasoningEffortsCopyWith<$R, ProviderReasoningEfforts, $Out>
  get $asProviderReasoningEfforts => $base.as(
    (v, t, t2) => _ProviderReasoningEffortsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProviderReasoningEffortsCopyWith<
  $R,
  $In extends ProviderReasoningEfforts,
  $Out
>
    implements ProviderReasoningCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get efforts;
  @override
  $R call({List<String>? efforts, bool? canDisable, String? defaultEffort});
  ProviderReasoningEffortsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderReasoningEffortsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderReasoningEfforts, $Out>
    implements
        ProviderReasoningEffortsCopyWith<$R, ProviderReasoningEfforts, $Out> {
  _ProviderReasoningEffortsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderReasoningEfforts> $mapper =
      ProviderReasoningEffortsMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get efforts =>
      ListCopyWith(
        $value.efforts,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(efforts: v),
      );
  @override
  $R call({
    List<String>? efforts,
    bool? canDisable,
    Object? defaultEffort = $none,
  }) => $apply(
    FieldCopyWithData({
      if (efforts != null) #efforts: efforts,
      if (canDisable != null) #canDisable: canDisable,
      if (defaultEffort != $none) #defaultEffort: defaultEffort,
    }),
  );
  @override
  ProviderReasoningEfforts $make(CopyWithData data) => ProviderReasoningEfforts(
    efforts: data.get(#efforts, or: $value.efforts),
    canDisable: data.get(#canDisable, or: $value.canDisable),
    defaultEffort: data.get(#defaultEffort, or: $value.defaultEffort),
  );

  @override
  ProviderReasoningEffortsCopyWith<$R2, ProviderReasoningEfforts, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProviderReasoningEffortsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

