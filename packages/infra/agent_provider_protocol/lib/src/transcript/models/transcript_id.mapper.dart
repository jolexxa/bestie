// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transcript_id.dart';

class TranscriptIdMapper extends ClassMapperBase<TranscriptId> {
  TranscriptIdMapper._();

  static TranscriptIdMapper? _instance;
  static TranscriptIdMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptIdMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptId';

  static UuidValue _$value(TranscriptId v) => v.value;
  static const Field<TranscriptId, UuidValue> _f$value = Field(
    'value',
    _$value,
  );

  @override
  final MappableFields<TranscriptId> fields = const {#value: _f$value};

  @override
  final MappingHook hook = const TranscriptIdHook();
  static TranscriptId _instantiate(DecodingData data) {
    return TranscriptId(data.dec(_f$value));
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptId fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptId>(map);
  }

  static TranscriptId fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptId>(json);
  }
}

mixin TranscriptIdMappable {
  String toJson() {
    return TranscriptIdMapper.ensureInitialized().encodeJson<TranscriptId>(
      this as TranscriptId,
    );
  }

  Map<String, dynamic> toMap() {
    return TranscriptIdMapper.ensureInitialized().encodeMap<TranscriptId>(
      this as TranscriptId,
    );
  }

  TranscriptIdCopyWith<TranscriptId, TranscriptId, TranscriptId> get copyWith =>
      _TranscriptIdCopyWithImpl<TranscriptId, TranscriptId>(
        this as TranscriptId,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptIdMapper.ensureInitialized().stringifyValue(
      this as TranscriptId,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptIdMapper.ensureInitialized().equalsValue(
      this as TranscriptId,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptIdMapper.ensureInitialized().hashValue(
      this as TranscriptId,
    );
  }
}

extension TranscriptIdValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptId, $Out> {
  TranscriptIdCopyWith<$R, TranscriptId, $Out> get $asTranscriptId =>
      $base.as((v, t, t2) => _TranscriptIdCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TranscriptIdCopyWith<$R, $In extends TranscriptId, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({UuidValue? value});
  TranscriptIdCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TranscriptIdCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptId, $Out>
    implements TranscriptIdCopyWith<$R, TranscriptId, $Out> {
  _TranscriptIdCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptId> $mapper =
      TranscriptIdMapper.ensureInitialized();
  @override
  $R call({UuidValue? value}) =>
      $apply(FieldCopyWithData({if (value != null) #value: value}));
  @override
  TranscriptId $make(CopyWithData data) =>
      TranscriptId(data.get(#value, or: $value.value));

  @override
  TranscriptIdCopyWith<$R2, TranscriptId, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptIdCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptEntryIdMapper extends ClassMapperBase<TranscriptEntryId> {
  TranscriptEntryIdMapper._();

  static TranscriptEntryIdMapper? _instance;
  static TranscriptEntryIdMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptEntryIdMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptEntryId';

  static UuidValue _$value(TranscriptEntryId v) => v.value;
  static const Field<TranscriptEntryId, UuidValue> _f$value = Field(
    'value',
    _$value,
  );

  @override
  final MappableFields<TranscriptEntryId> fields = const {#value: _f$value};

  @override
  final MappingHook hook = const TranscriptEntryIdHook();
  static TranscriptEntryId _instantiate(DecodingData data) {
    return TranscriptEntryId(data.dec(_f$value));
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptEntryId fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptEntryId>(map);
  }

  static TranscriptEntryId fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptEntryId>(json);
  }
}

mixin TranscriptEntryIdMappable {
  String toJson() {
    return TranscriptEntryIdMapper.ensureInitialized()
        .encodeJson<TranscriptEntryId>(this as TranscriptEntryId);
  }

  Map<String, dynamic> toMap() {
    return TranscriptEntryIdMapper.ensureInitialized()
        .encodeMap<TranscriptEntryId>(this as TranscriptEntryId);
  }

  TranscriptEntryIdCopyWith<
    TranscriptEntryId,
    TranscriptEntryId,
    TranscriptEntryId
  >
  get copyWith =>
      _TranscriptEntryIdCopyWithImpl<TranscriptEntryId, TranscriptEntryId>(
        this as TranscriptEntryId,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptEntryIdMapper.ensureInitialized().stringifyValue(
      this as TranscriptEntryId,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptEntryIdMapper.ensureInitialized().equalsValue(
      this as TranscriptEntryId,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptEntryIdMapper.ensureInitialized().hashValue(
      this as TranscriptEntryId,
    );
  }
}

extension TranscriptEntryIdValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptEntryId, $Out> {
  TranscriptEntryIdCopyWith<$R, TranscriptEntryId, $Out>
  get $asTranscriptEntryId => $base.as(
    (v, t, t2) => _TranscriptEntryIdCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptEntryIdCopyWith<
  $R,
  $In extends TranscriptEntryId,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({UuidValue? value});
  TranscriptEntryIdCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptEntryIdCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptEntryId, $Out>
    implements TranscriptEntryIdCopyWith<$R, TranscriptEntryId, $Out> {
  _TranscriptEntryIdCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptEntryId> $mapper =
      TranscriptEntryIdMapper.ensureInitialized();
  @override
  $R call({UuidValue? value}) =>
      $apply(FieldCopyWithData({if (value != null) #value: value}));
  @override
  TranscriptEntryId $make(CopyWithData data) =>
      TranscriptEntryId(data.get(#value, or: $value.value));

  @override
  TranscriptEntryIdCopyWith<$R2, TranscriptEntryId, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptEntryIdCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptBlockIdMapper extends ClassMapperBase<TranscriptBlockId> {
  TranscriptBlockIdMapper._();

  static TranscriptBlockIdMapper? _instance;
  static TranscriptBlockIdMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptBlockIdMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptBlockId';

  static UuidValue _$value(TranscriptBlockId v) => v.value;
  static const Field<TranscriptBlockId, UuidValue> _f$value = Field(
    'value',
    _$value,
  );

  @override
  final MappableFields<TranscriptBlockId> fields = const {#value: _f$value};

  @override
  final MappingHook hook = const TranscriptBlockIdHook();
  static TranscriptBlockId _instantiate(DecodingData data) {
    return TranscriptBlockId(data.dec(_f$value));
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptBlockId fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptBlockId>(map);
  }

  static TranscriptBlockId fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptBlockId>(json);
  }
}

mixin TranscriptBlockIdMappable {
  String toJson() {
    return TranscriptBlockIdMapper.ensureInitialized()
        .encodeJson<TranscriptBlockId>(this as TranscriptBlockId);
  }

  Map<String, dynamic> toMap() {
    return TranscriptBlockIdMapper.ensureInitialized()
        .encodeMap<TranscriptBlockId>(this as TranscriptBlockId);
  }

  TranscriptBlockIdCopyWith<
    TranscriptBlockId,
    TranscriptBlockId,
    TranscriptBlockId
  >
  get copyWith =>
      _TranscriptBlockIdCopyWithImpl<TranscriptBlockId, TranscriptBlockId>(
        this as TranscriptBlockId,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptBlockIdMapper.ensureInitialized().stringifyValue(
      this as TranscriptBlockId,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptBlockIdMapper.ensureInitialized().equalsValue(
      this as TranscriptBlockId,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptBlockIdMapper.ensureInitialized().hashValue(
      this as TranscriptBlockId,
    );
  }
}

extension TranscriptBlockIdValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptBlockId, $Out> {
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, $Out>
  get $asTranscriptBlockId => $base.as(
    (v, t, t2) => _TranscriptBlockIdCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptBlockIdCopyWith<
  $R,
  $In extends TranscriptBlockId,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({UuidValue? value});
  TranscriptBlockIdCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptBlockIdCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptBlockId, $Out>
    implements TranscriptBlockIdCopyWith<$R, TranscriptBlockId, $Out> {
  _TranscriptBlockIdCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptBlockId> $mapper =
      TranscriptBlockIdMapper.ensureInitialized();
  @override
  $R call({UuidValue? value}) =>
      $apply(FieldCopyWithData({if (value != null) #value: value}));
  @override
  TranscriptBlockId $make(CopyWithData data) =>
      TranscriptBlockId(data.get(#value, or: $value.value));

  @override
  TranscriptBlockIdCopyWith<$R2, TranscriptBlockId, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptBlockIdCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptBlockRefMapper extends ClassMapperBase<TranscriptBlockRef> {
  TranscriptBlockRefMapper._();

  static TranscriptBlockRefMapper? _instance;
  static TranscriptBlockRefMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptBlockRefMapper._());
      TranscriptEntryIdMapper.ensureInitialized();
      TranscriptBlockIdMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptBlockRef';

  static TranscriptEntryId _$entryId(TranscriptBlockRef v) => v.entryId;
  static const Field<TranscriptBlockRef, TranscriptEntryId> _f$entryId = Field(
    'entryId',
    _$entryId,
  );
  static TranscriptBlockId _$blockId(TranscriptBlockRef v) => v.blockId;
  static const Field<TranscriptBlockRef, TranscriptBlockId> _f$blockId = Field(
    'blockId',
    _$blockId,
  );

  @override
  final MappableFields<TranscriptBlockRef> fields = const {
    #entryId: _f$entryId,
    #blockId: _f$blockId,
  };

  static TranscriptBlockRef _instantiate(DecodingData data) {
    return TranscriptBlockRef(
      entryId: data.dec(_f$entryId),
      blockId: data.dec(_f$blockId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptBlockRef fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptBlockRef>(map);
  }

  static TranscriptBlockRef fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptBlockRef>(json);
  }
}

mixin TranscriptBlockRefMappable {
  String toJson() {
    return TranscriptBlockRefMapper.ensureInitialized()
        .encodeJson<TranscriptBlockRef>(this as TranscriptBlockRef);
  }

  Map<String, dynamic> toMap() {
    return TranscriptBlockRefMapper.ensureInitialized()
        .encodeMap<TranscriptBlockRef>(this as TranscriptBlockRef);
  }

  TranscriptBlockRefCopyWith<
    TranscriptBlockRef,
    TranscriptBlockRef,
    TranscriptBlockRef
  >
  get copyWith =>
      _TranscriptBlockRefCopyWithImpl<TranscriptBlockRef, TranscriptBlockRef>(
        this as TranscriptBlockRef,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptBlockRefMapper.ensureInitialized().stringifyValue(
      this as TranscriptBlockRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptBlockRefMapper.ensureInitialized().equalsValue(
      this as TranscriptBlockRef,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptBlockRefMapper.ensureInitialized().hashValue(
      this as TranscriptBlockRef,
    );
  }
}

extension TranscriptBlockRefValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptBlockRef, $Out> {
  TranscriptBlockRefCopyWith<$R, TranscriptBlockRef, $Out>
  get $asTranscriptBlockRef => $base.as(
    (v, t, t2) => _TranscriptBlockRefCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptBlockRefCopyWith<
  $R,
  $In extends TranscriptBlockRef,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  TranscriptEntryIdCopyWith<$R, TranscriptEntryId, TranscriptEntryId>
  get entryId;
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId>
  get blockId;
  $R call({TranscriptEntryId? entryId, TranscriptBlockId? blockId});
  TranscriptBlockRefCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptBlockRefCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptBlockRef, $Out>
    implements TranscriptBlockRefCopyWith<$R, TranscriptBlockRef, $Out> {
  _TranscriptBlockRefCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptBlockRef> $mapper =
      TranscriptBlockRefMapper.ensureInitialized();
  @override
  TranscriptEntryIdCopyWith<$R, TranscriptEntryId, TranscriptEntryId>
  get entryId => $value.entryId.copyWith.$chain((v) => call(entryId: v));
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId>
  get blockId => $value.blockId.copyWith.$chain((v) => call(blockId: v));
  @override
  $R call({TranscriptEntryId? entryId, TranscriptBlockId? blockId}) => $apply(
    FieldCopyWithData({
      if (entryId != null) #entryId: entryId,
      if (blockId != null) #blockId: blockId,
    }),
  );
  @override
  TranscriptBlockRef $make(CopyWithData data) => TranscriptBlockRef(
    entryId: data.get(#entryId, or: $value.entryId),
    blockId: data.get(#blockId, or: $value.blockId),
  );

  @override
  TranscriptBlockRefCopyWith<$R2, TranscriptBlockRef, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptBlockRefCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

