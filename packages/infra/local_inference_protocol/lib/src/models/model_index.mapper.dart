// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model_index.dart';

class ModelIndexMapper extends ClassMapperBase<ModelIndex> {
  ModelIndexMapper._();

  static ModelIndexMapper? _instance;
  static ModelIndexMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelIndexMapper._());
      ModelIndexEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelIndex';

  static int _$version(ModelIndex v) => v.version;
  static const Field<ModelIndex, int> _f$version = Field('version', _$version);
  static List<ModelIndexEntry> _$models(ModelIndex v) => v.models;
  static const Field<ModelIndex, List<ModelIndexEntry>> _f$models = Field(
    'models',
    _$models,
  );

  @override
  final MappableFields<ModelIndex> fields = const {
    #version: _f$version,
    #models: _f$models,
  };

  static ModelIndex _instantiate(DecodingData data) {
    return ModelIndex(
      version: data.dec(_f$version),
      models: data.dec(_f$models),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelIndex fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelIndex>(map);
  }

  static ModelIndex fromJson(String json) {
    return ensureInitialized().decodeJson<ModelIndex>(json);
  }
}

mixin ModelIndexMappable {
  String toJson() {
    return ModelIndexMapper.ensureInitialized().encodeJson<ModelIndex>(
      this as ModelIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelIndexMapper.ensureInitialized().encodeMap<ModelIndex>(
      this as ModelIndex,
    );
  }

  ModelIndexCopyWith<ModelIndex, ModelIndex, ModelIndex> get copyWith =>
      _ModelIndexCopyWithImpl<ModelIndex, ModelIndex>(
        this as ModelIndex,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelIndexMapper.ensureInitialized().stringifyValue(
      this as ModelIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelIndexMapper.ensureInitialized().equalsValue(
      this as ModelIndex,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelIndexMapper.ensureInitialized().hashValue(this as ModelIndex);
  }
}

extension ModelIndexValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelIndex, $Out> {
  ModelIndexCopyWith<$R, ModelIndex, $Out> get $asModelIndex =>
      $base.as((v, t, t2) => _ModelIndexCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelIndexCopyWith<$R, $In extends ModelIndex, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ModelIndexEntry,
    ModelIndexEntryCopyWith<$R, ModelIndexEntry, ModelIndexEntry>
  >
  get models;
  $R call({int? version, List<ModelIndexEntry>? models});
  ModelIndexCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelIndexCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelIndex, $Out>
    implements ModelIndexCopyWith<$R, ModelIndex, $Out> {
  _ModelIndexCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelIndex> $mapper =
      ModelIndexMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ModelIndexEntry,
    ModelIndexEntryCopyWith<$R, ModelIndexEntry, ModelIndexEntry>
  >
  get models => ListCopyWith(
    $value.models,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(models: v),
  );
  @override
  $R call({int? version, List<ModelIndexEntry>? models}) => $apply(
    FieldCopyWithData({
      if (version != null) #version: version,
      if (models != null) #models: models,
    }),
  );
  @override
  ModelIndex $make(CopyWithData data) => ModelIndex(
    version: data.get(#version, or: $value.version),
    models: data.get(#models, or: $value.models),
  );

  @override
  ModelIndexCopyWith<$R2, ModelIndex, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelIndexCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelIndexEntryMapper extends ClassMapperBase<ModelIndexEntry> {
  ModelIndexEntryMapper._();

  static ModelIndexEntryMapper? _instance;
  static ModelIndexEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelIndexEntryMapper._());
      ModelProfileIdMapper.ensureInitialized();
      ModelReasoningMapper.ensureInitialized();
      ModelSamplingDefaultsMapper.ensureInitialized();
      ModelProvenanceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelIndexEntry';

  static String _$localId(ModelIndexEntry v) => v.localId;
  static const Field<ModelIndexEntry, String> _f$localId = Field(
    'localId',
    _$localId,
    key: r'local_id',
  );
  static String _$path(ModelIndexEntry v) => v.path;
  static const Field<ModelIndexEntry, String> _f$path = Field('path', _$path);
  static String _$displayName(ModelIndexEntry v) => v.displayName;
  static const Field<ModelIndexEntry, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    key: r'display_name',
  );
  static ModelProfileId _$profileId(ModelIndexEntry v) => v.profileId;
  static const Field<ModelIndexEntry, ModelProfileId> _f$profileId = Field(
    'profileId',
    _$profileId,
    key: r'profile_id',
  );
  static String _$architecture(ModelIndexEntry v) => v.architecture;
  static const Field<ModelIndexEntry, String> _f$architecture = Field(
    'architecture',
    _$architecture,
  );
  static String _$fileType(ModelIndexEntry v) => v.fileType;
  static const Field<ModelIndexEntry, String> _f$fileType = Field(
    'fileType',
    _$fileType,
    key: r'file_type',
  );
  static int _$sizeBytes(ModelIndexEntry v) => v.sizeBytes;
  static const Field<ModelIndexEntry, int> _f$sizeBytes = Field(
    'sizeBytes',
    _$sizeBytes,
    key: r'size_bytes',
  );
  static int _$trainedContextLength(ModelIndexEntry v) =>
      v.trainedContextLength;
  static const Field<ModelIndexEntry, int> _f$trainedContextLength = Field(
    'trainedContextLength',
    _$trainedContextLength,
    key: r'trained_context_length',
  );
  static ModelReasoning _$reasoning(ModelIndexEntry v) => v.reasoning;
  static const Field<ModelIndexEntry, ModelReasoning> _f$reasoning = Field(
    'reasoning',
    _$reasoning,
  );
  static ModelSamplingDefaults _$defaultSampling(ModelIndexEntry v) =>
      v.defaultSampling;
  static const Field<ModelIndexEntry, ModelSamplingDefaults>
  _f$defaultSampling = Field(
    'defaultSampling',
    _$defaultSampling,
    key: r'default_sampling',
  );
  static ModelProvenance _$provenance(ModelIndexEntry v) => v.provenance;
  static const Field<ModelIndexEntry, ModelProvenance> _f$provenance = Field(
    'provenance',
    _$provenance,
  );
  static String _$fingerprint(ModelIndexEntry v) => v.fingerprint;
  static const Field<ModelIndexEntry, String> _f$fingerprint = Field(
    'fingerprint',
    _$fingerprint,
  );
  static int? _$parameterCount(ModelIndexEntry v) => v.parameterCount;
  static const Field<ModelIndexEntry, int> _f$parameterCount = Field(
    'parameterCount',
    _$parameterCount,
    key: r'parameter_count',
    opt: true,
  );

  @override
  final MappableFields<ModelIndexEntry> fields = const {
    #localId: _f$localId,
    #path: _f$path,
    #displayName: _f$displayName,
    #profileId: _f$profileId,
    #architecture: _f$architecture,
    #fileType: _f$fileType,
    #sizeBytes: _f$sizeBytes,
    #trainedContextLength: _f$trainedContextLength,
    #reasoning: _f$reasoning,
    #defaultSampling: _f$defaultSampling,
    #provenance: _f$provenance,
    #fingerprint: _f$fingerprint,
    #parameterCount: _f$parameterCount,
  };

  static ModelIndexEntry _instantiate(DecodingData data) {
    return ModelIndexEntry(
      localId: data.dec(_f$localId),
      path: data.dec(_f$path),
      displayName: data.dec(_f$displayName),
      profileId: data.dec(_f$profileId),
      architecture: data.dec(_f$architecture),
      fileType: data.dec(_f$fileType),
      sizeBytes: data.dec(_f$sizeBytes),
      trainedContextLength: data.dec(_f$trainedContextLength),
      reasoning: data.dec(_f$reasoning),
      defaultSampling: data.dec(_f$defaultSampling),
      provenance: data.dec(_f$provenance),
      fingerprint: data.dec(_f$fingerprint),
      parameterCount: data.dec(_f$parameterCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelIndexEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelIndexEntry>(map);
  }

  static ModelIndexEntry fromJson(String json) {
    return ensureInitialized().decodeJson<ModelIndexEntry>(json);
  }
}

mixin ModelIndexEntryMappable {
  String toJson() {
    return ModelIndexEntryMapper.ensureInitialized()
        .encodeJson<ModelIndexEntry>(this as ModelIndexEntry);
  }

  Map<String, dynamic> toMap() {
    return ModelIndexEntryMapper.ensureInitialized().encodeMap<ModelIndexEntry>(
      this as ModelIndexEntry,
    );
  }

  ModelIndexEntryCopyWith<ModelIndexEntry, ModelIndexEntry, ModelIndexEntry>
  get copyWith =>
      _ModelIndexEntryCopyWithImpl<ModelIndexEntry, ModelIndexEntry>(
        this as ModelIndexEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelIndexEntryMapper.ensureInitialized().stringifyValue(
      this as ModelIndexEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelIndexEntryMapper.ensureInitialized().equalsValue(
      this as ModelIndexEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelIndexEntryMapper.ensureInitialized().hashValue(
      this as ModelIndexEntry,
    );
  }
}

extension ModelIndexEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelIndexEntry, $Out> {
  ModelIndexEntryCopyWith<$R, ModelIndexEntry, $Out> get $asModelIndexEntry =>
      $base.as((v, t, t2) => _ModelIndexEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelIndexEntryCopyWith<$R, $In extends ModelIndexEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ModelReasoningCopyWith<$R, ModelReasoning, ModelReasoning> get reasoning;
  ModelSamplingDefaultsCopyWith<
    $R,
    ModelSamplingDefaults,
    ModelSamplingDefaults
  >
  get defaultSampling;
  ModelProvenanceCopyWith<$R, ModelProvenance, ModelProvenance> get provenance;
  $R call({
    String? localId,
    String? path,
    String? displayName,
    ModelProfileId? profileId,
    String? architecture,
    String? fileType,
    int? sizeBytes,
    int? trainedContextLength,
    ModelReasoning? reasoning,
    ModelSamplingDefaults? defaultSampling,
    ModelProvenance? provenance,
    String? fingerprint,
    int? parameterCount,
  });
  ModelIndexEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelIndexEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelIndexEntry, $Out>
    implements ModelIndexEntryCopyWith<$R, ModelIndexEntry, $Out> {
  _ModelIndexEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelIndexEntry> $mapper =
      ModelIndexEntryMapper.ensureInitialized();
  @override
  ModelReasoningCopyWith<$R, ModelReasoning, ModelReasoning> get reasoning =>
      $value.reasoning.copyWith.$chain((v) => call(reasoning: v));
  @override
  ModelSamplingDefaultsCopyWith<
    $R,
    ModelSamplingDefaults,
    ModelSamplingDefaults
  >
  get defaultSampling =>
      $value.defaultSampling.copyWith.$chain((v) => call(defaultSampling: v));
  @override
  ModelProvenanceCopyWith<$R, ModelProvenance, ModelProvenance>
  get provenance =>
      $value.provenance.copyWith.$chain((v) => call(provenance: v));
  @override
  $R call({
    String? localId,
    String? path,
    String? displayName,
    ModelProfileId? profileId,
    String? architecture,
    String? fileType,
    int? sizeBytes,
    int? trainedContextLength,
    ModelReasoning? reasoning,
    ModelSamplingDefaults? defaultSampling,
    ModelProvenance? provenance,
    String? fingerprint,
    Object? parameterCount = $none,
  }) => $apply(
    FieldCopyWithData({
      if (localId != null) #localId: localId,
      if (path != null) #path: path,
      if (displayName != null) #displayName: displayName,
      if (profileId != null) #profileId: profileId,
      if (architecture != null) #architecture: architecture,
      if (fileType != null) #fileType: fileType,
      if (sizeBytes != null) #sizeBytes: sizeBytes,
      if (trainedContextLength != null)
        #trainedContextLength: trainedContextLength,
      if (reasoning != null) #reasoning: reasoning,
      if (defaultSampling != null) #defaultSampling: defaultSampling,
      if (provenance != null) #provenance: provenance,
      if (fingerprint != null) #fingerprint: fingerprint,
      if (parameterCount != $none) #parameterCount: parameterCount,
    }),
  );
  @override
  ModelIndexEntry $make(CopyWithData data) => ModelIndexEntry(
    localId: data.get(#localId, or: $value.localId),
    path: data.get(#path, or: $value.path),
    displayName: data.get(#displayName, or: $value.displayName),
    profileId: data.get(#profileId, or: $value.profileId),
    architecture: data.get(#architecture, or: $value.architecture),
    fileType: data.get(#fileType, or: $value.fileType),
    sizeBytes: data.get(#sizeBytes, or: $value.sizeBytes),
    trainedContextLength: data.get(
      #trainedContextLength,
      or: $value.trainedContextLength,
    ),
    reasoning: data.get(#reasoning, or: $value.reasoning),
    defaultSampling: data.get(#defaultSampling, or: $value.defaultSampling),
    provenance: data.get(#provenance, or: $value.provenance),
    fingerprint: data.get(#fingerprint, or: $value.fingerprint),
    parameterCount: data.get(#parameterCount, or: $value.parameterCount),
  );

  @override
  ModelIndexEntryCopyWith<$R2, ModelIndexEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelIndexEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelSamplingDefaultsMapper
    extends ClassMapperBase<ModelSamplingDefaults> {
  ModelSamplingDefaultsMapper._();

  static ModelSamplingDefaultsMapper? _instance;
  static ModelSamplingDefaultsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelSamplingDefaultsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ModelSamplingDefaults';

  static double? _$temperature(ModelSamplingDefaults v) => v.temperature;
  static const Field<ModelSamplingDefaults, double> _f$temperature = Field(
    'temperature',
    _$temperature,
    opt: true,
  );
  static int? _$topK(ModelSamplingDefaults v) => v.topK;
  static const Field<ModelSamplingDefaults, int> _f$topK = Field(
    'topK',
    _$topK,
    key: r'top_k',
    opt: true,
  );
  static double? _$topP(ModelSamplingDefaults v) => v.topP;
  static const Field<ModelSamplingDefaults, double> _f$topP = Field(
    'topP',
    _$topP,
    key: r'top_p',
    opt: true,
  );
  static double? _$minP(ModelSamplingDefaults v) => v.minP;
  static const Field<ModelSamplingDefaults, double> _f$minP = Field(
    'minP',
    _$minP,
    key: r'min_p',
    opt: true,
  );

  @override
  final MappableFields<ModelSamplingDefaults> fields = const {
    #temperature: _f$temperature,
    #topK: _f$topK,
    #topP: _f$topP,
    #minP: _f$minP,
  };

  static ModelSamplingDefaults _instantiate(DecodingData data) {
    return ModelSamplingDefaults(
      temperature: data.dec(_f$temperature),
      topK: data.dec(_f$topK),
      topP: data.dec(_f$topP),
      minP: data.dec(_f$minP),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelSamplingDefaults fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelSamplingDefaults>(map);
  }

  static ModelSamplingDefaults fromJson(String json) {
    return ensureInitialized().decodeJson<ModelSamplingDefaults>(json);
  }
}

mixin ModelSamplingDefaultsMappable {
  String toJson() {
    return ModelSamplingDefaultsMapper.ensureInitialized()
        .encodeJson<ModelSamplingDefaults>(this as ModelSamplingDefaults);
  }

  Map<String, dynamic> toMap() {
    return ModelSamplingDefaultsMapper.ensureInitialized()
        .encodeMap<ModelSamplingDefaults>(this as ModelSamplingDefaults);
  }

  ModelSamplingDefaultsCopyWith<
    ModelSamplingDefaults,
    ModelSamplingDefaults,
    ModelSamplingDefaults
  >
  get copyWith =>
      _ModelSamplingDefaultsCopyWithImpl<
        ModelSamplingDefaults,
        ModelSamplingDefaults
      >(this as ModelSamplingDefaults, $identity, $identity);
  @override
  String toString() {
    return ModelSamplingDefaultsMapper.ensureInitialized().stringifyValue(
      this as ModelSamplingDefaults,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelSamplingDefaultsMapper.ensureInitialized().equalsValue(
      this as ModelSamplingDefaults,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelSamplingDefaultsMapper.ensureInitialized().hashValue(
      this as ModelSamplingDefaults,
    );
  }
}

extension ModelSamplingDefaultsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelSamplingDefaults, $Out> {
  ModelSamplingDefaultsCopyWith<$R, ModelSamplingDefaults, $Out>
  get $asModelSamplingDefaults => $base.as(
    (v, t, t2) => _ModelSamplingDefaultsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ModelSamplingDefaultsCopyWith<
  $R,
  $In extends ModelSamplingDefaults,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({double? temperature, int? topK, double? topP, double? minP});
  ModelSamplingDefaultsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelSamplingDefaultsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelSamplingDefaults, $Out>
    implements ModelSamplingDefaultsCopyWith<$R, ModelSamplingDefaults, $Out> {
  _ModelSamplingDefaultsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelSamplingDefaults> $mapper =
      ModelSamplingDefaultsMapper.ensureInitialized();
  @override
  $R call({
    Object? temperature = $none,
    Object? topK = $none,
    Object? topP = $none,
    Object? minP = $none,
  }) => $apply(
    FieldCopyWithData({
      if (temperature != $none) #temperature: temperature,
      if (topK != $none) #topK: topK,
      if (topP != $none) #topP: topP,
      if (minP != $none) #minP: minP,
    }),
  );
  @override
  ModelSamplingDefaults $make(CopyWithData data) => ModelSamplingDefaults(
    temperature: data.get(#temperature, or: $value.temperature),
    topK: data.get(#topK, or: $value.topK),
    topP: data.get(#topP, or: $value.topP),
    minP: data.get(#minP, or: $value.minP),
  );

  @override
  ModelSamplingDefaultsCopyWith<$R2, ModelSamplingDefaults, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ModelSamplingDefaultsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelProvenanceMapper extends ClassMapperBase<ModelProvenance> {
  ModelProvenanceMapper._();

  static ModelProvenanceMapper? _instance;
  static ModelProvenanceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelProvenanceMapper._());
      ModelDownloadedMapper.ensureInitialized();
      ModelScannedMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelProvenance';

  @override
  final MappableFields<ModelProvenance> fields = const {};

  static ModelProvenance _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ModelProvenance',
      'source',
      '${data.value['source']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelProvenance fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelProvenance>(map);
  }

  static ModelProvenance fromJson(String json) {
    return ensureInitialized().decodeJson<ModelProvenance>(json);
  }
}

mixin ModelProvenanceMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ModelProvenanceCopyWith<ModelProvenance, ModelProvenance, ModelProvenance>
  get copyWith;
}

abstract class ModelProvenanceCopyWith<$R, $In extends ModelProvenance, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ModelProvenanceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class ModelDownloadedMapper extends SubClassMapperBase<ModelDownloaded> {
  ModelDownloadedMapper._();

  static ModelDownloadedMapper? _instance;
  static ModelDownloadedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelDownloadedMapper._());
      ModelProvenanceMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelDownloaded';

  static String _$repo(ModelDownloaded v) => v.repo;
  static const Field<ModelDownloaded, String> _f$repo = Field('repo', _$repo);
  static String _$file(ModelDownloaded v) => v.file;
  static const Field<ModelDownloaded, String> _f$file = Field('file', _$file);
  static String? _$revision(ModelDownloaded v) => v.revision;
  static const Field<ModelDownloaded, String> _f$revision = Field(
    'revision',
    _$revision,
    opt: true,
  );

  @override
  final MappableFields<ModelDownloaded> fields = const {
    #repo: _f$repo,
    #file: _f$file,
    #revision: _f$revision,
  };

  @override
  final String discriminatorKey = 'source';
  @override
  final dynamic discriminatorValue = 'downloaded';
  @override
  late final ClassMapperBase superMapper =
      ModelProvenanceMapper.ensureInitialized();

  static ModelDownloaded _instantiate(DecodingData data) {
    return ModelDownloaded(
      repo: data.dec(_f$repo),
      file: data.dec(_f$file),
      revision: data.dec(_f$revision),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelDownloaded fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelDownloaded>(map);
  }

  static ModelDownloaded fromJson(String json) {
    return ensureInitialized().decodeJson<ModelDownloaded>(json);
  }
}

mixin ModelDownloadedMappable {
  String toJson() {
    return ModelDownloadedMapper.ensureInitialized()
        .encodeJson<ModelDownloaded>(this as ModelDownloaded);
  }

  Map<String, dynamic> toMap() {
    return ModelDownloadedMapper.ensureInitialized().encodeMap<ModelDownloaded>(
      this as ModelDownloaded,
    );
  }

  ModelDownloadedCopyWith<ModelDownloaded, ModelDownloaded, ModelDownloaded>
  get copyWith =>
      _ModelDownloadedCopyWithImpl<ModelDownloaded, ModelDownloaded>(
        this as ModelDownloaded,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelDownloadedMapper.ensureInitialized().stringifyValue(
      this as ModelDownloaded,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelDownloadedMapper.ensureInitialized().equalsValue(
      this as ModelDownloaded,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelDownloadedMapper.ensureInitialized().hashValue(
      this as ModelDownloaded,
    );
  }
}

extension ModelDownloadedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelDownloaded, $Out> {
  ModelDownloadedCopyWith<$R, ModelDownloaded, $Out> get $asModelDownloaded =>
      $base.as((v, t, t2) => _ModelDownloadedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelDownloadedCopyWith<$R, $In extends ModelDownloaded, $Out>
    implements ModelProvenanceCopyWith<$R, $In, $Out> {
  @override
  $R call({String? repo, String? file, String? revision});
  ModelDownloadedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelDownloadedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelDownloaded, $Out>
    implements ModelDownloadedCopyWith<$R, ModelDownloaded, $Out> {
  _ModelDownloadedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelDownloaded> $mapper =
      ModelDownloadedMapper.ensureInitialized();
  @override
  $R call({String? repo, String? file, Object? revision = $none}) => $apply(
    FieldCopyWithData({
      if (repo != null) #repo: repo,
      if (file != null) #file: file,
      if (revision != $none) #revision: revision,
    }),
  );
  @override
  ModelDownloaded $make(CopyWithData data) => ModelDownloaded(
    repo: data.get(#repo, or: $value.repo),
    file: data.get(#file, or: $value.file),
    revision: data.get(#revision, or: $value.revision),
  );

  @override
  ModelDownloadedCopyWith<$R2, ModelDownloaded, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelDownloadedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelScannedMapper extends SubClassMapperBase<ModelScanned> {
  ModelScannedMapper._();

  static ModelScannedMapper? _instance;
  static ModelScannedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelScannedMapper._());
      ModelProvenanceMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelScanned';

  static String _$root(ModelScanned v) => v.root;
  static const Field<ModelScanned, String> _f$root = Field('root', _$root);

  @override
  final MappableFields<ModelScanned> fields = const {#root: _f$root};

  @override
  final String discriminatorKey = 'source';
  @override
  final dynamic discriminatorValue = 'scanned';
  @override
  late final ClassMapperBase superMapper =
      ModelProvenanceMapper.ensureInitialized();

  static ModelScanned _instantiate(DecodingData data) {
    return ModelScanned(root: data.dec(_f$root));
  }

  @override
  final Function instantiate = _instantiate;

  static ModelScanned fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelScanned>(map);
  }

  static ModelScanned fromJson(String json) {
    return ensureInitialized().decodeJson<ModelScanned>(json);
  }
}

mixin ModelScannedMappable {
  String toJson() {
    return ModelScannedMapper.ensureInitialized().encodeJson<ModelScanned>(
      this as ModelScanned,
    );
  }

  Map<String, dynamic> toMap() {
    return ModelScannedMapper.ensureInitialized().encodeMap<ModelScanned>(
      this as ModelScanned,
    );
  }

  ModelScannedCopyWith<ModelScanned, ModelScanned, ModelScanned> get copyWith =>
      _ModelScannedCopyWithImpl<ModelScanned, ModelScanned>(
        this as ModelScanned,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelScannedMapper.ensureInitialized().stringifyValue(
      this as ModelScanned,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelScannedMapper.ensureInitialized().equalsValue(
      this as ModelScanned,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelScannedMapper.ensureInitialized().hashValue(
      this as ModelScanned,
    );
  }
}

extension ModelScannedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelScanned, $Out> {
  ModelScannedCopyWith<$R, ModelScanned, $Out> get $asModelScanned =>
      $base.as((v, t, t2) => _ModelScannedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelScannedCopyWith<$R, $In extends ModelScanned, $Out>
    implements ModelProvenanceCopyWith<$R, $In, $Out> {
  @override
  $R call({String? root});
  ModelScannedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ModelScannedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelScanned, $Out>
    implements ModelScannedCopyWith<$R, ModelScanned, $Out> {
  _ModelScannedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelScanned> $mapper =
      ModelScannedMapper.ensureInitialized();
  @override
  $R call({String? root}) =>
      $apply(FieldCopyWithData({if (root != null) #root: root}));
  @override
  ModelScanned $make(CopyWithData data) =>
      ModelScanned(root: data.get(#root, or: $value.root));

  @override
  ModelScannedCopyWith<$R2, ModelScanned, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelScannedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

