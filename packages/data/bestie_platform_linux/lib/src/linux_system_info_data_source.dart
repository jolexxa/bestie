import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:system_info2/system_info2.dart';

@dataSource
class LinuxSystemInfoDataSource implements SystemInfoDataSource {
  LinuxSystemInfoDataSource();

  @override
  SystemInfoSnapshot readSystemInfo() {
    return SystemInfoSnapshot(
      logicalCoreCount: SysInfo.cores.length,
      totalRamBytes: SysInfo.getTotalPhysicalMemory(),
      availableRamBytes: SysInfo.getAvailablePhysicalMemory(),
      // Unified memory on Linux is determined per-device from the backend
      // (an integrated GPU shares host memory), not at the platform level.
      platformAlwaysUnified: false,
    );
  }
}
