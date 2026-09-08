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
    final n = tokenCount;
    final ms = elapsedMs;
    if (n == null || ms <= 0) return null;
    return n / (ms / 1000);
  }
}
