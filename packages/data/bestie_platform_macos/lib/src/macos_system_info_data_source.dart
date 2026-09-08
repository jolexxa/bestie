import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:system_info2/system_info2.dart';

int macOSTotalRamBytes() => posixSysctl.byNameInt64('hw.memsize') ?? 0;

/// Returns available system memory in bytes via Mach `host_statistics64`
/// plus a `hw.pagesize` sysctl read.
///
/// Computes available memory matching Activity Monitor:
///   used = (internal - purgeable + wired + compressor) × page_size
///   available = total_ram - used
///
/// Returns 0 on failure.
int macOSAvailableRamBytes() {
  final stats = posixMach.hostVmStatistics();
  if (stats == null) return 0;

  final pageSize = posixSysctl.byNameInt32('hw.pagesize');
  if (pageSize == null || pageSize <= 0) return 0;

  final total = macOSTotalRamBytes();
  final usedPages =
      stats.internalPageCount -
      stats.purgeableCount +
      stats.wireCount +
      stats.compressorPageCount;
  final used = usedPages * pageSize;
  final available = total - used;
  return available > 0 ? available : 0;
}

@dataSource
class MacOSSystemInfoDataSource implements SystemInfoDataSource {
  MacOSSystemInfoDataSource();

  @override
  SystemInfoSnapshot readSystemInfo() {
    return SystemInfoSnapshot(
      logicalCoreCount: SysInfo.cores.length,
      totalRamBytes: macOSTotalRamBytes(),
      availableRamBytes: macOSAvailableRamBytes(),
      platformAlwaysUnified: true,
    );
  }
}
