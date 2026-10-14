// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model_reasoning.dart';

class ModelReasoningMapper extends ClassMapperBase<ModelReasoning> {
  ModelReasoningMapper._();

  static ModelReasoningMapper? _instance;
  static ModelReasoningMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReasoningMapper._());
      ModelReasoningNoneMapper.ensureInitialized();
      ModelReasoningToggleMapper.ensureInitialized();
      ModelReasoningEffortsMapper.ensureInitialized();
      ModelReasoningAlwaysMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReasoning';

  @override
  final MappableFields<ModelReasoning> fields = const {};

  static ModelReasoning _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ModelReasoning',
      'kind',
      '${data.value['kind']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReasoning fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReasoning>(map);
  }

  static ModelReasoning fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReasoning>(json);
  }
}

mixin ModelReasoningMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ModelReasoningCopyWith<ModelReasoning, ModelReasoning, ModelReasoning>
  get copyWith;
}

abstract class ModelReasoningCopyWith<$R, $In extends ModelReasoning, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ModelReasoningCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class ModelReasoningNoneMapper extends SubClassMapperBase<ModelReasoningNone> {
  ModelReasoningNoneMapper._();

  static ModelReasoningNoneMapper? _instance;
  static ModelReasoningNoneMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReasoningNoneMapper._());
      ModelReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReasoningNone';

  @override
  final MappableFields<ModelReasoningNone> fields = const {};

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'none';
  @override
  late final ClassMapperBase superMapper =
      ModelReasoningMapper.ensureInitialized();

  static ModelReasoningNone _instantiate(DecodingData data) {
    return ModelReasoningNone();
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReasoningNone fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReasoningNone>(map);
  }

  static ModelReasoningNone fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReasoningNone>(json);
  }
}

mixin ModelReasoningNoneMappable {
  String toJson() {
    return ModelReasoningNoneMapper.ensureInitialized()
        .encodeJson<ModelReasoningNone>(this as ModelReasoningNone);
  }

  Map<String, dynamic> toMap() {
    return ModelReasoningNoneMapper.ensureInitialized()
        .encodeMap<ModelReasoningNone>(this as ModelReasoningNone);
  }

  ModelReasoningNoneCopyWith<
    ModelReasoningNone,
    ModelReasoningNone,
    ModelReasoningNone
  >
  get copyWith =>
      _ModelReasoningNoneCopyWithImpl<ModelReasoningNone, ModelReasoningNone>(
        this as ModelReasoningNone,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelReasoningNoneMapper.ensureInitialized().stringifyValue(
      this as ModelReasoningNone,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelReasoningNoneMapper.ensureInitialized().equalsValue(
      this as ModelReasoningNone,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelReasoningNoneMapper.ensureInitialized().hashValue(
      this as ModelReasoningNone,
    );
  }
}

extension ModelReasoningNoneValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelReasoningNone, $Out> {
  ModelReasoningNoneCopyWith<$R, ModelReasoningNone, $Out>
  get $asModelReasoningNone => $base.as(
    (v, t, t2) => _ModelReasoningNoneCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ModelReasoningNoneCopyWith<
  $R,
  $In extends ModelReasoningNone,
  $Out
>
    implements ModelReasoningCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ModelReasoningNoneCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelReasoningNoneCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelReasoningNone, $Out>
    implements ModelReasoningNoneCopyWith<$R, ModelReasoningNone, $Out> {
  _ModelReasoningNoneCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelReasoningNone> $mapper =
      ModelReasoningNoneMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ModelReasoningNone $make(CopyWithData data) => ModelReasoningNone();

  @override
  ModelReasoningNoneCopyWith<$R2, ModelReasoningNone, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelReasoningNoneCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelReasoningToggleMapper
    extends SubClassMapperBase<ModelReasoningToggle> {
  ModelReasoningToggleMapper._();

  static ModelReasoningToggleMapper? _instance;
  static ModelReasoningToggleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReasoningToggleMapper._());
      ModelReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReasoningToggle';

  @override
  final MappableFields<ModelReasoningToggle> fields = const {};

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'toggle';
  @override
  late final ClassMapperBase superMapper =
      ModelReasoningMapper.ensureInitialized();

  static ModelReasoningToggle _instantiate(DecodingData data) {
    return ModelReasoningToggle();
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReasoningToggle fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReasoningToggle>(map);
  }

  static ModelReasoningToggle fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReasoningToggle>(json);
  }
}

mixin ModelReasoningToggleMappable {
  String toJson() {
    return ModelReasoningToggleMapper.ensureInitialized()
        .encodeJson<ModelReasoningToggle>(this as ModelReasoningToggle);
  }

  Map<String, dynamic> toMap() {
    return ModelReasoningToggleMapper.ensureInitialized()
        .encodeMap<ModelReasoningToggle>(this as ModelReasoningToggle);
  }

  ModelReasoningToggleCopyWith<
    ModelReasoningToggle,
    ModelReasoningToggle,
    ModelReasoningToggle
  >
  get copyWith =>
      _ModelReasoningToggleCopyWithImpl<
        ModelReasoningToggle,
        ModelReasoningToggle
      >(this as ModelReasoningToggle, $identity, $identity);
  @override
  String toString() {
    return ModelReasoningToggleMapper.ensureInitialized().stringifyValue(
      this as ModelReasoningToggle,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelReasoningToggleMapper.ensureInitialized().equalsValue(
      this as ModelReasoningToggle,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelReasoningToggleMapper.ensureInitialized().hashValue(
      this as ModelReasoningToggle,
    );
  }
}

extension ModelReasoningToggleValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelReasoningToggle, $Out> {
  ModelReasoningToggleCopyWith<$R, ModelReasoningToggle, $Out>
  get $asModelReasoningToggle => $base.as(
    (v, t, t2) => _ModelReasoningToggleCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ModelReasoningToggleCopyWith<
  $R,
  $In extends ModelReasoningToggle,
  $Out
>
    implements ModelReasoningCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ModelReasoningToggleCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelReasoningToggleCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelReasoningToggle, $Out>
    implements ModelReasoningToggleCopyWith<$R, ModelReasoningToggle, $Out> {
  _ModelReasoningToggleCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelReasoningToggle> $mapper =
      ModelReasoningToggleMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ModelReasoningToggle $make(CopyWithData data) => ModelReasoningToggle();

  @override
  ModelReasoningToggleCopyWith<$R2, ModelReasoningToggle, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ModelReasoningToggleCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelReasoningEffortsMapper
    extends SubClassMapperBase<ModelReasoningEfforts> {
  ModelReasoningEffortsMapper._();

  static ModelReasoningEffortsMapper? _instance;
  static ModelReasoningEffortsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReasoningEffortsMapper._());
      ModelReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReasoningEfforts';

  static List<String> _$efforts(ModelReasoningEfforts v) => v.efforts;
  static const Field<ModelReasoningEfforts, List<String>> _f$efforts = Field(
    'efforts',
    _$efforts,
  );

  @override
  final MappableFields<ModelReasoningEfforts> fields = const {
    #efforts: _f$efforts,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'efforts';
  @override
  late final ClassMapperBase superMapper =
      ModelReasoningMapper.ensureInitialized();

  static ModelReasoningEfforts _instantiate(DecodingData data) {
    return ModelReasoningEfforts(efforts: data.dec(_f$efforts));
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReasoningEfforts fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReasoningEfforts>(map);
  }

  static ModelReasoningEfforts fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReasoningEfforts>(json);
  }
}

mixin ModelReasoningEffortsMappable {
  String toJson() {
    return ModelReasoningEffortsMapper.ensureInitialized()
        .encodeJson<ModelReasoningEfforts>(this as ModelReasoningEfforts);
  }

  Map<String, dynamic> toMap() {
    return ModelReasoningEffortsMapper.ensureInitialized()
        .encodeMap<ModelReasoningEfforts>(this as ModelReasoningEfforts);
  }

  ModelReasoningEffortsCopyWith<
    ModelReasoningEfforts,
    ModelReasoningEfforts,
    ModelReasoningEfforts
  >
  get copyWith =>
      _ModelReasoningEffortsCopyWithImpl<
        ModelReasoningEfforts,
        ModelReasoningEfforts
      >(this as ModelReasoningEfforts, $identity, $identity);
  @override
  String toString() {
    return ModelReasoningEffortsMapper.ensureInitialized().stringifyValue(
      this as ModelReasoningEfforts,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelReasoningEffortsMapper.ensureInitialized().equalsValue(
      this as ModelReasoningEfforts,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelReasoningEffortsMapper.ensureInitialized().hashValue(
      this as ModelReasoningEfforts,
    );
  }
}

extension ModelReasoningEffortsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelReasoningEfforts, $Out> {
  ModelReasoningEffortsCopyWith<$R, ModelReasoningEfforts, $Out>
  get $asModelReasoningEfforts => $base.as(
    (v, t, t2) => _ModelReasoningEffortsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ModelReasoningEffortsCopyWith<
  $R,
  $In extends ModelReasoningEfforts,
  $Out
>
    implements ModelReasoningCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get efforts;
  @override
  $R call({List<String>? efforts});
  ModelReasoningEffortsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelReasoningEffortsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelReasoningEfforts, $Out>
    implements ModelReasoningEffortsCopyWith<$R, ModelReasoningEfforts, $Out> {
  _ModelReasoningEffortsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelReasoningEfforts> $mapper =
      ModelReasoningEffortsMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get efforts =>
      ListCopyWith(
        $value.efforts,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(efforts: v),
      );
  @override
  $R call({List<String>? efforts}) =>
      $apply(FieldCopyWithData({if (efforts != null) #efforts: efforts}));
  @override
  ModelReasoningEfforts $make(CopyWithData data) =>
      ModelReasoningEfforts(efforts: data.get(#efforts, or: $value.efforts));

  @override
  ModelReasoningEffortsCopyWith<$R2, ModelReasoningEfforts, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ModelReasoningEffortsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelReasoningAlwaysMapper
    extends SubClassMapperBase<ModelReasoningAlways> {
  ModelReasoningAlwaysMapper._();

  static ModelReasoningAlwaysMapper? _instance;
  static ModelReasoningAlwaysMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReasoningAlwaysMapper._());
      ModelReasoningMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReasoningAlways';

  @override
  final MappableFields<ModelReasoningAlways> fields = const {};

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'always';
  @override
  late final ClassMapperBase superMapper =
      ModelReasoningMapper.ensureInitialized();

  static ModelReasoningAlways _instantiate(DecodingData data) {
    return ModelReasoningAlways();
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReasoningAlways fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReasoningAlways>(map);
  }

  static ModelReasoningAlways fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReasoningAlways>(json);
  }
}

mixin ModelReasoningAlwaysMappable {
  String toJson() {
    return ModelReasoningAlwaysMapper.ensureInitialized()
        .encodeJson<ModelReasoningAlways>(this as ModelReasoningAlways);
  }

  Map<String, dynamic> toMap() {
    return ModelReasoningAlwaysMapper.ensureInitialized()
        .encodeMap<ModelReasoningAlways>(this as ModelReasoningAlways);
  }

  ModelReasoningAlwaysCopyWith<
    ModelReasoningAlways,
    ModelReasoningAlways,
    ModelReasoningAlways
  >
  get copyWith =>
      _ModelReasoningAlwaysCopyWithImpl<
        ModelReasoningAlways,
        ModelReasoningAlways
      >(this as ModelReasoningAlways, $identity, $identity);
  @override
  String toString() {
    return ModelReasoningAlwaysMapper.ensureInitialized().stringifyValue(
      this as ModelReasoningAlways,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelReasoningAlwaysMapper.ensureInitialized().equalsValue(
      this as ModelReasoningAlways,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelReasoningAlwaysMapper.ensureInitialized().hashValue(
      this as ModelReasoningAlways,
    );
  }
}

extension ModelReasoningAlwaysValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelReasoningAlways, $Out> {
  ModelReasoningAlwaysCopyWith<$R, ModelReasoningAlways, $Out>
  get $asModelReasoningAlways => $base.as(
    (v, t, t2) => _ModelReasoningAlwaysCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ModelReasoningAlwaysCopyWith<
  $R,
  $In extends ModelReasoningAlways,
  $Out
>
    implements ModelReasoningCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ModelReasoningAlwaysCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelReasoningAlwaysCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelReasoningAlways, $Out>
    implements ModelReasoningAlwaysCopyWith<$R, ModelReasoningAlways, $Out> {
  _ModelReasoningAlwaysCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelReasoningAlways> $mapper =
      ModelReasoningAlwaysMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ModelReasoningAlways $make(CopyWithData data) => ModelReasoningAlways();

  @override
  ModelReasoningAlwaysCopyWith<$R2, ModelReasoningAlways, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ModelReasoningAlwaysCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

