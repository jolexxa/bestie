import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings/macos_bindings.dart'
    as macos
    show HOST_VM_INFO64, HOST_VM_INFO64_COUNT, vm_statistics64;
import 'package:posix_dart/src/bindings_api.dart';

/// Snapshot of mach VM stats useful for "available memory"
/// calculations. Field names match Apple's `vm_statistics64`. Counts
/// are in pages — multiply by [PosixSysctl.byNameInt32('hw.pagesize')]
/// to get bytes.
class MachVmStatistics {
  const MachVmStatistics({
    required this.freeCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.wireCount,
    required this.internalPageCount,
    required this.purgeableCount,
    required this.compressorPageCount,
  });

  final int freeCount;
  final int activeCount;
  final int inactiveCount;
  final int wireCount;
  final int internalPageCount;
  final int purgeableCount;
  final int compressorPageCount;
}

/// Darwin-only wrappers around mach's host-statistics APIs.
class PosixMach {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  PosixMach({DarwinBindings? bindings}) : _b = bindings ?? darwinBindings;

  final DarwinBindings _b;

  /// Reads mach VM statistics via `host_statistics64`. Returns `null`
  /// on failure.
  MachVmStatistics? hostVmStatistics() {
    final stats = calloc<macos.vm_statistics64>();
    final count = calloc<ffi.Uint32>();
    try {
      count.value = macos.HOST_VM_INFO64_COUNT;
      final port = _b.mach_host_self();
      final rc = _b.host_statistics64(
        port,
        macos.HOST_VM_INFO64,
        stats.cast<ffi.Int>(),
        count.cast<ffi.UnsignedInt>(),
      );
      if (rc != 0) return null;

      final s = stats.ref;
      return MachVmStatistics(
        freeCount: s.free_count,
        activeCount: s.active_count,
        inactiveCount: s.inactive_count,
        wireCount: s.wire_count,
        internalPageCount: s.internal_page_count,
        purgeableCount: s.purgeable_count,
        compressorPageCount: s.compressor_page_count,
      );
    } finally {
      calloc
        ..free(stats)
        ..free(count);
    }
  }
}

/// [PosixMach] over the host's libc.
final PosixMach posixMach = PosixMach();
