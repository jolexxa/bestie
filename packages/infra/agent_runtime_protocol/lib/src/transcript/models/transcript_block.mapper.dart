// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transcript_block.dart';

class TranscriptBlockMapper extends ClassMapperBase<TranscriptBlock> {
  TranscriptBlockMapper._();

  static TranscriptBlockMapper? _instance;
  static TranscriptBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptBlockMapper._());
      TranscriptParagraphBlockMapper.ensureInitialized();
      TranscriptToolOutputBlockMapper.ensureInitialized();
      TranscriptReasoningBlockMapper.ensureInitialized();
      TranscriptToolCallBlockMapper.ensureInitialized();
      TranscriptToolCallResponseBlockMapper.ensureInitialized();
      TranscriptSummaryBlockMapper.ensureInitialized();
      TranscriptBlockIdMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptBlock';

  static TranscriptBlockId _$id(TranscriptBlock v) => v.id;
  static const Field<TranscriptBlock, TranscriptBlockId> _f$id = Field(
    'id',
    _$id,
  );
  static BlockStat? _$stat(TranscriptBlock v) => v.stat;
  static const Field<TranscriptBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );

  @override
  final MappableFields<TranscriptBlock> fields = const {
    #id: _f$id,
    #stat: _f$stat,
  };

  static TranscriptBlock _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'TranscriptBlock',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptBlock>(map);
  }

  static TranscriptBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptBlock>(json);
  }
}

mixin TranscriptBlockMappable {
  String toJson();
  Map<String, dynamic> toMap();
  TranscriptBlockCopyWith<TranscriptBlock, TranscriptBlock, TranscriptBlock>
  get copyWith;
}

abstract class TranscriptBlockCopyWith<$R, $In extends TranscriptBlock, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  $R call({TranscriptBlockId? id, BlockStat? stat});
  TranscriptBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class TranscriptParagraphBlockMapper
    extends SubClassMapperBase<TranscriptParagraphBlock> {
  TranscriptParagraphBlockMapper._();

  static TranscriptParagraphBlockMapper? _instance;
  static TranscriptParagraphBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TranscriptParagraphBlockMapper._(),
      );
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptParagraphBlock';

  static TranscriptBlockId _$id(TranscriptParagraphBlock v) => v.id;
  static const Field<TranscriptParagraphBlock, TranscriptBlockId> _f$id = Field(
    'id',
    _$id,
  );
  static String _$text(TranscriptParagraphBlock v) => v.text;
  static const Field<TranscriptParagraphBlock, String> _f$text = Field(
    'text',
    _$text,
  );
  static BlockStat? _$stat(TranscriptParagraphBlock v) => v.stat;
  static const Field<TranscriptParagraphBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );

  @override
  final MappableFields<TranscriptParagraphBlock> fields = const {
    #id: _f$id,
    #text: _f$text,
    #stat: _f$stat,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'paragraph';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptParagraphBlock _instantiate(DecodingData data) {
    return TranscriptParagraphBlock(
      id: data.dec(_f$id),
      text: data.dec(_f$text),
      stat: data.dec(_f$stat),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptParagraphBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptParagraphBlock>(map);
  }

  static TranscriptParagraphBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptParagraphBlock>(json);
  }
}

mixin TranscriptParagraphBlockMappable {
  String toJson() {
    return TranscriptParagraphBlockMapper.ensureInitialized()
        .encodeJson<TranscriptParagraphBlock>(this as TranscriptParagraphBlock);
  }

  Map<String, dynamic> toMap() {
    return TranscriptParagraphBlockMapper.ensureInitialized()
        .encodeMap<TranscriptParagraphBlock>(this as TranscriptParagraphBlock);
  }

  TranscriptParagraphBlockCopyWith<
    TranscriptParagraphBlock,
    TranscriptParagraphBlock,
    TranscriptParagraphBlock
  >
  get copyWith =>
      _TranscriptParagraphBlockCopyWithImpl<
        TranscriptParagraphBlock,
        TranscriptParagraphBlock
      >(this as TranscriptParagraphBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptParagraphBlockMapper.ensureInitialized().stringifyValue(
      this as TranscriptParagraphBlock,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptParagraphBlockMapper.ensureInitialized().equalsValue(
      this as TranscriptParagraphBlock,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptParagraphBlockMapper.ensureInitialized().hashValue(
      this as TranscriptParagraphBlock,
    );
  }
}

extension TranscriptParagraphBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptParagraphBlock, $Out> {
  TranscriptParagraphBlockCopyWith<$R, TranscriptParagraphBlock, $Out>
  get $asTranscriptParagraphBlock => $base.as(
    (v, t, t2) => _TranscriptParagraphBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptParagraphBlockCopyWith<
  $R,
  $In extends TranscriptParagraphBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({TranscriptBlockId? id, String? text, BlockStat? stat});
  TranscriptParagraphBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptParagraphBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptParagraphBlock, $Out>
    implements
        TranscriptParagraphBlockCopyWith<$R, TranscriptParagraphBlock, $Out> {
  _TranscriptParagraphBlockCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptParagraphBlock> $mapper =
      TranscriptParagraphBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({TranscriptBlockId? id, String? text, Object? stat = $none}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (text != null) #text: text,
          if (stat != $none) #stat: stat,
        }),
      );
  @override
  TranscriptParagraphBlock $make(CopyWithData data) => TranscriptParagraphBlock(
    id: data.get(#id, or: $value.id),
    text: data.get(#text, or: $value.text),
    stat: data.get(#stat, or: $value.stat),
  );

  @override
  TranscriptParagraphBlockCopyWith<$R2, TranscriptParagraphBlock, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptParagraphBlockCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptToolOutputBlockMapper
    extends SubClassMapperBase<TranscriptToolOutputBlock> {
  TranscriptToolOutputBlockMapper._();

  static TranscriptToolOutputBlockMapper? _instance;
  static TranscriptToolOutputBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TranscriptToolOutputBlockMapper._(),
      );
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptToolOutputBlock';

  static TranscriptBlockId _$id(TranscriptToolOutputBlock v) => v.id;
  static const Field<TranscriptToolOutputBlock, TranscriptBlockId> _f$id =
      Field('id', _$id);
  static String _$text(TranscriptToolOutputBlock v) => v.text;
  static const Field<TranscriptToolOutputBlock, String> _f$text = Field(
    'text',
    _$text,
  );
  static BlockStat? _$stat(TranscriptToolOutputBlock v) => v.stat;
  static const Field<TranscriptToolOutputBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );

  @override
  final MappableFields<TranscriptToolOutputBlock> fields = const {
    #id: _f$id,
    #text: _f$text,
    #stat: _f$stat,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'tool_output';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptToolOutputBlock _instantiate(DecodingData data) {
    return TranscriptToolOutputBlock(
      id: data.dec(_f$id),
      text: data.dec(_f$text),
      stat: data.dec(_f$stat),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptToolOutputBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptToolOutputBlock>(map);
  }

  static TranscriptToolOutputBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptToolOutputBlock>(json);
  }
}

mixin TranscriptToolOutputBlockMappable {
  String toJson() {
    return TranscriptToolOutputBlockMapper.ensureInitialized()
        .encodeJson<TranscriptToolOutputBlock>(
          this as TranscriptToolOutputBlock,
        );
  }

  Map<String, dynamic> toMap() {
    return TranscriptToolOutputBlockMapper.ensureInitialized()
        .encodeMap<TranscriptToolOutputBlock>(
          this as TranscriptToolOutputBlock,
        );
  }

  TranscriptToolOutputBlockCopyWith<
    TranscriptToolOutputBlock,
    TranscriptToolOutputBlock,
    TranscriptToolOutputBlock
  >
  get copyWith =>
      _TranscriptToolOutputBlockCopyWithImpl<
        TranscriptToolOutputBlock,
        TranscriptToolOutputBlock
      >(this as TranscriptToolOutputBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptToolOutputBlockMapper.ensureInitialized().stringifyValue(
      this as TranscriptToolOutputBlock,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptToolOutputBlockMapper.ensureInitialized().equalsValue(
      this as TranscriptToolOutputBlock,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptToolOutputBlockMapper.ensureInitialized().hashValue(
      this as TranscriptToolOutputBlock,
    );
  }
}

extension TranscriptToolOutputBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptToolOutputBlock, $Out> {
  TranscriptToolOutputBlockCopyWith<$R, TranscriptToolOutputBlock, $Out>
  get $asTranscriptToolOutputBlock => $base.as(
    (v, t, t2) => _TranscriptToolOutputBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptToolOutputBlockCopyWith<
  $R,
  $In extends TranscriptToolOutputBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({TranscriptBlockId? id, String? text, BlockStat? stat});
  TranscriptToolOutputBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptToolOutputBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptToolOutputBlock, $Out>
    implements
        TranscriptToolOutputBlockCopyWith<$R, TranscriptToolOutputBlock, $Out> {
  _TranscriptToolOutputBlockCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptToolOutputBlock> $mapper =
      TranscriptToolOutputBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({TranscriptBlockId? id, String? text, Object? stat = $none}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (text != null) #text: text,
          if (stat != $none) #stat: stat,
        }),
      );
  @override
  TranscriptToolOutputBlock $make(CopyWithData data) =>
      TranscriptToolOutputBlock(
        id: data.get(#id, or: $value.id),
        text: data.get(#text, or: $value.text),
        stat: data.get(#stat, or: $value.stat),
      );

  @override
  TranscriptToolOutputBlockCopyWith<$R2, TranscriptToolOutputBlock, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptToolOutputBlockCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptReasoningBlockMapper
    extends SubClassMapperBase<TranscriptReasoningBlock> {
  TranscriptReasoningBlockMapper._();

  static TranscriptReasoningBlockMapper? _instance;
  static TranscriptReasoningBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TranscriptReasoningBlockMapper._(),
      );
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptReasoningBlock';

  static TranscriptBlockId _$id(TranscriptReasoningBlock v) => v.id;
  static const Field<TranscriptReasoningBlock, TranscriptBlockId> _f$id = Field(
    'id',
    _$id,
  );
  static String _$text(TranscriptReasoningBlock v) => v.text;
  static const Field<TranscriptReasoningBlock, String> _f$text = Field(
    'text',
    _$text,
  );
  static BlockStat? _$stat(TranscriptReasoningBlock v) => v.stat;
  static const Field<TranscriptReasoningBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );

  @override
  final MappableFields<TranscriptReasoningBlock> fields = const {
    #id: _f$id,
    #text: _f$text,
    #stat: _f$stat,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'reasoning';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptReasoningBlock _instantiate(DecodingData data) {
    return TranscriptReasoningBlock(
      id: data.dec(_f$id),
      text: data.dec(_f$text),
      stat: data.dec(_f$stat),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptReasoningBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptReasoningBlock>(map);
  }

  static TranscriptReasoningBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptReasoningBlock>(json);
  }
}

mixin TranscriptReasoningBlockMappable {
  String toJson() {
    return TranscriptReasoningBlockMapper.ensureInitialized()
        .encodeJson<TranscriptReasoningBlock>(this as TranscriptReasoningBlock);
  }

  Map<String, dynamic> toMap() {
    return TranscriptReasoningBlockMapper.ensureInitialized()
        .encodeMap<TranscriptReasoningBlock>(this as TranscriptReasoningBlock);
  }

  TranscriptReasoningBlockCopyWith<
    TranscriptReasoningBlock,
    TranscriptReasoningBlock,
    TranscriptReasoningBlock
  >
  get copyWith =>
      _TranscriptReasoningBlockCopyWithImpl<
        TranscriptReasoningBlock,
        TranscriptReasoningBlock
      >(this as TranscriptReasoningBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptReasoningBlockMapper.ensureInitialized().stringifyValue(
      this as TranscriptReasoningBlock,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptReasoningBlockMapper.ensureInitialized().equalsValue(
      this as TranscriptReasoningBlock,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptReasoningBlockMapper.ensureInitialized().hashValue(
      this as TranscriptReasoningBlock,
    );
  }
}

extension TranscriptReasoningBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptReasoningBlock, $Out> {
  TranscriptReasoningBlockCopyWith<$R, TranscriptReasoningBlock, $Out>
  get $asTranscriptReasoningBlock => $base.as(
    (v, t, t2) => _TranscriptReasoningBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptReasoningBlockCopyWith<
  $R,
  $In extends TranscriptReasoningBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({TranscriptBlockId? id, String? text, BlockStat? stat});
  TranscriptReasoningBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptReasoningBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptReasoningBlock, $Out>
    implements
        TranscriptReasoningBlockCopyWith<$R, TranscriptReasoningBlock, $Out> {
  _TranscriptReasoningBlockCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptReasoningBlock> $mapper =
      TranscriptReasoningBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({TranscriptBlockId? id, String? text, Object? stat = $none}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (text != null) #text: text,
          if (stat != $none) #stat: stat,
        }),
      );
  @override
  TranscriptReasoningBlock $make(CopyWithData data) => TranscriptReasoningBlock(
    id: data.get(#id, or: $value.id),
    text: data.get(#text, or: $value.text),
    stat: data.get(#stat, or: $value.stat),
  );

  @override
  TranscriptReasoningBlockCopyWith<$R2, TranscriptReasoningBlock, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptReasoningBlockCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptToolCallBlockMapper
    extends SubClassMapperBase<TranscriptToolCallBlock> {
  TranscriptToolCallBlockMapper._();

  static TranscriptToolCallBlockMapper? _instance;
  static TranscriptToolCallBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TranscriptToolCallBlockMapper._(),
      );
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      ToolCallMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptToolCallBlock';

  static TranscriptBlockId _$id(TranscriptToolCallBlock v) => v.id;
  static const Field<TranscriptToolCallBlock, TranscriptBlockId> _f$id = Field(
    'id',
    _$id,
  );
  static ToolCall _$toolCall(TranscriptToolCallBlock v) => v.toolCall;
  static const Field<TranscriptToolCallBlock, ToolCall> _f$toolCall = Field(
    'toolCall',
    _$toolCall,
  );
  static BlockStat? _$stat(TranscriptToolCallBlock v) => v.stat;
  static const Field<TranscriptToolCallBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );
  static String? _$labelTemplate(TranscriptToolCallBlock v) => v.labelTemplate;
  static const Field<TranscriptToolCallBlock, String> _f$labelTemplate = Field(
    'labelTemplate',
    _$labelTemplate,
    opt: true,
  );

  @override
  final MappableFields<TranscriptToolCallBlock> fields = const {
    #id: _f$id,
    #toolCall: _f$toolCall,
    #stat: _f$stat,
    #labelTemplate: _f$labelTemplate,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'tool_call';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptToolCallBlock _instantiate(DecodingData data) {
    return TranscriptToolCallBlock(
      id: data.dec(_f$id),
      toolCall: data.dec(_f$toolCall),
      stat: data.dec(_f$stat),
      labelTemplate: data.dec(_f$labelTemplate),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptToolCallBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptToolCallBlock>(map);
  }

  static TranscriptToolCallBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptToolCallBlock>(json);
  }
}

mixin TranscriptToolCallBlockMappable {
  String toJson() {
    return TranscriptToolCallBlockMapper.ensureInitialized()
        .encodeJson<TranscriptToolCallBlock>(this as TranscriptToolCallBlock);
  }

  Map<String, dynamic> toMap() {
    return TranscriptToolCallBlockMapper.ensureInitialized()
        .encodeMap<TranscriptToolCallBlock>(this as TranscriptToolCallBlock);
  }

  TranscriptToolCallBlockCopyWith<
    TranscriptToolCallBlock,
    TranscriptToolCallBlock,
    TranscriptToolCallBlock
  >
  get copyWith =>
      _TranscriptToolCallBlockCopyWithImpl<
        TranscriptToolCallBlock,
        TranscriptToolCallBlock
      >(this as TranscriptToolCallBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptToolCallBlockMapper.ensureInitialized().stringifyValue(
      this as TranscriptToolCallBlock,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptToolCallBlockMapper.ensureInitialized().equalsValue(
      this as TranscriptToolCallBlock,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptToolCallBlockMapper.ensureInitialized().hashValue(
      this as TranscriptToolCallBlock,
    );
  }
}

extension TranscriptToolCallBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptToolCallBlock, $Out> {
  TranscriptToolCallBlockCopyWith<$R, TranscriptToolCallBlock, $Out>
  get $asTranscriptToolCallBlock => $base.as(
    (v, t, t2) => _TranscriptToolCallBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptToolCallBlockCopyWith<
  $R,
  $In extends TranscriptToolCallBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  ToolCallCopyWith<$R, ToolCall, ToolCall> get toolCall;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({
    TranscriptBlockId? id,
    ToolCall? toolCall,
    BlockStat? stat,
    String? labelTemplate,
  });
  TranscriptToolCallBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptToolCallBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptToolCallBlock, $Out>
    implements
        TranscriptToolCallBlockCopyWith<$R, TranscriptToolCallBlock, $Out> {
  _TranscriptToolCallBlockCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptToolCallBlock> $mapper =
      TranscriptToolCallBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  ToolCallCopyWith<$R, ToolCall, ToolCall> get toolCall =>
      $value.toolCall.copyWith.$chain((v) => call(toolCall: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({
    TranscriptBlockId? id,
    ToolCall? toolCall,
    Object? stat = $none,
    Object? labelTemplate = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (toolCall != null) #toolCall: toolCall,
      if (stat != $none) #stat: stat,
      if (labelTemplate != $none) #labelTemplate: labelTemplate,
    }),
  );
  @override
  TranscriptToolCallBlock $make(CopyWithData data) => TranscriptToolCallBlock(
    id: data.get(#id, or: $value.id),
    toolCall: data.get(#toolCall, or: $value.toolCall),
    stat: data.get(#stat, or: $value.stat),
    labelTemplate: data.get(#labelTemplate, or: $value.labelTemplate),
  );

  @override
  TranscriptToolCallBlockCopyWith<$R2, TranscriptToolCallBlock, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptToolCallBlockCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TranscriptToolCallResponseBlockMapper
    extends SubClassMapperBase<TranscriptToolCallResponseBlock> {
  TranscriptToolCallResponseBlockMapper._();

  static TranscriptToolCallResponseBlockMapper? _instance;
  static TranscriptToolCallResponseBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TranscriptToolCallResponseBlockMapper._(),
      );
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      ToolCallResponseMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptToolCallResponseBlock';

  static TranscriptBlockId _$id(TranscriptToolCallResponseBlock v) => v.id;
  static const Field<TranscriptToolCallResponseBlock, TranscriptBlockId> _f$id =
      Field('id', _$id);
  static ToolCallResponse _$response(TranscriptToolCallResponseBlock v) =>
      v.response;
  static const Field<TranscriptToolCallResponseBlock, ToolCallResponse>
  _f$response = Field('response', _$response);
  static BlockStat? _$stat(TranscriptToolCallResponseBlock v) => v.stat;
  static const Field<TranscriptToolCallResponseBlock, BlockStat> _f$stat =
      Field('stat', _$stat, opt: true);

  @override
  final MappableFields<TranscriptToolCallResponseBlock> fields = const {
    #id: _f$id,
    #response: _f$response,
    #stat: _f$stat,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'tool_response';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptToolCallResponseBlock _instantiate(DecodingData data) {
    return TranscriptToolCallResponseBlock(
      id: data.dec(_f$id),
      response: data.dec(_f$response),
      stat: data.dec(_f$stat),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptToolCallResponseBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptToolCallResponseBlock>(map);
  }

  static TranscriptToolCallResponseBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptToolCallResponseBlock>(
      json,
    );
  }
}

mixin TranscriptToolCallResponseBlockMappable {
  String toJson() {
    return TranscriptToolCallResponseBlockMapper.ensureInitialized()
        .encodeJson<TranscriptToolCallResponseBlock>(
          this as TranscriptToolCallResponseBlock,
        );
  }

  Map<String, dynamic> toMap() {
    return TranscriptToolCallResponseBlockMapper.ensureInitialized()
        .encodeMap<TranscriptToolCallResponseBlock>(
          this as TranscriptToolCallResponseBlock,
        );
  }

  TranscriptToolCallResponseBlockCopyWith<
    TranscriptToolCallResponseBlock,
    TranscriptToolCallResponseBlock,
    TranscriptToolCallResponseBlock
  >
  get copyWith =>
      _TranscriptToolCallResponseBlockCopyWithImpl<
        TranscriptToolCallResponseBlock,
        TranscriptToolCallResponseBlock
      >(this as TranscriptToolCallResponseBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptToolCallResponseBlockMapper.ensureInitialized()
        .stringifyValue(this as TranscriptToolCallResponseBlock);
  }

  @override
  bool operator ==(Object other) {
    return TranscriptToolCallResponseBlockMapper.ensureInitialized()
        .equalsValue(this as TranscriptToolCallResponseBlock, other);
  }

  @override
  int get hashCode {
    return TranscriptToolCallResponseBlockMapper.ensureInitialized().hashValue(
      this as TranscriptToolCallResponseBlock,
    );
  }
}

extension TranscriptToolCallResponseBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptToolCallResponseBlock, $Out> {
  TranscriptToolCallResponseBlockCopyWith<
    $R,
    TranscriptToolCallResponseBlock,
    $Out
  >
  get $asTranscriptToolCallResponseBlock => $base.as(
    (v, t, t2) =>
        _TranscriptToolCallResponseBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptToolCallResponseBlockCopyWith<
  $R,
  $In extends TranscriptToolCallResponseBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  ToolCallResponseCopyWith<$R, ToolCallResponse, ToolCallResponse> get response;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({TranscriptBlockId? id, ToolCallResponse? response, BlockStat? stat});
  TranscriptToolCallResponseBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptToolCallResponseBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptToolCallResponseBlock, $Out>
    implements
        TranscriptToolCallResponseBlockCopyWith<
          $R,
          TranscriptToolCallResponseBlock,
          $Out
        > {
  _TranscriptToolCallResponseBlockCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<TranscriptToolCallResponseBlock> $mapper =
      TranscriptToolCallResponseBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  ToolCallResponseCopyWith<$R, ToolCallResponse, ToolCallResponse>
  get response => $value.response.copyWith.$chain((v) => call(response: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({
    TranscriptBlockId? id,
    ToolCallResponse? response,
    Object? stat = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (response != null) #response: response,
      if (stat != $none) #stat: stat,
    }),
  );
  @override
  TranscriptToolCallResponseBlock $make(CopyWithData data) =>
      TranscriptToolCallResponseBlock(
        id: data.get(#id, or: $value.id),
        response: data.get(#response, or: $value.response),
        stat: data.get(#stat, or: $value.stat),
      );

  @override
  TranscriptToolCallResponseBlockCopyWith<
    $R2,
    TranscriptToolCallResponseBlock,
    $Out2
  >
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptToolCallResponseBlockCopyWithImpl<$R2, $Out2>(
        $value,
        $cast,
        t,
      );
}

class TranscriptSummaryBlockMapper
    extends SubClassMapperBase<TranscriptSummaryBlock> {
  TranscriptSummaryBlockMapper._();

  static TranscriptSummaryBlockMapper? _instance;
  static TranscriptSummaryBlockMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptSummaryBlockMapper._());
      TranscriptBlockMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptBlockIdMapper.ensureInitialized();
      BlockStatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TranscriptSummaryBlock';

  static TranscriptBlockId _$id(TranscriptSummaryBlock v) => v.id;
  static const Field<TranscriptSummaryBlock, TranscriptBlockId> _f$id = Field(
    'id',
    _$id,
  );
  static String _$text(TranscriptSummaryBlock v) => v.text;
  static const Field<TranscriptSummaryBlock, String> _f$text = Field(
    'text',
    _$text,
  );
  static BlockStat? _$stat(TranscriptSummaryBlock v) => v.stat;
  static const Field<TranscriptSummaryBlock, BlockStat> _f$stat = Field(
    'stat',
    _$stat,
    opt: true,
  );

  @override
  final MappableFields<TranscriptSummaryBlock> fields = const {
    #id: _f$id,
    #text: _f$text,
    #stat: _f$stat,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'summary';
  @override
  late final ClassMapperBase superMapper =
      TranscriptBlockMapper.ensureInitialized();

  static TranscriptSummaryBlock _instantiate(DecodingData data) {
    return TranscriptSummaryBlock(
      id: data.dec(_f$id),
      text: data.dec(_f$text),
      stat: data.dec(_f$stat),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TranscriptSummaryBlock fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TranscriptSummaryBlock>(map);
  }

  static TranscriptSummaryBlock fromJson(String json) {
    return ensureInitialized().decodeJson<TranscriptSummaryBlock>(json);
  }
}

mixin TranscriptSummaryBlockMappable {
  String toJson() {
    return TranscriptSummaryBlockMapper.ensureInitialized()
        .encodeJson<TranscriptSummaryBlock>(this as TranscriptSummaryBlock);
  }

  Map<String, dynamic> toMap() {
    return TranscriptSummaryBlockMapper.ensureInitialized()
        .encodeMap<TranscriptSummaryBlock>(this as TranscriptSummaryBlock);
  }

  TranscriptSummaryBlockCopyWith<
    TranscriptSummaryBlock,
    TranscriptSummaryBlock,
    TranscriptSummaryBlock
  >
  get copyWith =>
      _TranscriptSummaryBlockCopyWithImpl<
        TranscriptSummaryBlock,
        TranscriptSummaryBlock
      >(this as TranscriptSummaryBlock, $identity, $identity);
  @override
  String toString() {
    return TranscriptSummaryBlockMapper.ensureInitialized().stringifyValue(
      this as TranscriptSummaryBlock,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptSummaryBlockMapper.ensureInitialized().equalsValue(
      this as TranscriptSummaryBlock,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptSummaryBlockMapper.ensureInitialized().hashValue(
      this as TranscriptSummaryBlock,
    );
  }
}

extension TranscriptSummaryBlockValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TranscriptSummaryBlock, $Out> {
  TranscriptSummaryBlockCopyWith<$R, TranscriptSummaryBlock, $Out>
  get $asTranscriptSummaryBlock => $base.as(
    (v, t, t2) => _TranscriptSummaryBlockCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TranscriptSummaryBlockCopyWith<
  $R,
  $In extends TranscriptSummaryBlock,
  $Out
>
    implements TranscriptBlockCopyWith<$R, $In, $Out> {
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id;
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat;
  @override
  $R call({TranscriptBlockId? id, String? text, BlockStat? stat});
  TranscriptSummaryBlockCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TranscriptSummaryBlockCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TranscriptSummaryBlock, $Out>
    implements
        TranscriptSummaryBlockCopyWith<$R, TranscriptSummaryBlock, $Out> {
  _TranscriptSummaryBlockCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TranscriptSummaryBlock> $mapper =
      TranscriptSummaryBlockMapper.ensureInitialized();
  @override
  TranscriptBlockIdCopyWith<$R, TranscriptBlockId, TranscriptBlockId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  BlockStatCopyWith<$R, BlockStat, BlockStat>? get stat =>
      $value.stat?.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({TranscriptBlockId? id, String? text, Object? stat = $none}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (text != null) #text: text,
          if (stat != $none) #stat: stat,
        }),
      );
  @override
  TranscriptSummaryBlock $make(CopyWithData data) => TranscriptSummaryBlock(
    id: data.get(#id, or: $value.id),
    text: data.get(#text, or: $value.text),
    stat: data.get(#stat, or: $value.stat),
  );

  @override
  TranscriptSummaryBlockCopyWith<$R2, TranscriptSummaryBlock, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TranscriptSummaryBlockCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

