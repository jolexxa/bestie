import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;
import 'package:posix_dart/src/bindings_api.dart';
import 'package:posix_dart/src/constants.dart';
import 'package:posix_dart/src/posix_failure.dart';

/// Wraps `ioctl(fd, TIOCSWINSZ, &winsize{rows, cols})` — the call
/// that propagates a terminal resize to the kernel (which in turn
/// delivers SIGWINCH to the child's foreground process group).
///
/// `struct winsize` is bit-identical on macOS and glibc (four
/// `unsigned short`s), but each platform still gets its own
/// implementation so the import doesn't lie and so future divergence
/// (or arm64 alignment quirks) would be caught by the ffigen-emitted
/// struct.
// This is a platform abstraction interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class WinsizeSetter {
  /// Resizes the pty behind [masterFd] to [rows] × [cols].
  WinsizeResizeResult resize({
    required int masterFd,
    required int rows,
    required int cols,
  });
}

/// glibc implementation of [WinsizeSetter].
final class LinuxWinsizeSetter implements WinsizeSetter {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  LinuxWinsizeSetter({LinuxStructBindings? bindings})
    : _b = bindings ?? linuxStructBindings;

  final LinuxStructBindings _b;

  @override
  WinsizeResizeResult resize({
    required int masterFd,
    required int rows,
    required int cols,
  }) {
    final ws = calloc<linux.WinSize>();
    try {
      ws.ref
        ..ws_row = rows
        ..ws_col = cols;
      final rc = _b.ioctlWinSize(masterFd, tiocswinsz, ws);
      if (rc != 0) {
        return WinsizeResizeFailed(
          PosixFailure.withoutErrno('ioctl(TIOCSWINSZ)', 'returned $rc'),
        );
      }
      return const WinsizeResizeSucceeded();
    } finally {
      calloc.free(ws);
    }
  }
}

/// Darwin implementation of [WinsizeSetter].
final class MacosWinsizeSetter implements WinsizeSetter {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  MacosWinsizeSetter({MacosStructBindings? bindings})
    : _b = bindings ?? macosStructBindings;

  final MacosStructBindings _b;

  @override
  WinsizeResizeResult resize({
    required int masterFd,
    required int rows,
    required int cols,
  }) {
    final ws = calloc<macos.WinSize>();
    try {
      ws.ref
        ..ws_row = rows
        ..ws_col = cols;
      final rc = _b.ioctlWinSize(masterFd, tiocswinsz, ws);
      if (rc != 0) {
        return WinsizeResizeFailed(
          PosixFailure.withoutErrno('ioctl(TIOCSWINSZ)', 'returned $rc'),
        );
      }
      return const WinsizeResizeSucceeded();
    } finally {
      calloc.free(ws);
    }
  }
}

/// The [WinsizeSetter] for the host platform.
final WinsizeSetter platformWinsizeSetter = Platform.isMacOS
    ? MacosWinsizeSetter()
    : LinuxWinsizeSetter();

sealed class WinsizeResizeResult {
  const WinsizeResizeResult();
}

final class WinsizeResizeSucceeded extends WinsizeResizeResult {
  const WinsizeResizeSucceeded();
}

final class WinsizeResizeFailed extends WinsizeResizeResult {
  const WinsizeResizeFailed(this.failure);
  final PosixFailure failure;
}
