import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Physical memory totals in bytes.
final class MemoryStatus {
  const MemoryStatus({required this.totalBytes, required this.availableBytes});

  /// Total physical memory (`ullTotalPhys`).
  final int totalBytes;

  /// Physical memory available to this process (`ullAvailPhys`).
  final int availableBytes;
}

/// Reads physical memory via `GlobalMemoryStatusEx`.
class MemoryQuery {
  MemoryQuery(this._bindings);

  final WindowsBindings _bindings;

  /// Reads the current memory status.
  MemoryStatusResult status() {
    final buffer = calloc<MEMORYSTATUSEX>()
      ..ref.dwLength = sizeOf<MEMORYSTATUSEX>();
    try {
      if (_bindings.GlobalMemoryStatusEx(buffer) == 0) {
        return MemoryStatusFailed(
          Win32Failure.fromLastError(_bindings, 'GlobalMemoryStatusEx'),
        );
      }
      final status = buffer.ref;
      return MemoryStatusSucceeded(
        MemoryStatus(
          totalBytes: status.ullTotalPhys,
          availableBytes: status.ullAvailPhys,
        ),
      );
    } finally {
      calloc.free(buffer);
    }
  }
}

sealed class MemoryStatusResult {
  const MemoryStatusResult();
}

final class MemoryStatusSucceeded extends MemoryStatusResult {
  const MemoryStatusSucceeded(this.status);
  final MemoryStatus status;
}

final class MemoryStatusFailed extends MemoryStatusResult {
  const MemoryStatusFailed(this.failure);
  final Win32Failure failure;
}
