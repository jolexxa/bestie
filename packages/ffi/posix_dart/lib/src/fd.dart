import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'package:posix_dart/src/bindings.dart';
import 'package:posix_dart/src/bindings_api.dart';
import 'package:posix_dart/src/posix_failure.dart';

/// Thin wrappers around libc's file-descriptor primitives:
/// `dup`, `dup2`, `close`, `open`, `write`. Each returns a
/// per-operation sealed result; failures carry a [PosixFailure]
/// value rather than being thrown.
class PosixFd {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double
  /// — the failure branches below can't be provoked with real fds.
  PosixFd({FdBindings? bindings}) : _bindings = bindings ?? posixBindings;

  final FdBindings _bindings;

  /// Duplicate file descriptor [fd].
  FdDupResult dup(int fd) {
    final result = _bindings.dup(fd);
    if (result < 0) {
      return FdDupFailed(
        PosixFailure.fromErrno('dup', _errnoFromReturn(result)),
      );
    }
    return FdDupSucceeded(result);
  }

  /// Duplicate [oldFd] onto [newFd]. Closes [newFd] first if open.
  FdDup2Result dup2(int oldFd, int newFd) {
    final result = _bindings.dup2(oldFd, newFd);
    if (result < 0) {
      return FdDup2Failed(
        PosixFailure.fromErrno('dup2', _errnoFromReturn(result)),
      );
    }
    return FdDup2Succeeded(result);
  }

  /// Close file descriptor [fd].
  FdCloseResult close(int fd) {
    final result = _bindings.close(fd);
    if (result < 0) {
      return FdCloseFailed(
        PosixFailure.fromErrno('close', _errnoFromReturn(result)),
      );
    }
    return const FdCloseSucceeded();
  }

  /// Write [bytes] to [fd] via libc's `write(2)`. Returned
  /// `bytesWritten` may be less than `bytes.length` if interrupted
  /// or the fd is non-blocking.
  FdWriteResult write(int fd, List<int> bytes) {
    if (bytes.isEmpty) return const FdWriteSucceeded(0);
    final buf = calloc<ffi.Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      final n = _bindings.write(fd, buf.cast<ffi.Void>(), bytes.length);
      if (n < 0) {
        return FdWriteFailed(
          PosixFailure.fromErrno('write', _errnoFromReturn(n)),
        );
      }
      return FdWriteSucceeded(n);
    } finally {
      calloc.free(buf);
    }
  }

  /// Read up to [maxBytes] from [fd] via libc's `read(2)`. An empty
  /// [FdReadSucceeded.bytes] means EOF (a `read` of `0` on a blocking
  /// fd). Returned bytes are copied out of the FFI buffer before it is
  /// freed, so the list is safe to retain.
  FdReadResult read(int fd, int maxBytes) {
    if (maxBytes <= 0) return const FdReadSucceeded(<int>[]);
    final buf = calloc<ffi.Uint8>(maxBytes);
    try {
      final n = _bindings.read(fd, buf.cast<ffi.Void>(), maxBytes);
      if (n < 0) {
        return FdReadFailed(
          PosixFailure.fromErrno('read', _errnoFromReturn(n)),
        );
      }
      return FdReadSucceeded(buf.asTypedList(n).sublist(0));
    } finally {
      calloc.free(buf);
    }
  }

  /// Open [path] with [flags]. For `O_CREAT`, pass [mode] (default
  /// 0644).
  FdOpenResult open(String path, int flags, {int mode = 0x1A4}) {
    final pathPtr = path.toNativeUtf8();
    try {
      // Use the variadic `openMode` shape ffigen generated — it
      // takes the third `mode` arg and works for both create and
      // non-create cases (kernel ignores `mode` when `O_CREAT` is
      // not set).
      final fd = _bindings.openMode(pathPtr.cast<ffi.Char>(), flags, mode);
      if (fd < 0) {
        return FdOpenFailed(
          PosixFailure.fromErrno('open', _errnoFromReturn(fd)),
        );
      }
      return FdOpenSucceeded(fd);
    } finally {
      calloc.free(pathPtr);
    }
  }
}

/// [PosixFd] over the host's libc — what everything in this package uses
/// unless a test substitutes its own.
final PosixFd posixFd = PosixFd();

/// Libc functions that return -1 on failure typically set `errno`,
/// but Dart FFI doesn't expose `__errno_location()` / `__error()`
/// directly. ffigen could add these, but the simpler path that
/// matches every other libc consumer in bestie today: trust the
/// non-zero return and surface a generic errno of 0 with
/// `strerror`-less messaging.
///
int _errnoFromReturn(int rc) => 0;

sealed class FdDupResult {
  const FdDupResult();
}

final class FdDupSucceeded extends FdDupResult {
  const FdDupSucceeded(this.fd);
  final int fd;
}

final class FdDupFailed extends FdDupResult {
  const FdDupFailed(this.failure);
  final PosixFailure failure;
}

sealed class FdDup2Result {
  const FdDup2Result();
}

final class FdDup2Succeeded extends FdDup2Result {
  const FdDup2Succeeded(this.fd);
  final int fd;
}

final class FdDup2Failed extends FdDup2Result {
  const FdDup2Failed(this.failure);
  final PosixFailure failure;
}

sealed class FdCloseResult {
  const FdCloseResult();
}

final class FdCloseSucceeded extends FdCloseResult {
  const FdCloseSucceeded();
}

final class FdCloseFailed extends FdCloseResult {
  const FdCloseFailed(this.failure);
  final PosixFailure failure;
}

sealed class FdWriteResult {
  const FdWriteResult();
}

final class FdWriteSucceeded extends FdWriteResult {
  const FdWriteSucceeded(this.bytesWritten);
  final int bytesWritten;
}

final class FdWriteFailed extends FdWriteResult {
  const FdWriteFailed(this.failure);
  final PosixFailure failure;
}

sealed class FdReadResult {
  const FdReadResult();
}

final class FdReadSucceeded extends FdReadResult {
  const FdReadSucceeded(this.bytes);

  /// Bytes read. Empty means EOF (`read` returned `0`).
  final List<int> bytes;
}

final class FdReadFailed extends FdReadResult {
  const FdReadFailed(this.failure);
  final PosixFailure failure;
}

sealed class FdOpenResult {
  const FdOpenResult();
}

final class FdOpenSucceeded extends FdOpenResult {
  const FdOpenSucceeded(this.fd);
  final int fd;
}

final class FdOpenFailed extends FdOpenResult {
  const FdOpenFailed(this.failure);
  final PosixFailure failure;
}
