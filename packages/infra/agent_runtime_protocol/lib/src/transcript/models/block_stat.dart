import 'package:dart_mappable/dart_mappable.dart';

part 'block_stat.mapper.dart';

/// Timing and token facts for a single transcript block.
@MappableClass()
final class BlockStat with BlockStatMappable {
  const BlockStat({
    required this.startedAt,
    required this.endedAt,
    this.tokenCount,
  });

  /// When the block's first content was produced.
  final DateTime startedAt;

  /// When the block's last content was produced.
  final DateTime endedAt;

  /// Tokens the model decoded to produce this block.
  final int? tokenCount;

  int get elapsedMs => endedAt.difference(startedAt).inMilliseconds;

  double? get tokensPerSecond {
    final tokens = tokenCount;
    final ms = elapsedMs;
    if (tokens == null || ms <= 0) return null;
    return tokens / (ms / 1000);
  }

  /// The stat spanning both this and [other], carrying both token counts.
  BlockStat merge(BlockStat other) {
    final tokens = (tokenCount ?? 0) + (other.tokenCount ?? 0);
    return BlockStat(
      startedAt: startedAt.isBefore(other.startedAt)
          ? startedAt
          : other.startedAt,
      endedAt: endedAt.isAfter(other.endedAt) ? endedAt : other.endedAt,
      tokenCount: tokens > 0 ? tokens : null,
    );
  }
}

extension MergedBlockStats on Iterable<BlockStat?> {
  /// The stat spanning every known stat here; null when none is known.
  BlockStat? get merged => nonNulls.fold<BlockStat?>(
    null,
    (merged, next) => merged?.merge(next) ?? next,
  );
}
