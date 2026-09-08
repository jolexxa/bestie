import 'package:bestie_platform_abstractions/src/abstractions/system_info_provider.dart';
import 'package:bestie_platform_abstractions/src/models/memory_stat.dart';
import 'package:intentions/intentions.dart';

/// Pure snapshot of system resource information.
@model
class SystemInfoSnapshot implements SystemInfoProvider {
  const SystemInfoSnapshot({
    required this.logicalCoreCount,
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.platformAlwaysUnified,
  });

  @override
  final int logicalCoreCount;
  @override
  final int totalRamBytes;
  @override
  final int availableRamBytes;
  @override
  final bool platformAlwaysUnified;

  /// RAM usage derived from this snapshot.
  MemoryStat get ramStat {
    if (totalRamBytes <= 0) {
      return const MemoryStat(usedBytes: 0, totalBytes: 0, availablePercent: 0);
    }
    final used = totalRamBytes - availableRamBytes;
    final percent = (availableRamBytes * 100 / totalRamBytes).round().clamp(
      0,
      100,
    );
    return MemoryStat(
      usedBytes: used,
      totalBytes: totalRamBytes,
      availablePercent: percent,
    );
  }
}
