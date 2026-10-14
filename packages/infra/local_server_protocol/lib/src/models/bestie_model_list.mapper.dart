// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'bestie_model_list.dart';

class BestieModelListMapper extends ClassMapperBase<BestieModelList> {
  BestieModelListMapper._();

  static BestieModelListMapper? _instance;
  static BestieModelListMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BestieModelListMapper._());
      BestieModelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'BestieModelList';

  static List<BestieModel> _$data(BestieModelList v) => v.data;
  static const Field<BestieModelList, List<BestieModel>> _f$data = Field(
    'data',
    _$data,
  );
  static String _$object(BestieModelList v) => v.object;
  static const Field<BestieModelList, String> _f$object = Field(
    'object',
    _$object,
    opt: true,
    def: 'list',
  );

  @override
  final MappableFields<BestieModelList> fields = const {
    #data: _f$data,
    #object: _f$object,
  };

  static BestieModelList _instantiate(DecodingData data) {
    return BestieModelList(
      data: data.dec(_f$data),
      object: data.dec(_f$object),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BestieModelList fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BestieModelList>(map);
  }

  static BestieModelList fromJson(String json) {
    return ensureInitialized().decodeJson<BestieModelList>(json);
  }
}

mixin BestieModelListMappable {
  String toJson() {
    return BestieModelListMapper.ensureInitialized()
        .encodeJson<BestieModelList>(this as BestieModelList);
  }

  Map<String, dynamic> toMap() {
    return BestieModelListMapper.ensureInitialized().encodeMap<BestieModelList>(
      this as BestieModelList,
    );
  }

  BestieModelListCopyWith<BestieModelList, BestieModelList, BestieModelList>
  get copyWith =>
      _BestieModelListCopyWithImpl<BestieModelList, BestieModelList>(
        this as BestieModelList,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BestieModelListMapper.ensureInitialized().stringifyValue(
      this as BestieModelList,
    );
  }

  @override
  bool operator ==(Object other) {
    return BestieModelListMapper.ensureInitialized().equalsValue(
      this as BestieModelList,
      other,
    );
  }

  @override
  int get hashCode {
    return BestieModelListMapper.ensureInitialized().hashValue(
      this as BestieModelList,
    );
  }
}

extension BestieModelListValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BestieModelList, $Out> {
  BestieModelListCopyWith<$R, BestieModelList, $Out> get $asBestieModelList =>
      $base.as((v, t, t2) => _BestieModelListCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BestieModelListCopyWith<$R, $In extends BestieModelList, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    BestieModel,
    BestieModelCopyWith<$R, BestieModel, BestieModel>
  >
  get data;
  $R call({List<BestieModel>? data, String? object});
  BestieModelListCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _BestieModelListCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BestieModelList, $Out>
    implements BestieModelListCopyWith<$R, BestieModelList, $Out> {
  _BestieModelListCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BestieModelList> $mapper =
      BestieModelListMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    BestieModel,
    BestieModelCopyWith<$R, BestieModel, BestieModel>
  >
  get data => ListCopyWith(
    $value.data,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(data: v),
  );
  @override
  $R call({List<BestieModel>? data, String? object}) => $apply(
    FieldCopyWithData({
      if (data != null) #data: data,
      if (object != null) #object: object,
    }),
  );
  @override
  BestieModelList $make(CopyWithData data) => BestieModelList(
    data: data.get(#data, or: $value.data),
    object: data.get(#object, or: $value.object),
  );

  @override
  BestieModelListCopyWith<$R2, BestieModelList, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BestieModelListCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class BestieModelMapper extends ClassMapperBase<BestieModel> {
  BestieModelMapper._();

  static BestieModelMapper? _instance;
  static BestieModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BestieModelMapper._());
      BestieModelFactsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'BestieModel';

  static String _$id(BestieModel v) => v.id;
  static const Field<BestieModel, String> _f$id = Field('id', _$id);
  static int _$contextLength(BestieModel v) => v.contextLength;
  static const Field<BestieModel, int> _f$contextLength = Field(
    'contextLength',
    _$contextLength,
    key: r'context_length',
  );
  static BestieModelFacts _$bestie(BestieModel v) => v.bestie;
  static const Field<BestieModel, BestieModelFacts> _f$bestie = Field(
    'bestie',
    _$bestie,
  );
  static int _$created(BestieModel v) => v.created;
  static const Field<BestieModel, int> _f$created = Field('created', _$created);
  static String _$object(BestieModel v) => v.object;
  static const Field<BestieModel, String> _f$object = Field(
    'object',
    _$object,
    opt: true,
    def: 'model',
  );
  static String _$ownedBy(BestieModel v) => v.ownedBy;
  static const Field<BestieModel, String> _f$ownedBy = Field(
    'ownedBy',
    _$ownedBy,
    key: r'owned_by',
    opt: true,
    def: 'bestie',
  );

  @override
  final MappableFields<BestieModel> fields = const {
    #id: _f$id,
    #contextLength: _f$contextLength,
    #bestie: _f$bestie,
    #created: _f$created,
    #object: _f$object,
    #ownedBy: _f$ownedBy,
  };

  static BestieModel _instantiate(DecodingData data) {
    return BestieModel(
      id: data.dec(_f$id),
      contextLength: data.dec(_f$contextLength),
      bestie: data.dec(_f$bestie),
      created: data.dec(_f$created),
      object: data.dec(_f$object),
      ownedBy: data.dec(_f$ownedBy),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BestieModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BestieModel>(map);
  }

  static BestieModel fromJson(String json) {
    return ensureInitialized().decodeJson<BestieModel>(json);
  }
}

mixin BestieModelMappable {
  String toJson() {
    return BestieModelMapper.ensureInitialized().encodeJson<BestieModel>(
      this as BestieModel,
    );
  }

  Map<String, dynamic> toMap() {
    return BestieModelMapper.ensureInitialized().encodeMap<BestieModel>(
      this as BestieModel,
    );
  }

  BestieModelCopyWith<BestieModel, BestieModel, BestieModel> get copyWith =>
      _BestieModelCopyWithImpl<BestieModel, BestieModel>(
        this as BestieModel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BestieModelMapper.ensureInitialized().stringifyValue(
      this as BestieModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return BestieModelMapper.ensureInitialized().equalsValue(
      this as BestieModel,
      other,
    );
  }

  @override
  int get hashCode {
    return BestieModelMapper.ensureInitialized().hashValue(this as BestieModel);
  }
}

extension BestieModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BestieModel, $Out> {
  BestieModelCopyWith<$R, BestieModel, $Out> get $asBestieModel =>
      $base.as((v, t, t2) => _BestieModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BestieModelCopyWith<$R, $In extends BestieModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  BestieModelFactsCopyWith<$R, BestieModelFacts, BestieModelFacts> get bestie;
  $R call({
    String? id,
    int? contextLength,
    BestieModelFacts? bestie,
    int? created,
    String? object,
    String? ownedBy,
  });
  BestieModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BestieModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BestieModel, $Out>
    implements BestieModelCopyWith<$R, BestieModel, $Out> {
  _BestieModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BestieModel> $mapper =
      BestieModelMapper.ensureInitialized();
  @override
  BestieModelFactsCopyWith<$R, BestieModelFacts, BestieModelFacts> get bestie =>
      $value.bestie.copyWith.$chain((v) => call(bestie: v));
  @override
  $R call({
    String? id,
    int? contextLength,
    BestieModelFacts? bestie,
    int? created,
    String? object,
    String? ownedBy,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (contextLength != null) #contextLength: contextLength,
      if (bestie != null) #bestie: bestie,
      if (created != null) #created: created,
      if (object != null) #object: object,
      if (ownedBy != null) #ownedBy: ownedBy,
    }),
  );
  @override
  BestieModel $make(CopyWithData data) => BestieModel(
    id: data.get(#id, or: $value.id),
    contextLength: data.get(#contextLength, or: $value.contextLength),
    bestie: data.get(#bestie, or: $value.bestie),
    created: data.get(#created, or: $value.created),
    object: data.get(#object, or: $value.object),
    ownedBy: data.get(#ownedBy, or: $value.ownedBy),
  );

  @override
  BestieModelCopyWith<$R2, BestieModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BestieModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class BestieModelFactsMapper extends ClassMapperBase<BestieModelFacts> {
  BestieModelFactsMapper._();

  static BestieModelFactsMapper? _instance;
  static BestieModelFactsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BestieModelFactsMapper._());
      ModelReasoningMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'BestieModelFacts';

  static bool _$loaded(BestieModelFacts v) => v.loaded;
  static const Field<BestieModelFacts, bool> _f$loaded = Field(
    'loaded',
    _$loaded,
  );
  static ModelReasoning _$reasoning(BestieModelFacts v) => v.reasoning;
  static const Field<BestieModelFacts, ModelReasoning> _f$reasoning = Field(
    'reasoning',
    _$reasoning,
  );
  static String _$displayName(BestieModelFacts v) => v.displayName;
  static const Field<BestieModelFacts, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    key: r'display_name',
  );
  static String _$fileType(BestieModelFacts v) => v.fileType;
  static const Field<BestieModelFacts, String> _f$fileType = Field(
    'fileType',
    _$fileType,
    key: r'file_type',
  );
  static int _$sizeBytes(BestieModelFacts v) => v.sizeBytes;
  static const Field<BestieModelFacts, int> _f$sizeBytes = Field(
    'sizeBytes',
    _$sizeBytes,
    key: r'size_bytes',
  );

  @override
  final MappableFields<BestieModelFacts> fields = const {
    #loaded: _f$loaded,
    #reasoning: _f$reasoning,
    #displayName: _f$displayName,
    #fileType: _f$fileType,
    #sizeBytes: _f$sizeBytes,
  };

  static BestieModelFacts _instantiate(DecodingData data) {
    return BestieModelFacts(
      loaded: data.dec(_f$loaded),
      reasoning: data.dec(_f$reasoning),
      displayName: data.dec(_f$displayName),
      fileType: data.dec(_f$fileType),
      sizeBytes: data.dec(_f$sizeBytes),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BestieModelFacts fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BestieModelFacts>(map);
  }

  static BestieModelFacts fromJson(String json) {
    return ensureInitialized().decodeJson<BestieModelFacts>(json);
  }
}

mixin BestieModelFactsMappable {
  String toJson() {
    return BestieModelFactsMapper.ensureInitialized()
        .encodeJson<BestieModelFacts>(this as BestieModelFacts);
  }

  Map<String, dynamic> toMap() {
    return BestieModelFactsMapper.ensureInitialized()
        .encodeMap<BestieModelFacts>(this as BestieModelFacts);
  }

  BestieModelFactsCopyWith<BestieModelFacts, BestieModelFacts, BestieModelFacts>
  get copyWith =>
      _BestieModelFactsCopyWithImpl<BestieModelFacts, BestieModelFacts>(
        this as BestieModelFacts,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BestieModelFactsMapper.ensureInitialized().stringifyValue(
      this as BestieModelFacts,
    );
  }

  @override
  bool operator ==(Object other) {
    return BestieModelFactsMapper.ensureInitialized().equalsValue(
      this as BestieModelFacts,
      other,
    );
  }

  @override
  int get hashCode {
    return BestieModelFactsMapper.ensureInitialized().hashValue(
      this as BestieModelFacts,
    );
  }
}

extension BestieModelFactsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BestieModelFacts, $Out> {
  BestieModelFactsCopyWith<$R, BestieModelFacts, $Out>
  get $asBestieModelFacts =>
      $base.as((v, t, t2) => _BestieModelFactsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BestieModelFactsCopyWith<$R, $In extends BestieModelFacts, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ModelReasoningCopyWith<$R, ModelReasoning, ModelReasoning> get reasoning;
  $R call({
    bool? loaded,
    ModelReasoning? reasoning,
    String? displayName,
    String? fileType,
    int? sizeBytes,
  });
  BestieModelFactsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _BestieModelFactsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BestieModelFacts, $Out>
    implements BestieModelFactsCopyWith<$R, BestieModelFacts, $Out> {
  _BestieModelFactsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BestieModelFacts> $mapper =
      BestieModelFactsMapper.ensureInitialized();
  @override
  ModelReasoningCopyWith<$R, ModelReasoning, ModelReasoning> get reasoning =>
      $value.reasoning.copyWith.$chain((v) => call(reasoning: v));
  @override
  $R call({
    bool? loaded,
    ModelReasoning? reasoning,
    String? displayName,
    String? fileType,
    int? sizeBytes,
  }) => $apply(
    FieldCopyWithData({
      if (loaded != null) #loaded: loaded,
      if (reasoning != null) #reasoning: reasoning,
      if (displayName != null) #displayName: displayName,
      if (fileType != null) #fileType: fileType,
      if (sizeBytes != null) #sizeBytes: sizeBytes,
    }),
  );
  @override
  BestieModelFacts $make(CopyWithData data) => BestieModelFacts(
    loaded: data.get(#loaded, or: $value.loaded),
    reasoning: data.get(#reasoning, or: $value.reasoning),
    displayName: data.get(#displayName, or: $value.displayName),
    fileType: data.get(#fileType, or: $value.fileType),
    sizeBytes: data.get(#sizeBytes, or: $value.sizeBytes),
  );

  @override
  BestieModelFactsCopyWith<$R2, BestieModelFacts, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BestieModelFactsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

