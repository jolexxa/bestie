// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model_status.dart';

class ModelStatusMapper extends ClassMapperBase<ModelStatus> {
  ModelStatusMapper._();

  static ModelStatusMapper? _instance;
  static ModelStatusMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelStatusMapper._());
      ModelUnloadedMapper.ensureInitialized();
      ModelFittingMapper.ensureInitialized();
      ModelLoadingMapper.ensureInitialized();
      ModelReadyMapper.ensureInitialized();
      ModelFailedMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelStatus';

  @override
  final MappableFields<ModelStatus> fields = const {};

  static ModelStatus _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ModelStatus',
      'state',
      '${data.value['state']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelStatus fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelStatus>(map);
  }

  static ModelStatus fromJson(String json) {
    return ensureInitialized().decodeJson<ModelStatus>(json);
  }
}

mixin ModelStatusMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ModelStatusCopyWith<ModelStatus, ModelStatus, ModelStatus> get copyWith;
}

abstract class ModelStatusCopyWith<$R, $In extends ModelStatus, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ModelStatusCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class ModelUnloadedMapper extends SubClassMapperBase<ModelUnloaded> {
  ModelUnloadedMapper._();

  static ModelUnloadedMapper? _instance;
  static ModelUnloadedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelUnloadedMapper._());
      ModelStatusMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelUnloaded';

  @override
  final MappableFields<ModelUnloaded> fields = const {};

  @override
  final String discriminatorKey = 'state';
  @override
  final dynamic discriminatorValue = 'unloaded';
  @override
  late final ClassMapperBase superMapper =
      ModelStatusMapper.ensureInitialized();

  static ModelUnloaded _instantiate(DecodingData data) {
    return ModelUnloaded();
  }

  @override
  final Function instantiate = _instantiate;

  static ModelUnloaded fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelUnloaded>(map);
  }

  static ModelUnloaded fromJson(String json) {
    return ensureInitialized().decodeJson<ModelUnloaded>(json);
  }
}

mixin ModelUnloadedMappable {
  String toJson() {
    return ModelUnloadedMapper.ensureInitialized().encodeJson<ModelUnloaded>(
      this as ModelUnloaded,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelUnloadedMapper.ensureInitialized().encodeMap<ModelUnloaded>(
      this as ModelUnloaded,
    );
  }

  ModelUnloadedCopyWith<ModelUnloaded, ModelUnloaded, ModelUnloaded>
  get copyWith => _ModelUnloadedCopyWithImpl<ModelUnloaded, ModelUnloaded>(
    this as ModelUnloaded,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ModelUnloadedMapper.ensureInitialized().stringifyValue(
      this as ModelUnloaded,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelUnloadedMapper.ensureInitialized().equalsValue(
      this as ModelUnloaded,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelUnloadedMapper.ensureInitialized().hashValue(
      this as ModelUnloaded,
    );
  }
}

extension ModelUnloadedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelUnloaded, $Out> {
  ModelUnloadedCopyWith<$R, ModelUnloaded, $Out> get $asModelUnloaded =>
      $base.as((v, t, t2) => _ModelUnloadedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelUnloadedCopyWith<$R, $In extends ModelUnloaded, $Out>
    implements ModelStatusCopyWith<$R, $In, $Out> {
  @override
  $R call();
  ModelUnloadedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelUnloadedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelUnloaded, $Out>
    implements ModelUnloadedCopyWith<$R, ModelUnloaded, $Out> {
  _ModelUnloadedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelUnloaded> $mapper =
      ModelUnloadedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ModelUnloaded $make(CopyWithData data) => ModelUnloaded();

  @override
  ModelUnloadedCopyWith<$R2, ModelUnloaded, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelUnloadedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelFittingMapper extends SubClassMapperBase<ModelFitting> {
  ModelFittingMapper._();

  static ModelFittingMapper? _instance;
  static ModelFittingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelFittingMapper._());
      ModelStatusMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelFitting';

  static String _$localId(ModelFitting v) => v.localId;
  static const Field<ModelFitting, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );

  @override
  final MappableFields<ModelFitting> fields = const {#localId: _f$localId};

  @override
  final String discriminatorKey = 'state';
  @override
  final dynamic discriminatorValue = 'fitting';
  @override
  late final ClassMapperBase superMapper =
      ModelStatusMapper.ensureInitialized();

  static ModelFitting _instantiate(DecodingData data) {
    return ModelFitting(localId: data.dec(_f$localId));
  }

  @override
  final Function instantiate = _instantiate;

  static ModelFitting fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelFitting>(map);
  }

  static ModelFitting fromJson(String json) {
    return ensureInitialized().decodeJson<ModelFitting>(json);
  }
}

mixin ModelFittingMappable {
  String toJson() {
    return ModelFittingMapper.ensureInitialized().encodeJson<ModelFitting>(
      this as ModelFitting,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelFittingMapper.ensureInitialized().encodeMap<ModelFitting>(
      this as ModelFitting,
    );
  }

  ModelFittingCopyWith<ModelFitting, ModelFitting, ModelFitting> get copyWith =>
      _ModelFittingCopyWithImpl<ModelFitting, ModelFitting>(
        this as ModelFitting,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelFittingMapper.ensureInitialized().stringifyValue(
      this as ModelFitting,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelFittingMapper.ensureInitialized().equalsValue(
      this as ModelFitting,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelFittingMapper.ensureInitialized().hashValue(
      this as ModelFitting,
    );
  }
}

extension ModelFittingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelFitting, $Out> {
  ModelFittingCopyWith<$R, ModelFitting, $Out> get $asModelFitting =>
      $base.as((v, t, t2) => _ModelFittingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelFittingCopyWith<$R, $In extends ModelFitting, $Out>
    implements ModelStatusCopyWith<$R, $In, $Out> {
  @override
  $R call({String? localId});
  ModelFittingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelFittingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelFitting, $Out>
    implements ModelFittingCopyWith<$R, ModelFitting, $Out> {
  _ModelFittingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelFitting> $mapper =
      ModelFittingMapper.ensureInitialized();
  @override
  $R call({String? localId}) =>
      $apply(FieldCopyWithData({if (localId != null) #localId: localId}));
  @override
  ModelFitting $make(CopyWithData data) =>
      ModelFitting(localId: data.get(#localId, or: $value.localId));

  @override
  ModelFittingCopyWith<$R2, ModelFitting, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelFittingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelLoadingMapper extends SubClassMapperBase<ModelLoading> {
  ModelLoadingMapper._();

  static ModelLoadingMapper? _instance;
  static ModelLoadingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelLoadingMapper._());
      ModelStatusMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelLoading';

  static String _$localId(ModelLoading v) => v.localId;
  static const Field<ModelLoading, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );
  static double _$progress(ModelLoading v) => v.progress;
  static const Field<ModelLoading, double> _f$progress = Field(
    'progress',
    _$progress,
  );

  @override
  final MappableFields<ModelLoading> fields = const {
    #localId: _f$localId,
    #progress: _f$progress,
  };

  @override
  final String discriminatorKey = 'state';
  @override
  final dynamic discriminatorValue = 'loading';
  @override
  late final ClassMapperBase superMapper =
      ModelStatusMapper.ensureInitialized();

  static ModelLoading _instantiate(DecodingData data) {
    return ModelLoading(
      localId: data.dec(_f$localId),
      progress: data.dec(_f$progress),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelLoading fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelLoading>(map);
  }

  static ModelLoading fromJson(String json) {
    return ensureInitialized().decodeJson<ModelLoading>(json);
  }
}

mixin ModelLoadingMappable {
  String toJson() {
    return ModelLoadingMapper.ensureInitialized().encodeJson<ModelLoading>(
      this as ModelLoading,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelLoadingMapper.ensureInitialized().encodeMap<ModelLoading>(
      this as ModelLoading,
    );
  }

  ModelLoadingCopyWith<ModelLoading, ModelLoading, ModelLoading> get copyWith =>
      _ModelLoadingCopyWithImpl<ModelLoading, ModelLoading>(
        this as ModelLoading,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelLoadingMapper.ensureInitialized().stringifyValue(
      this as ModelLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelLoadingMapper.ensureInitialized().equalsValue(
      this as ModelLoading,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelLoadingMapper.ensureInitialized().hashValue(
      this as ModelLoading,
    );
  }
}

extension ModelLoadingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelLoading, $Out> {
  ModelLoadingCopyWith<$R, ModelLoading, $Out> get $asModelLoading =>
      $base.as((v, t, t2) => _ModelLoadingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelLoadingCopyWith<$R, $In extends ModelLoading, $Out>
    implements ModelStatusCopyWith<$R, $In, $Out> {
  @override
  $R call({String? localId, double? progress});
  ModelLoadingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelLoadingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelLoading, $Out>
    implements ModelLoadingCopyWith<$R, ModelLoading, $Out> {
  _ModelLoadingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelLoading> $mapper =
      ModelLoadingMapper.ensureInitialized();
  @override
  $R call({String? localId, double? progress}) => $apply(
    FieldCopyWithData({
      if (localId != null) #localId: localId,
      if (progress != null) #progress: progress,
    }),
  );
  @override
  ModelLoading $make(CopyWithData data) => ModelLoading(
    localId: data.get(#localId, or: $value.localId),
    progress: data.get(#progress, or: $value.progress),
  );

  @override
  ModelLoadingCopyWith<$R2, ModelLoading, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelLoadingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelReadyMapper extends SubClassMapperBase<ModelReady> {
  ModelReadyMapper._();

  static ModelReadyMapper? _instance;
  static ModelReadyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelReadyMapper._());
      ModelStatusMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelReady';

  static String _$localId(ModelReady v) => v.localId;
  static const Field<ModelReady, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );
  static int _$contextSize(ModelReady v) => v.contextSize;
  static const Field<ModelReady, int> _f$contextSize = Field(
    'contextSize',
    _$contextSize,
    key: r'context_size',
  );
  static int _$maxAgents(ModelReady v) => v.maxAgents;
  static const Field<ModelReady, int> _f$maxAgents = Field(
    'maxAgents',
    _$maxAgents,
    key: r'max_agents',
  );
  static int _$deviceBytes(ModelReady v) => v.deviceBytes;
  static const Field<ModelReady, int> _f$deviceBytes = Field(
    'deviceBytes',
    _$deviceBytes,
    key: r'device_bytes',
  );

  @override
  final MappableFields<ModelReady> fields = const {
    #localId: _f$localId,
    #contextSize: _f$contextSize,
    #maxAgents: _f$maxAgents,
    #deviceBytes: _f$deviceBytes,
  };

  @override
  final String discriminatorKey = 'state';
  @override
  final dynamic discriminatorValue = 'ready';
  @override
  late final ClassMapperBase superMapper =
      ModelStatusMapper.ensureInitialized();

  static ModelReady _instantiate(DecodingData data) {
    return ModelReady(
      localId: data.dec(_f$localId),
      contextSize: data.dec(_f$contextSize),
      maxAgents: data.dec(_f$maxAgents),
      deviceBytes: data.dec(_f$deviceBytes),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelReady fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelReady>(map);
  }

  static ModelReady fromJson(String json) {
    return ensureInitialized().decodeJson<ModelReady>(json);
  }
}

mixin ModelReadyMappable {
  String toJson() {
    return ModelReadyMapper.ensureInitialized().encodeJson<ModelReady>(
      this as ModelReady,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelReadyMapper.ensureInitialized().encodeMap<ModelReady>(
      this as ModelReady,
    );
  }

  ModelReadyCopyWith<ModelReady, ModelReady, ModelReady> get copyWith =>
      _ModelReadyCopyWithImpl<ModelReady, ModelReady>(
        this as ModelReady,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelReadyMapper.ensureInitialized().stringifyValue(
      this as ModelReady,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelReadyMapper.ensureInitialized().equalsValue(
      this as ModelReady,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelReadyMapper.ensureInitialized().hashValue(this as ModelReady);
  }
}

extension ModelReadyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelReady, $Out> {
  ModelReadyCopyWith<$R, ModelReady, $Out> get $asModelReady =>
      $base.as((v, t, t2) => _ModelReadyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelReadyCopyWith<$R, $In extends ModelReady, $Out>
    implements ModelStatusCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? localId,
    int? contextSize,
    int? maxAgents,
    int? deviceBytes,
  });
  ModelReadyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelReadyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelReady, $Out>
    implements ModelReadyCopyWith<$R, ModelReady, $Out> {
  _ModelReadyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelReady> $mapper =
      ModelReadyMapper.ensureInitialized();
  @override
  $R call({
    String? localId,
    int? contextSize,
    int? maxAgents,
    int? deviceBytes,
  }) => $apply(
    FieldCopyWithData({
      if (localId != null) #localId: localId,
      if (contextSize != null) #contextSize: contextSize,
      if (maxAgents != null) #maxAgents: maxAgents,
      if (deviceBytes != null) #deviceBytes: deviceBytes,
    }),
  );
  @override
  ModelReady $make(CopyWithData data) => ModelReady(
    localId: data.get(#localId, or: $value.localId),
    contextSize: data.get(#contextSize, or: $value.contextSize),
    maxAgents: data.get(#maxAgents, or: $value.maxAgents),
    deviceBytes: data.get(#deviceBytes, or: $value.deviceBytes),
  );

  @override
  ModelReadyCopyWith<$R2, ModelReady, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelReadyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelFailedMapper extends SubClassMapperBase<ModelFailed> {
  ModelFailedMapper._();

  static ModelFailedMapper? _instance;
  static ModelFailedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelFailedMapper._());
      ModelStatusMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelFailed';

  static String _$localId(ModelFailed v) => v.localId;
  static const Field<ModelFailed, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );
  static String _$reason(ModelFailed v) => v.reason;
  static const Field<ModelFailed, String> _f$reason = Field('reason', _$reason);

  @override
  final MappableFields<ModelFailed> fields = const {
    #localId: _f$localId,
    #reason: _f$reason,
  };

  @override
  final String discriminatorKey = 'state';
  @override
  final dynamic discriminatorValue = 'failed';
  @override
  late final ClassMapperBase superMapper =
      ModelStatusMapper.ensureInitialized();

  static ModelFailed _instantiate(DecodingData data) {
    return ModelFailed(
      localId: data.dec(_f$localId),
      reason: data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelFailed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelFailed>(map);
  }

  static ModelFailed fromJson(String json) {
    return ensureInitialized().decodeJson<ModelFailed>(json);
  }
}

mixin ModelFailedMappable {
  String toJson() {
    return ModelFailedMapper.ensureInitialized().encodeJson<ModelFailed>(
      this as ModelFailed,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelFailedMapper.ensureInitialized().encodeMap<ModelFailed>(
      this as ModelFailed,
    );
  }

  ModelFailedCopyWith<ModelFailed, ModelFailed, ModelFailed> get copyWith =>
      _ModelFailedCopyWithImpl<ModelFailed, ModelFailed>(
        this as ModelFailed,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelFailedMapper.ensureInitialized().stringifyValue(
      this as ModelFailed,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelFailedMapper.ensureInitialized().equalsValue(
      this as ModelFailed,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelFailedMapper.ensureInitialized().hashValue(this as ModelFailed);
  }
}

extension ModelFailedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelFailed, $Out> {
  ModelFailedCopyWith<$R, ModelFailed, $Out> get $asModelFailed =>
      $base.as((v, t, t2) => _ModelFailedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelFailedCopyWith<$R, $In extends ModelFailed, $Out>
    implements ModelStatusCopyWith<$R, $In, $Out> {
  @override
  $R call({String? localId, String? reason});
  ModelFailedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelFailedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelFailed, $Out>
    implements ModelFailedCopyWith<$R, ModelFailed, $Out> {
  _ModelFailedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelFailed> $mapper =
      ModelFailedMapper.ensureInitialized();
  @override
  $R call({String? localId, String? reason}) => $apply(
    FieldCopyWithData({
      if (localId != null) #localId: localId,
      if (reason != null) #reason: reason,
    }),
  );
  @override
  ModelFailed $make(CopyWithData data) => ModelFailed(
    localId: data.get(#localId, or: $value.localId),
    reason: data.get(#reason, or: $value.reason),
  );

  @override
  ModelFailedCopyWith<$R2, ModelFailed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelFailedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelLoadRequestMapper extends ClassMapperBase<ModelLoadRequest> {
  ModelLoadRequestMapper._();

  static ModelLoadRequestMapper? _instance;
  static ModelLoadRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelLoadRequestMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ModelLoadRequest';

  static String _$localId(ModelLoadRequest v) => v.localId;
  static const Field<ModelLoadRequest, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );
  static int _$maxAgents(ModelLoadRequest v) => v.maxAgents;
  static const Field<ModelLoadRequest, int> _f$maxAgents = Field(
    'maxAgents',
    _$maxAgents,
    key: r'max_agents',
  );
  static int? _$contextCap(ModelLoadRequest v) => v.contextCap;
  static const Field<ModelLoadRequest, int> _f$contextCap = Field(
    'contextCap',
    _$contextCap,
    key: r'context_cap',
    opt: true,
  );

  @override
  final MappableFields<ModelLoadRequest> fields = const {
    #localId: _f$localId,
    #maxAgents: _f$maxAgents,
    #contextCap: _f$contextCap,
  };

  static ModelLoadRequest _instantiate(DecodingData data) {
    return ModelLoadRequest(
      localId: data.dec(_f$localId),
      maxAgents: data.dec(_f$maxAgents),
      contextCap: data.dec(_f$contextCap),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelLoadRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelLoadRequest>(map);
  }

  static ModelLoadRequest fromJson(String json) {
    return ensureInitialized().decodeJson<ModelLoadRequest>(json);
  }
}

mixin ModelLoadRequestMappable {
  String toJson() {
    return ModelLoadRequestMapper.ensureInitialized()
        .encodeJson<ModelLoadRequest>(this as ModelLoadRequest);
  }

  Map<String, dynamic> toMap() {
    return ModelLoadRequestMapper.ensureInitialized()
        .encodeMap<ModelLoadRequest>(this as ModelLoadRequest);
  }

  ModelLoadRequestCopyWith<ModelLoadRequest, ModelLoadRequest, ModelLoadRequest>
  get copyWith =>
      _ModelLoadRequestCopyWithImpl<ModelLoadRequest, ModelLoadRequest>(
        this as ModelLoadRequest,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelLoadRequestMapper.ensureInitialized().stringifyValue(
      this as ModelLoadRequest,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelLoadRequestMapper.ensureInitialized().equalsValue(
      this as ModelLoadRequest,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelLoadRequestMapper.ensureInitialized().hashValue(
      this as ModelLoadRequest,
    );
  }
}

extension ModelLoadRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelLoadRequest, $Out> {
  ModelLoadRequestCopyWith<$R, ModelLoadRequest, $Out>
  get $asModelLoadRequest =>
      $base.as((v, t, t2) => _ModelLoadRequestCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelLoadRequestCopyWith<$R, $In extends ModelLoadRequest, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? localId, int? maxAgents, int? contextCap});
  ModelLoadRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelLoadRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelLoadRequest, $Out>
    implements ModelLoadRequestCopyWith<$R, ModelLoadRequest, $Out> {
  _ModelLoadRequestCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelLoadRequest> $mapper =
      ModelLoadRequestMapper.ensureInitialized();
  @override
  $R call({String? localId, int? maxAgents, Object? contextCap = $none}) =>
      $apply(
        FieldCopyWithData({
          if (localId != null) #localId: localId,
          if (maxAgents != null) #maxAgents: maxAgents,
          if (contextCap != $none) #contextCap: contextCap,
        }),
      );
  @override
  ModelLoadRequest $make(CopyWithData data) => ModelLoadRequest(
    localId: data.get(#localId, or: $value.localId),
    maxAgents: data.get(#maxAgents, or: $value.maxAgents),
    contextCap: data.get(#contextCap, or: $value.contextCap),
  );

  @override
  ModelLoadRequestCopyWith<$R2, ModelLoadRequest, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelLoadRequestCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

