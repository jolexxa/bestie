import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:system_info2/system_info2.dart';

/// Reads memory from Mach and sysctl.
@dataSource
class MacOSSystemInfoDataSource implements SystemInfoDataSource {
  /// [mach] and [sysctl] default to the host's libc; pass them to substitute
  /// doubles.
  MacOSSystemInfoDataSource({PosixMach? mach, PosixSysctl? sysctl})
    : _mach = mach ?? posixMach,
      _sysctl = sysctl ?? posixSysctl;

  final PosixMach _mach;
  final PosixSysctl _sysctl;

  @override
  SystemInfoSnapshot readSystemInfo() {
    final total = _sysctl.byNameInt64('hw.memsize') ?? 0;
    return SystemInfoSnapshot(
      logicalCoreCount: SysInfo.cores.length,
      totalRamBytes: total,
      availableRamBytes: _availableBytes(total),
      platformAlwaysUnified: true,
    );
  }

  /// Memory the kernel counts as free or reclaimable before it reports
  /// pressure: free (speculative included), active and inactive pages. Wired
  /// pages and the compressor's pages are never available.
  int _availableBytes(int total) {
    final stats = _mach.hostVmStatistics();
    if (stats == null) return 0;
    final pageSize = _sysctl.byNameInt32('hw.pagesize') ?? 0;
    final pages = stats.freeCount + stats.activeCount + stats.inactiveCount;
    return (pages * pageSize).clamp(0, total);
  }
}
