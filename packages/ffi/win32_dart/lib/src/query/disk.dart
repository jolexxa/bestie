import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Free space on the volume containing a path, in bytes.
final class DiskSpace {
  const DiskSpace({
    required this.availableBytes,
    required this.totalBytes,
    required this.freeBytes,
  });

  /// Bytes available to the calling user, after any disk quota.
  final int availableBytes;

  /// Total bytes on the volume.
  final int totalBytes;

  /// Free bytes on the volume, ignoring quotas.
  final int freeBytes;
}

/// Reads free space via `GetDiskFreeSpaceExW`.
class DiskQuery {
  DiskQuery(this._bindings);

  final WindowsBindings _bindings;

  /// Reads free space for the volume containing [path].
  DiskSpaceResult space(String path) {
    final available = calloc<ULARGE_INTEGER>();
    final total = calloc<ULARGE_INTEGER>();
    final free = calloc<ULARGE_INTEGER>();
    try {
      final ok = withWideString(
        path,
        (directory) =>
            _bindings.GetDiskFreeSpaceExW(directory, available, total, free),
      );
      if (ok == 0) {
        return DiskSpaceFailed(
          Win32Failure.fromLastError(_bindings, 'GetDiskFreeSpaceExW'),
        );
      }
      return DiskSpaceSucceeded(
        DiskSpace(
          availableBytes: available.ref.QuadPart,
          totalBytes: total.ref.QuadPart,
          freeBytes: free.ref.QuadPart,
        ),
      );
    } finally {
      calloc
        ..free(available)
        ..free(total)
        ..free(free);
    }
  }
}

sealed class DiskSpaceResult {
  const DiskSpaceResult();
}

final class DiskSpaceSucceeded extends DiskSpaceResult {
  const DiskSpaceSucceeded(this.space);
  final DiskSpace space;
}

final class DiskSpaceFailed extends DiskSpaceResult {
  const DiskSpaceFailed(this.failure);
  final Win32Failure failure;
}
