import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;
import 'package:posix_dart/src/bindings_api.dart';
import 'package:posix_dart/src/posix_failure.dart';

/// Snapshot of `statvfs(2)` output, narrowed to the disk-space
/// numbers bestie actually uses. Fields are pages — multiply by the
/// reported [fragmentSize] to get bytes.
class StatvfsSnapshot {
  const StatvfsSnapshot({
    required this.fragmentSize,
    required this.blocks,
    required this.blocksFree,
    required this.blocksAvailable,
  });

  /// Size of one fragment in bytes (`f_frsize`).
  final int fragmentSize;

  /// Total fragments (`f_blocks`).
  final int blocks;

  /// Free fragments (`f_bfree`).
  final int blocksFree;

  /// Fragments available to a non-superuser (`f_bavail`).
  final int blocksAvailable;

  /// Bytes available to a non-superuser.
  int get availableBytes => blocksAvailable * fragmentSize;
}

/// Reads `statvfs(2)` for the filesystem containing a path.
///
/// `struct statvfs` has different field types and offsets on Darwin vs
/// glibc, so there is no single typed call to make — each platform gets
/// its own implementation.
// ignore: one_member_abstracts
abstract interface class StatvfsReader {
  /// Returns a [StatvfsResult] for the filesystem containing [path].
  StatvfsResult statvfs(String path);
}

/// glibc implementation of [StatvfsReader].
final class LinuxStatvfsReader implements StatvfsReader {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  LinuxStatvfsReader({LinuxStructBindings? bindings})
    : _b = bindings ?? linuxStructBindings;

  final LinuxStructBindings _b;

  @override
  StatvfsResult statvfs(String path) {
    final pathPtr = path.toNativeUtf8();
    final buf = calloc<linux.Statvfs>();
    try {
      final rc = _b.statvfs(pathPtr.cast<Char>(), buf);
      if (rc != 0) {
        return StatvfsFailed(
          PosixFailure.withoutErrno('statvfs', 'returned $rc for "$path"'),
        );
      }
      final s = buf.ref;
      return StatvfsSucceeded(
        StatvfsSnapshot(
          fragmentSize: s.f_frsize,
          blocks: s.f_blocks,
          blocksFree: s.f_bfree,
          blocksAvailable: s.f_bavail,
        ),
      );
    } finally {
      calloc
        ..free(pathPtr)
        ..free(buf);
    }
  }
}

/// Darwin implementation of [StatvfsReader].
final class MacosStatvfsReader implements StatvfsReader {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  MacosStatvfsReader({MacosStructBindings? bindings})
    : _b = bindings ?? macosStructBindings;

  final MacosStructBindings _b;

  @override
  StatvfsResult statvfs(String path) {
    final pathPtr = path.toNativeUtf8();
    final buf = calloc<macos.Statvfs>();
    try {
      final rc = _b.statvfs(pathPtr.cast<Char>(), buf);
      if (rc != 0) {
        return StatvfsFailed(
          PosixFailure.withoutErrno('statvfs', 'returned $rc for "$path"'),
        );
      }
      final s = buf.ref;
      return StatvfsSucceeded(
        StatvfsSnapshot(
          fragmentSize: s.f_frsize,
          blocks: s.f_blocks,
          blocksFree: s.f_bfree,
          blocksAvailable: s.f_bavail,
        ),
      );
    } finally {
      calloc
        ..free(pathPtr)
        ..free(buf);
    }
  }
}

sealed class StatvfsResult {
  const StatvfsResult();
}

final class StatvfsSucceeded extends StatvfsResult {
  const StatvfsSucceeded(this.snapshot);
  final StatvfsSnapshot snapshot;
}

final class StatvfsFailed extends StatvfsResult {
  const StatvfsFailed(this.failure);
  final PosixFailure failure;
}
