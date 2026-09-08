import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;
import 'package:posix_dart/src/bindings_api.dart';
import 'package:posix_dart/src/constants.dart';
import 'package:posix_dart/src/posix_failure.dart';
import 'package:posix_dart/src/sizes.dart';

/// Opaque handle to a saved termios state.
class TermiosSnapshot {
  const TermiosSnapshot._(this._ptr);

  final Pointer<Void> _ptr;
}

/// `tcgetattr` / `tcsetattr` for the host platform.
abstract interface class TermiosControl {
  /// Read the current termios state for [fd]. On success the caller owns
  /// the snapshot — release via [freeSnapshot].
  TermiosSnapshotResult snapshot(int fd);

  /// Write [snap] back to [fd] using `tcsetattr(fd, TCSANOW, snap)`.
  /// Does NOT free [snap].
  TermiosRestoreResult restore(int fd, TermiosSnapshot snap);

  /// Free a [TermiosSnapshot] previously returned from this object.
  void freeSnapshot(TermiosSnapshot snap);

  /// Read [fd]'s termios, clear the bits in [iflagMask] from `c_iflag`
  /// and the bits in [lflagMask] from `c_lflag`, write it back. The
  /// succeeded result carries the *original* snapshot so the caller can
  /// later [restore] it.
  TermiosClearFlagsResult clearFlags(
    int fd, {
    int iflagMask = 0,
    int lflagMask = 0,
  });
}

/// glibc implementation of [TermiosControl].
final class LinuxTermiosControl implements TermiosControl {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  LinuxTermiosControl({LinuxStructBindings? bindings})
    : _b = bindings ?? linuxStructBindings;

  final LinuxStructBindings _b;

  @override
  TermiosSnapshotResult snapshot(int fd) {
    final buf = calloc<linux.termios>();
    final rc = _b.tcgetattr(fd, buf);
    if (rc != 0) {
      calloc.free(buf);
      return TermiosSnapshotFailed(
        PosixFailure.withoutErrno('tcgetattr', 'returned $rc'),
      );
    }
    return TermiosSnapshotSucceeded(TermiosSnapshot._(buf.cast<Void>()));
  }

  @override
  TermiosRestoreResult restore(int fd, TermiosSnapshot snap) {
    final rc = _b.tcsetattr(fd, tcsanow, snap._ptr.cast<linux.termios>());
    if (rc != 0) {
      return TermiosRestoreFailed(
        PosixFailure.withoutErrno('tcsetattr', 'returned $rc'),
      );
    }
    return const TermiosRestoreSucceeded();
  }

  @override
  void freeSnapshot(TermiosSnapshot snap) => calloc.free(snap._ptr);

  @override
  TermiosClearFlagsResult clearFlags(
    int fd, {
    int iflagMask = 0,
    int lflagMask = 0,
  }) {
    final original = calloc<linux.termios>();
    final originalRc = _b.tcgetattr(fd, original);
    if (originalRc != 0) {
      calloc.free(original);
      return TermiosClearFlagsFailed(
        PosixFailure.withoutErrno('tcgetattr', 'returned $originalRc'),
      );
    }
    final modified = calloc<linux.termios>();
    try {
      _copyBytes(original.cast<Uint8>(), modified.cast<Uint8>());
      if (iflagMask != 0) {
        modified.ref.c_iflag = modified.ref.c_iflag & ~iflagMask;
      }
      if (lflagMask != 0) {
        modified.ref.c_lflag = modified.ref.c_lflag & ~lflagMask;
      }
      final rc = _b.tcsetattr(fd, tcsanow, modified);
      if (rc != 0) {
        calloc.free(original);
        return TermiosClearFlagsFailed(
          PosixFailure.withoutErrno('tcsetattr', 'returned $rc'),
        );
      }
      return TermiosClearFlagsSucceeded(
        TermiosSnapshot._(original.cast<Void>()),
      );
    } finally {
      calloc.free(modified);
    }
  }
}

/// Darwin implementation of [TermiosControl].
final class MacosTermiosControl implements TermiosControl {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  MacosTermiosControl({MacosStructBindings? bindings})
    : _b = bindings ?? macosStructBindings;

  final MacosStructBindings _b;

  @override
  TermiosSnapshotResult snapshot(int fd) {
    final buf = calloc<macos.termios>();
    final rc = _b.tcgetattr(fd, buf);
    if (rc != 0) {
      calloc.free(buf);
      return TermiosSnapshotFailed(
        PosixFailure.withoutErrno('tcgetattr', 'returned $rc'),
      );
    }
    return TermiosSnapshotSucceeded(TermiosSnapshot._(buf.cast<Void>()));
  }

  @override
  TermiosRestoreResult restore(int fd, TermiosSnapshot snap) {
    final rc = _b.tcsetattr(fd, tcsanow, snap._ptr.cast<macos.termios>());
    if (rc != 0) {
      return TermiosRestoreFailed(
        PosixFailure.withoutErrno('tcsetattr', 'returned $rc'),
      );
    }
    return const TermiosRestoreSucceeded();
  }

  @override
  void freeSnapshot(TermiosSnapshot snap) => calloc.free(snap._ptr);

  @override
  TermiosClearFlagsResult clearFlags(
    int fd, {
    int iflagMask = 0,
    int lflagMask = 0,
  }) {
    final original = calloc<macos.termios>();
    final originalRc = _b.tcgetattr(fd, original);
    if (originalRc != 0) {
      calloc.free(original);
      return TermiosClearFlagsFailed(
        PosixFailure.withoutErrno('tcgetattr', 'returned $originalRc'),
      );
    }
    final modified = calloc<macos.termios>();
    try {
      _copyBytes(original.cast<Uint8>(), modified.cast<Uint8>());
      if (iflagMask != 0) {
        modified.ref.c_iflag = modified.ref.c_iflag & ~iflagMask;
      }
      if (lflagMask != 0) {
        modified.ref.c_lflag = modified.ref.c_lflag & ~lflagMask;
      }
      final rc = _b.tcsetattr(fd, tcsanow, modified);
      if (rc != 0) {
        calloc.free(original);
        return TermiosClearFlagsFailed(
          PosixFailure.withoutErrno('tcsetattr', 'returned $rc'),
        );
      }
      return TermiosClearFlagsSucceeded(
        TermiosSnapshot._(original.cast<Void>()),
      );
    } finally {
      calloc.free(modified);
    }
  }
}

/// The [TermiosControl] for the host platform.
final TermiosControl platformTermiosControl = Platform.isMacOS
    ? MacosTermiosControl()
    : LinuxTermiosControl();

void _copyBytes(Pointer<Uint8> src, Pointer<Uint8> dst) {
  final n = PosixSizes.termios;
  for (var i = 0; i < n; i++) {
    dst[i] = src[i];
  }
}

sealed class TermiosSnapshotResult {
  const TermiosSnapshotResult();
}

final class TermiosSnapshotSucceeded extends TermiosSnapshotResult {
  const TermiosSnapshotSucceeded(this.snapshot);
  final TermiosSnapshot snapshot;
}

final class TermiosSnapshotFailed extends TermiosSnapshotResult {
  const TermiosSnapshotFailed(this.failure);
  final PosixFailure failure;
}

sealed class TermiosRestoreResult {
  const TermiosRestoreResult();
}

final class TermiosRestoreSucceeded extends TermiosRestoreResult {
  const TermiosRestoreSucceeded();
}

final class TermiosRestoreFailed extends TermiosRestoreResult {
  const TermiosRestoreFailed(this.failure);
  final PosixFailure failure;
}

sealed class TermiosClearFlagsResult {
  const TermiosClearFlagsResult();
}

final class TermiosClearFlagsSucceeded extends TermiosClearFlagsResult {
  const TermiosClearFlagsSucceeded(this.originalSnapshot);
  final TermiosSnapshot originalSnapshot;
}

final class TermiosClearFlagsFailed extends TermiosClearFlagsResult {
  const TermiosClearFlagsFailed(this.failure);
  final PosixFailure failure;
}
