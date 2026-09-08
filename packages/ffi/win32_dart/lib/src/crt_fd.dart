import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// A CRT file descriptor, closed exactly once.
class CrtFd {
  CrtFd(this.descriptor, this._bindings);

  /// The descriptor as the CRT numbers it.
  final int descriptor;

  final WindowsBindings _bindings;
  bool _closed = false;

  /// Whether [close] has already succeeded.
  bool get isClosed => _closed;

  /// Writes [bytes] via the CRT's `_write`. The count written may be short.
  CrtWriteResult write(List<int> bytes) {
    if (_closed) {
      return const CrtWriteFailed(
        Win32Failure.withoutCode('_write', 'descriptor is closed'),
      );
    }
    if (bytes.isEmpty) return const CrtWriteSucceeded(0);

    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final written = _bindings.write(
        descriptor,
        buffer.cast<Void>(),
        bytes.length,
      );
      if (written < 0) {
        return CrtWriteFailed(
          Win32Failure.fromCrtErrno(_bindings, '_write'),
        );
      }
      return CrtWriteSucceeded(written);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Closes the descriptor. Closing an already-closed [CrtFd] does nothing
  /// and succeeds — the descriptor number would otherwise have been reused
  /// by then.
  CrtCloseResult close() {
    if (_closed) return const CrtCloseSucceeded();
    if (_bindings.close(descriptor) != 0) {
      return CrtCloseFailed(Win32Failure.fromCrtErrno(_bindings, '_close'));
    }
    _closed = true;
    return const CrtCloseSucceeded();
  }
}

sealed class CrtWriteResult {
  const CrtWriteResult();
}

final class CrtWriteSucceeded extends CrtWriteResult {
  const CrtWriteSucceeded(this.bytesWritten);
  final int bytesWritten;
}

final class CrtWriteFailed extends CrtWriteResult {
  const CrtWriteFailed(this.failure);
  final Win32Failure failure;
}

sealed class CrtCloseResult {
  const CrtCloseResult();
}

final class CrtCloseSucceeded extends CrtCloseResult {
  const CrtCloseSucceeded();
}

final class CrtCloseFailed extends CrtCloseResult {
  const CrtCloseFailed(this.failure);
  final Win32Failure failure;
}
