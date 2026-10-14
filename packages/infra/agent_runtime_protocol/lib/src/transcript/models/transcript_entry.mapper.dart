// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transcript_entry.dart';

class TranscriptEntryMapper extends ClassMapperBase<TranscriptEntry> {
  TranscriptEntryMapper._();

  static TranscriptEntryMapper? _instance;
  static TranscriptEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptEntryMapper._());
      TranscriptEntryIdMapper.ensureInitialized();
      RoleMapper.ensureInitialized();
      TranscriptBlockMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptEntry';

  static TranscriptEntryId _$id(TranscriptEntry v) => v.id;
  static const Field<TranscriptEntry, TranscriptEntryId> _f$id = Field(
    'id',
    _$id,
  );
  static Role _$role(TranscriptEntry v) => v.role;
  static const Field<TranscriptEntry, Role> _f$role = Field('role', _$role);
  static List<TranscriptBlock> _$blocks(TranscriptEntry v) => v.blocks;
  static const Field<TranscriptEntry, List<TranscriptBlock>> _f$blocks = Field(
    'blocks',
    _$blocks,
  );
  static String? _$name(TranscriptEntry v) => v.name;
  static const Field<TranscriptEntry, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );

  @override
  final MappableFields<TranscriptEntry> fields = const {
    #id: _f$id,
    #role: _f$role,
    #blocks: _f$blocks,
    #name: _f$name,
  };

  static TranscriptEntry _instantiate(DecodingData data) {
    return TranscriptEntry(
      id: data.dec(_f$id),
      role: data.dec(_f$role),
      blocks: data.dec(_f$blocks),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptEntry>(map);
  }

  static TranscriptEntry fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptEntry>(json);
  }
}

mixin TranscriptEntryMappable {
  String toJson() {
    return TranscriptEntryMapper.ensureInitialized()
        .encodeJson<TranscriptEntry>(this as TranscriptEntry);
  }

  Map<String, dynamic> toMap() {
    return TranscriptEntryMapper.ensureInitialized().encodeMap<TranscriptEntry>(
      this as TranscriptEntry,
    );
  }

  TranscriptEntryCopyWith<TranscriptEntry, TranscriptEntry, TranscriptEntry>
  get copyWith =>
      _TranscriptEntryCopyWithImpl<TranscriptEntry, TranscriptEntry>(
        this as TranscriptEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptEntryMapper.ensureInitialized().stringifyValue(
      this as TranscriptEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptEntryMapper.ensureInitialized().equalsValue(
      this as TranscriptEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptEntryMapper.ensureInitialized().hashValue(
      this as TranscriptEntry,
    );
  }
}

extension TranscriptEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptEntry, $Out> {
  TranscriptEntryCopyWith<$R, TranscriptEntry, $Out> get $asTranscriptEntry =>
      $base.as((v, t, t2) => _TranscriptEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TranscriptEntryCopyWith<$R, $In extends TranscriptEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  TranscriptEntryIdCopyWith<$R, TranscriptEntryId, TranscriptEntryId> get id;
  ListCopyWith<
    $R,
    TranscriptBlock,
    TranscriptBlockCopyWith<$R, TranscriptBlock, TranscriptBlock>
  >
  get blocks;
  $R call({
    TranscriptEntryId? id,
    Role? role,
    List<TranscriptBlock>? blocks,
    String? name,
  });
  TranscriptEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptEntry, $Out>
    implements TranscriptEntryCopyWith<$R, TranscriptEntry, $Out> {
  _TranscriptEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptEntry> $mapper =
      TranscriptEntryMapper.ensureInitialized();
  @override
  TranscriptEntryIdCopyWith<$R, TranscriptEntryId, TranscriptEntryId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  ListCopyWith<
    $R,
    TranscriptBlock,
    TranscriptBlockCopyWith<$R, TranscriptBlock, TranscriptBlock>
  >
  get blocks => ListCopyWith(
    $value.blocks,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(blocks: v),
  );
  @override
  $R call({
    TranscriptEntryId? id,
    Role? role,
    List<TranscriptBlock>? blocks,
    Object? name = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (role != null) #role: role,
      if (blocks != null) #blocks: blocks,
      if (name != $none) #name: name,
    }),
  );
  @override
  TranscriptEntry $make(CopyWithData data) => TranscriptEntry(
    id: data.get(#id, or: $value.id),
    role: data.get(#role, or: $value.role),
    blocks: data.get(#blocks, or: $value.blocks),
    name: data.get(#name, or: $value.name),
  );

  @override
  TranscriptEntryCopyWith<$R2, TranscriptEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

