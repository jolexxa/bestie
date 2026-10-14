// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model.dart';

class HfModelMapper extends ClassMapperBase<HfModel> {
  HfModelMapper._();

  static HfModelMapper? _instance;
  static HfModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HfModelMapper._());
      MapperContainer.globals.useAll([GatedModeMapper()]);
      SiblingInfoMapper.ensureInitialized();
      HfGgufInfoMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HfModel';

  static String _$id(HfModel v) => v.id;
  static const Field<HfModel, String> _f$id = Field('id', _$id);
  static String? _$author(HfModel v) => v.author;
  static const Field<HfModel, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
  );
  static String? _$sha(HfModel v) => v.sha;
  static const Field<HfModel, String> _f$sha = Field('sha', _$sha, opt: true);
  static DateTime? _$lastModified(HfModel v) => v.lastModified;
  static const Field<HfModel, DateTime> _f$lastModified = Field(
    'lastModified',
    _$lastModified,
    opt: true,
  );
  static bool? _$isPrivate(HfModel v) => v.isPrivate;
  static const Field<HfModel, bool> _f$isPrivate = Field(
    'isPrivate',
    _$isPrivate,
    key: r'private',
    opt: true,
  );
  static GatedMode? _$gated(HfModel v) => v.gated;
  static const Field<HfModel, GatedMode> _f$gated = Field(
    'gated',
    _$gated,
    opt: true,
  );
  static bool? _$isDisabled(HfModel v) => v.isDisabled;
  static const Field<HfModel, bool> _f$isDisabled = Field(
    'isDisabled',
    _$isDisabled,
    key: r'disabled',
    opt: true,
  );
  static int? _$downloads(HfModel v) => v.downloads;
  static const Field<HfModel, int> _f$downloads = Field(
    'downloads',
    _$downloads,
    opt: true,
  );
  static int? _$likes(HfModel v) => v.likes;
  static const Field<HfModel, int> _f$likes = Field(
    'likes',
    _$likes,
    opt: true,
  );
  static String? _$library(HfModel v) => v.library;
  static const Field<HfModel, String> _f$library = Field(
    'library',
    _$library,
    key: r'library_name',
    opt: true,
  );
  static List<String>? _$tags(HfModel v) => v.tags;
  static const Field<HfModel, List<String>> _f$tags = Field(
    'tags',
    _$tags,
    opt: true,
  );
  static String? _$pipelineTag(HfModel v) => v.pipelineTag;
  static const Field<HfModel, String> _f$pipelineTag = Field(
    'pipelineTag',
    _$pipelineTag,
    key: r'pipeline_tag',
    opt: true,
  );
  static DateTime? _$createdAt(HfModel v) => v.createdAt;
  static const Field<HfModel, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    opt: true,
  );
  static int? _$downloadsAllTime(HfModel v) => v.downloadsAllTime;
  static const Field<HfModel, int> _f$downloadsAllTime = Field(
    'downloadsAllTime',
    _$downloadsAllTime,
    opt: true,
  );
  static int? _$trendingScore(HfModel v) => v.trendingScore;
  static const Field<HfModel, int> _f$trendingScore = Field(
    'trendingScore',
    _$trendingScore,
    opt: true,
  );
  static int? _$usedStorage(HfModel v) => v.usedStorage;
  static const Field<HfModel, int> _f$usedStorage = Field(
    'usedStorage',
    _$usedStorage,
    opt: true,
  );
  static List<SiblingInfo>? _$siblings(HfModel v) => v.siblings;
  static const Field<HfModel, List<SiblingInfo>> _f$siblings = Field(
    'siblings',
    _$siblings,
    opt: true,
  );
  static HfGgufInfo? _$gguf(HfModel v) => v.gguf;
  static const Field<HfModel, HfGgufInfo> _f$gguf = Field(
    'gguf',
    _$gguf,
    opt: true,
  );

  @override
  final MappableFields<HfModel> fields = const {
    #id: _f$id,
    #author: _f$author,
    #sha: _f$sha,
    #lastModified: _f$lastModified,
    #isPrivate: _f$isPrivate,
    #gated: _f$gated,
    #isDisabled: _f$isDisabled,
    #downloads: _f$downloads,
    #likes: _f$likes,
    #library: _f$library,
    #tags: _f$tags,
    #pipelineTag: _f$pipelineTag,
    #createdAt: _f$createdAt,
    #downloadsAllTime: _f$downloadsAllTime,
    #trendingScore: _f$trendingScore,
    #usedStorage: _f$usedStorage,
    #siblings: _f$siblings,
    #gguf: _f$gguf,
  };

  static HfModel _instantiate(DecodingData data) {
    return HfModel(
      id: data.dec(_f$id),
      author: data.dec(_f$author),
      sha: data.dec(_f$sha),
      lastModified: data.dec(_f$lastModified),
      isPrivate: data.dec(_f$isPrivate),
      gated: data.dec(_f$gated),
      isDisabled: data.dec(_f$isDisabled),
      downloads: data.dec(_f$downloads),
      likes: data.dec(_f$likes),
      library: data.dec(_f$library),
      tags: data.dec(_f$tags),
      pipelineTag: data.dec(_f$pipelineTag),
      createdAt: data.dec(_f$createdAt),
      downloadsAllTime: data.dec(_f$downloadsAllTime),
      trendingScore: data.dec(_f$trendingScore),
      usedStorage: data.dec(_f$usedStorage),
      siblings: data.dec(_f$siblings),
      gguf: data.dec(_f$gguf),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HfModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HfModel>(map);
  }

  static HfModel fromJson(String json) {
    return ensureInitialized().decodeJson<HfModel>(json);
  }
}

mixin HfModelMappable {
  String toJson() {
    return HfModelMapper.ensureInitialized().encodeJson<HfModel>(
      this as HfModel,
    );
  }

  Map<String, dynamic> toMap() {
    return HfModelMapper.ensureInitialized().encodeMap<HfModel>(
      this as HfModel,
    );
  }

  HfModelCopyWith<HfModel, HfModel, HfModel> get copyWith =>
      _HfModelCopyWithImpl<HfModel, HfModel>(
        this as HfModel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HfModelMapper.ensureInitialized().stringifyValue(this as HfModel);
  }

  @override
  bool operator ==(Object other) {
    return HfModelMapper.ensureInitialized().equalsValue(
      this as HfModel,
      other,
    );
  }

  @override
  int get hashCode {
    return HfModelMapper.ensureInitialized().hashValue(this as HfModel);
  }
}

extension HfModelValueCopy<$R, $Out> on ObjectCopyWith<$R, HfModel, $Out> {
  HfModelCopyWith<$R, HfModel, $Out> get $asHfModel =>
      $base.as((v, t, t2) => _HfModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HfModelCopyWith<$R, $In extends HfModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get tags;
  ListCopyWith<
    $R,
    SiblingInfo,
    SiblingInfoCopyWith<$R, SiblingInfo, SiblingInfo>
  >?
  get siblings;
  HfGgufInfoCopyWith<$R, HfGgufInfo, HfGgufInfo>? get gguf;
  $R call({
    String? id,
    String? author,
    String? sha,
    DateTime? lastModified,
    bool? isPrivate,
    GatedMode? gated,
    bool? isDisabled,
    int? downloads,
    int? likes,
    String? library,
    List<String>? tags,
    String? pipelineTag,
    DateTime? createdAt,
    int? downloadsAllTime,
    int? trendingScore,
    int? usedStorage,
    List<SiblingInfo>? siblings,
    HfGgufInfo? gguf,
  });
  HfModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HfModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HfModel, $Out>
    implements HfModelCopyWith<$R, HfModel, $Out> {
  _HfModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HfModel> $mapper =
      HfModelMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get tags =>
      $value.tags != null
      ? ListCopyWith(
          $value.tags!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(tags: v),
        )
      : null;
  @override
  ListCopyWith<
    $R,
    SiblingInfo,
    SiblingInfoCopyWith<$R, SiblingInfo, SiblingInfo>
  >?
  get siblings => $value.siblings != null
      ? ListCopyWith(
          $value.siblings!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(siblings: v),
        )
      : null;
  @override
  HfGgufInfoCopyWith<$R, HfGgufInfo, HfGgufInfo>? get gguf =>
      $value.gguf?.copyWith.$chain((v) => call(gguf: v));
  @override
  $R call({
    String? id,
    Object? author = $none,
    Object? sha = $none,
    Object? lastModified = $none,
    Object? isPrivate = $none,
    Object? gated = $none,
    Object? isDisabled = $none,
    Object? downloads = $none,
    Object? likes = $none,
    Object? library = $none,
    Object? tags = $none,
    Object? pipelineTag = $none,
    Object? createdAt = $none,
    Object? downloadsAllTime = $none,
    Object? trendingScore = $none,
    Object? usedStorage = $none,
    Object? siblings = $none,
    Object? gguf = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (author != $none) #author: author,
      if (sha != $none) #sha: sha,
      if (lastModified != $none) #lastModified: lastModified,
      if (isPrivate != $none) #isPrivate: isPrivate,
      if (gated != $none) #gated: gated,
      if (isDisabled != $none) #isDisabled: isDisabled,
      if (downloads != $none) #downloads: downloads,
      if (likes != $none) #likes: likes,
      if (library != $none) #library: library,
      if (tags != $none) #tags: tags,
      if (pipelineTag != $none) #pipelineTag: pipelineTag,
      if (createdAt != $none) #createdAt: createdAt,
      if (downloadsAllTime != $none) #downloadsAllTime: downloadsAllTime,
      if (trendingScore != $none) #trendingScore: trendingScore,
      if (usedStorage != $none) #usedStorage: usedStorage,
      if (siblings != $none) #siblings: siblings,
      if (gguf != $none) #gguf: gguf,
    }),
  );
  @override
  HfModel $make(CopyWithData data) => HfModel(
    id: data.get(#id, or: $value.id),
    author: data.get(#author, or: $value.author),
    sha: data.get(#sha, or: $value.sha),
    lastModified: data.get(#lastModified, or: $value.lastModified),
    isPrivate: data.get(#isPrivate, or: $value.isPrivate),
    gated: data.get(#gated, or: $value.gated),
    isDisabled: data.get(#isDisabled, or: $value.isDisabled),
    downloads: data.get(#downloads, or: $value.downloads),
    likes: data.get(#likes, or: $value.likes),
    library: data.get(#library, or: $value.library),
    tags: data.get(#tags, or: $value.tags),
    pipelineTag: data.get(#pipelineTag, or: $value.pipelineTag),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    downloadsAllTime: data.get(#downloadsAllTime, or: $value.downloadsAllTime),
    trendingScore: data.get(#trendingScore, or: $value.trendingScore),
    usedStorage: data.get(#usedStorage, or: $value.usedStorage),
    siblings: data.get(#siblings, or: $value.siblings),
    gguf: data.get(#gguf, or: $value.gguf),
  );

  @override
  HfModelCopyWith<$R2, HfModel, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _HfModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SiblingInfoMapper extends ClassMapperBase<SiblingInfo> {
  SiblingInfoMapper._();

  static SiblingInfoMapper? _instance;
  static SiblingInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SiblingInfoMapper._());
      LfsInfoMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SiblingInfo';

  static String _$relativeFilename(SiblingInfo v) => v.relativeFilename;
  static const Field<SiblingInfo, String> _f$relativeFilename = Field(
    'relativeFilename',
    _$relativeFilename,
    key: r'rfilename',
  );
  static int? _$size(SiblingInfo v) => v.size;
  static const Field<SiblingInfo, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
  );
  static String? _$blobId(SiblingInfo v) => v.blobId;
  static const Field<SiblingInfo, String> _f$blobId = Field(
    'blobId',
    _$blobId,
    opt: true,
  );
  static LfsInfo? _$lfs(SiblingInfo v) => v.lfs;
  static const Field<SiblingInfo, LfsInfo> _f$lfs = Field(
    'lfs',
    _$lfs,
    opt: true,
  );

  @override
  final MappableFields<SiblingInfo> fields = const {
    #relativeFilename: _f$relativeFilename,
    #size: _f$size,
    #blobId: _f$blobId,
    #lfs: _f$lfs,
  };

  static SiblingInfo _instantiate(DecodingData data) {
    return SiblingInfo(
      relativeFilename: data.dec(_f$relativeFilename),
      size: data.dec(_f$size),
      blobId: data.dec(_f$blobId),
      lfs: data.dec(_f$lfs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SiblingInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SiblingInfo>(map);
  }

  static SiblingInfo fromJson(String json) {
    return ensureInitialized().decodeJson<SiblingInfo>(json);
  }
}

mixin SiblingInfoMappable {
  String toJson() {
    return SiblingInfoMapper.ensureInitialized().encodeJson<SiblingInfo>(
      this as SiblingInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return SiblingInfoMapper.ensureInitialized().encodeMap<SiblingInfo>(
      this as SiblingInfo,
    );
  }

  SiblingInfoCopyWith<SiblingInfo, SiblingInfo, SiblingInfo> get copyWith =>
      _SiblingInfoCopyWithImpl<SiblingInfo, SiblingInfo>(
        this as SiblingInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SiblingInfoMapper.ensureInitialized().stringifyValue(
      this as SiblingInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    return SiblingInfoMapper.ensureInitialized().equalsValue(
      this as SiblingInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return SiblingInfoMapper.ensureInitialized().hashValue(this as SiblingInfo);
  }
}

extension SiblingInfoValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SiblingInfo, $Out> {
  SiblingInfoCopyWith<$R, SiblingInfo, $Out> get $asSiblingInfo =>
      $base.as((v, t, t2) => _SiblingInfoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SiblingInfoCopyWith<$R, $In extends SiblingInfo, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  LfsInfoCopyWith<$R, LfsInfo, LfsInfo>? get lfs;
  $R call({String? relativeFilename, int? size, String? blobId, LfsInfo? lfs});
  SiblingInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SiblingInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SiblingInfo, $Out>
    implements SiblingInfoCopyWith<$R, SiblingInfo, $Out> {
  _SiblingInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SiblingInfo> $mapper =
      SiblingInfoMapper.ensureInitialized();
  @override
  LfsInfoCopyWith<$R, LfsInfo, LfsInfo>? get lfs =>
      $value.lfs?.copyWith.$chain((v) => call(lfs: v));
  @override
  $R call({
    String? relativeFilename,
    Object? size = $none,
    Object? blobId = $none,
    Object? lfs = $none,
  }) => $apply(
    FieldCopyWithData({
      if (relativeFilename != null) #relativeFilename: relativeFilename,
      if (size != $none) #size: size,
      if (blobId != $none) #blobId: blobId,
      if (lfs != $none) #lfs: lfs,
    }),
  );
  @override
  SiblingInfo $make(CopyWithData data) => SiblingInfo(
    relativeFilename: data.get(#relativeFilename, or: $value.relativeFilename),
    size: data.get(#size, or: $value.size),
    blobId: data.get(#blobId, or: $value.blobId),
    lfs: data.get(#lfs, or: $value.lfs),
  );

  @override
  SiblingInfoCopyWith<$R2, SiblingInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SiblingInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LfsInfoMapper extends ClassMapperBase<LfsInfo> {
  LfsInfoMapper._();

  static LfsInfoMapper? _instance;
  static LfsInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LfsInfoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LfsInfo';

  static String _$sha256(LfsInfo v) => v.sha256;
  static const Field<LfsInfo, String> _f$sha256 = Field('sha256', _$sha256);
  static int _$size(LfsInfo v) => v.size;
  static const Field<LfsInfo, int> _f$size = Field('size', _$size);
  static int? _$pointerSize(LfsInfo v) => v.pointerSize;
  static const Field<LfsInfo, int> _f$pointerSize = Field(
    'pointerSize',
    _$pointerSize,
    opt: true,
  );

  @override
  final MappableFields<LfsInfo> fields = const {
    #sha256: _f$sha256,
    #size: _f$size,
    #pointerSize: _f$pointerSize,
  };

  static LfsInfo _instantiate(DecodingData data) {
    return LfsInfo(
      sha256: data.dec(_f$sha256),
      size: data.dec(_f$size),
      pointerSize: data.dec(_f$pointerSize),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LfsInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LfsInfo>(map);
  }

  static LfsInfo fromJson(String json) {
    return ensureInitialized().decodeJson<LfsInfo>(json);
  }
}

mixin LfsInfoMappable {
  String toJson() {
    return LfsInfoMapper.ensureInitialized().encodeJson<LfsInfo>(
      this as LfsInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return LfsInfoMapper.ensureInitialized().encodeMap<LfsInfo>(
      this as LfsInfo,
    );
  }

  LfsInfoCopyWith<LfsInfo, LfsInfo, LfsInfo> get copyWith =>
      _LfsInfoCopyWithImpl<LfsInfo, LfsInfo>(
        this as LfsInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LfsInfoMapper.ensureInitialized().stringifyValue(this as LfsInfo);
  }

  @override
  bool operator ==(Object other) {
    return LfsInfoMapper.ensureInitialized().equalsValue(
      this as LfsInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return LfsInfoMapper.ensureInitialized().hashValue(this as LfsInfo);
  }
}

extension LfsInfoValueCopy<$R, $Out> on ObjectCopyWith<$R, LfsInfo, $Out> {
  LfsInfoCopyWith<$R, LfsInfo, $Out> get $asLfsInfo =>
      $base.as((v, t, t2) => _LfsInfoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LfsInfoCopyWith<$R, $In extends LfsInfo, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? sha256, int? size, int? pointerSize});
  LfsInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LfsInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LfsInfo, $Out>
    implements LfsInfoCopyWith<$R, LfsInfo, $Out> {
  _LfsInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LfsInfo> $mapper =
      LfsInfoMapper.ensureInitialized();
  @override
  $R call({String? sha256, int? size, Object? pointerSize = $none}) => $apply(
    FieldCopyWithData({
      if (sha256 != null) #sha256: sha256,
      if (size != null) #size: size,
      if (pointerSize != $none) #pointerSize: pointerSize,
    }),
  );
  @override
  LfsInfo $make(CopyWithData data) => LfsInfo(
    sha256: data.get(#sha256, or: $value.sha256),
    size: data.get(#size, or: $value.size),
    pointerSize: data.get(#pointerSize, or: $value.pointerSize),
  );

  @override
  LfsInfoCopyWith<$R2, LfsInfo, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LfsInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class HfGgufInfoMapper extends ClassMapperBase<HfGgufInfo> {
  HfGgufInfoMapper._();

  static HfGgufInfoMapper? _instance;
  static HfGgufInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HfGgufInfoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'HfGgufInfo';

  static int? _$total(HfGgufInfo v) => v.total;
  static const Field<HfGgufInfo, int> _f$total = Field(
    'total',
    _$total,
    opt: true,
  );
  static String? _$architecture(HfGgufInfo v) => v.architecture;
  static const Field<HfGgufInfo, String> _f$architecture = Field(
    'architecture',
    _$architecture,
    opt: true,
  );
  static int? _$contextLength(HfGgufInfo v) => v.contextLength;
  static const Field<HfGgufInfo, int> _f$contextLength = Field(
    'contextLength',
    _$contextLength,
    key: r'context_length',
    opt: true,
  );
  static String? _$chatTemplate(HfGgufInfo v) => v.chatTemplate;
  static const Field<HfGgufInfo, String> _f$chatTemplate = Field(
    'chatTemplate',
    _$chatTemplate,
    key: r'chat_template',
    opt: true,
  );

  @override
  final MappableFields<HfGgufInfo> fields = const {
    #total: _f$total,
    #architecture: _f$architecture,
    #contextLength: _f$contextLength,
    #chatTemplate: _f$chatTemplate,
  };

  static HfGgufInfo _instantiate(DecodingData data) {
    return HfGgufInfo(
      total: data.dec(_f$total),
      architecture: data.dec(_f$architecture),
      contextLength: data.dec(_f$contextLength),
      chatTemplate: data.dec(_f$chatTemplate),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HfGgufInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HfGgufInfo>(map);
  }

  static HfGgufInfo fromJson(String json) {
    return ensureInitialized().decodeJson<HfGgufInfo>(json);
  }
}

mixin HfGgufInfoMappable {
  String toJson() {
    return HfGgufInfoMapper.ensureInitialized().encodeJson<HfGgufInfo>(
      this as HfGgufInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return HfGgufInfoMapper.ensureInitialized().encodeMap<HfGgufInfo>(
      this as HfGgufInfo,
    );
  }

  HfGgufInfoCopyWith<HfGgufInfo, HfGgufInfo, HfGgufInfo> get copyWith =>
      _HfGgufInfoCopyWithImpl<HfGgufInfo, HfGgufInfo>(
        this as HfGgufInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HfGgufInfoMapper.ensureInitialized().stringifyValue(
      this as HfGgufInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    return HfGgufInfoMapper.ensureInitialized().equalsValue(
      this as HfGgufInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return HfGgufInfoMapper.ensureInitialized().hashValue(this as HfGgufInfo);
  }
}

extension HfGgufInfoValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HfGgufInfo, $Out> {
  HfGgufInfoCopyWith<$R, HfGgufInfo, $Out> get $asHfGgufInfo =>
      $base.as((v, t, t2) => _HfGgufInfoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HfGgufInfoCopyWith<$R, $In extends HfGgufInfo, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? total,
    String? architecture,
    int? contextLength,
    String? chatTemplate,
  });
  HfGgufInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HfGgufInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HfGgufInfo, $Out>
    implements HfGgufInfoCopyWith<$R, HfGgufInfo, $Out> {
  _HfGgufInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HfGgufInfo> $mapper =
      HfGgufInfoMapper.ensureInitialized();
  @override
  $R call({
    Object? total = $none,
    Object? architecture = $none,
    Object? contextLength = $none,
    Object? chatTemplate = $none,
  }) => $apply(
    FieldCopyWithData({
      if (total != $none) #total: total,
      if (architecture != $none) #architecture: architecture,
      if (contextLength != $none) #contextLength: contextLength,
      if (chatTemplate != $none) #chatTemplate: chatTemplate,
    }),
  );
  @override
  HfGgufInfo $make(CopyWithData data) => HfGgufInfo(
    total: data.get(#total, or: $value.total),
    architecture: data.get(#architecture, or: $value.architecture),
    contextLength: data.get(#contextLength, or: $value.contextLength),
    chatTemplate: data.get(#chatTemplate, or: $value.chatTemplate),
  );

  @override
  HfGgufInfoCopyWith<$R2, HfGgufInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HfGgufInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

