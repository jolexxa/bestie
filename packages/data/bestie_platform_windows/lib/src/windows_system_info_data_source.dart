import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

/// Reads memory and processor counts straight from Win32.
@dataSource
class WindowsSystemInfoDataSource implements SystemInfoDataSource {
  /// [memory] and [processors] default to the host's Win32 surface; pass
  /// them to substitute doubles.
  WindowsSystemInfoDataSource({
    MemoryQuery? memory,
    ProcessorQuery? processors,
  }) : _memory = memory ?? MemoryQuery(win32),
       _processors = processors ?? ProcessorQuery(win32);

  final MemoryQuery _memory;
  final ProcessorQuery _processors;

  @override
  SystemInfoSnapshot readSystemInfo() {
    final cores = switch (_processors.activeCount()) {
      ProcessorCountSucceeded(:final count) => count,
      ProcessorCountFailed() => 1,
    };
    final memory = switch (_memory.status()) {
      MemoryStatusSucceeded(:final status) => status,
      MemoryStatusFailed() => null,
    };

    return SystemInfoSnapshot(
      logicalCoreCount: cores,
      totalRamBytes: memory?.totalBytes ?? 0,
      availableRamBytes: memory?.availableBytes ?? 0,
      platformAlwaysUnified: false,
    );
  }
}
