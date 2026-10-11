// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'block_stat.dart';

class BlockStatMapper extends ClassMapperBase<BlockStat> {
  BlockStatMapper._();

  static BlockStatMapper? _instance;
  static BlockStatMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BlockStatMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BlockStat';

  static DateTime _$startedAt(BlockStat v) => v.startedAt;
  static const Field<BlockStat, DateTime> _f$startedAt = Field(
    'startedAt',
    _$startedAt,
  );
  static DateTime _$endedAt(BlockStat v) => v.endedAt;
  static const Field<BlockStat, DateTime> _f$endedAt = Field(
    'endedAt',
    _$endedAt,
  );
  static int? _$tokenCount(BlockStat v) => v.tokenCount;
  static const Field<BlockStat, int> _f$tokenCount = Field(
    'tokenCount',
    _$tokenCount,
    opt: true,
  );

  @override
  final MappableFields<BlockStat> fields = const {
    #startedAt: _f$startedAt,
    #endedAt: _f$endedAt,
    #tokenCount: _f$tokenCount,
  };

  static BlockStat _instantiate(DecodingData data) {
    return BlockStat(
      startedAt: data.dec(_f$startedAt),
      endedAt: data.dec(_f$endedAt),
      tokenCount: data.dec(_f$tokenCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BlockStat fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BlockStat>(map);
  }

  static BlockStat fromJson(String json) {
    return ensureInitialized().decodeJson<BlockStat>(json);
  }
}

mixin BlockStatMappable {
  String toJson() {
    return BlockStatMapper.ensureInitialized().encodeJson<BlockStat>(
      this as BlockStat,
    );
  }

  Map<String, dynamic> toMap() {
    return BlockStatMapper.ensureInitialized().encodeMap<BlockStat>(
      this as BlockStat,
    );
  }

  BlockStatCopyWith<BlockStat, BlockStat, BlockStat> get copyWith =>
      _BlockStatCopyWithImpl<BlockStat, BlockStat>(
        this as BlockStat,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BlockStatMapper.ensureInitialized().stringifyValue(
      this as BlockStat,
    );
  }

  @override
  bool operator ==(Object other) {
    return BlockStatMapper.ensureInitialized().equalsValue(
      this as BlockStat,
      other,
    );
  }

  @override
  int get hashCode {
    return BlockStatMapper.ensureInitialized().hashValue(this as BlockStat);
  }
}

extension BlockStatValueCopy<$R, $Out> on ObjectCopyWith<$R, BlockStat, $Out> {
  BlockStatCopyWith<$R, BlockStat, $Out> get $asBlockStat =>
      $base.as((v, t, t2) => _BlockStatCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BlockStatCopyWith<$R, $In extends BlockStat, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({DateTime? startedAt, DateTime? endedAt, int? tokenCount});
  BlockStatCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BlockStatCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BlockStat, $Out>
    implements BlockStatCopyWith<$R, BlockStat, $Out> {
  _BlockStatCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BlockStat> $mapper =
      BlockStatMapper.ensureInitialized();
  @override
  $R call({
    DateTime? startedAt,
    DateTime? endedAt,
    Object? tokenCount = $none,
  }) => $apply(
    FieldCopyWithData({
      if (startedAt != null) #startedAt: startedAt,
      if (endedAt != null) #endedAt: endedAt,
      if (tokenCount != $none) #tokenCount: tokenCount,
    }),
  );
  @override
  BlockStat $make(CopyWithData data) => BlockStat(
    startedAt: data.get(#startedAt, or: $value.startedAt),
    endedAt: data.get(#endedAt, or: $value.endedAt),
    tokenCount: data.get(#tokenCount, or: $value.tokenCount),
  );

  @override
  BlockStatCopyWith<$R2, BlockStat, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BlockStatCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

