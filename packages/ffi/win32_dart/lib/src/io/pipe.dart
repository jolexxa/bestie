import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Opens anonymous pipes.
class Pipes {
  /// Calls through the given Win32 bindings.
  const Pipes(this._bindings);

  final WindowsBindings _bindings;

  /// Creates an anonymous pipe, [inheritable] when a child must inherit it.
  PipeOpenResult open({bool inheritable = false}) {
    final readOut = calloc<HANDLE>();
    final writeOut = calloc<HANDLE>();
    final security = inheritable
        ? (calloc<SECURITY_ATTRIBUTES>()
            ..ref.nLength = sizeOf<SECURITY_ATTRIBUTES>()
            ..ref.bInheritHandle = 1)
        : nullptr;
    try {
      if (_bindings.CreatePipe(readOut, writeOut, security, 0) == 0) {
        return PipeOpenFailed(
          Win32Failure.fromLastError(_bindings, 'CreatePipe'),
        );
      }
      return PipeOpenSucceeded(
        Pipe._(
          _bindings,
          Win32Handle(readOut.value),
          Win32Handle(writeOut.value),
        ),
      );
    } finally {
      calloc
        ..free(readOut)
        ..free(writeOut);
      if (security != nullptr) calloc.free(security);
    }
  }
}

/// An anonymous pipe: a read end and a write end, each closed once.
class Pipe {
  Pipe._(this._bindings, this._readEnd, this._writeEnd);

  final WindowsBindings _bindings;
  final Win32Handle _readEnd;
  final Win32Handle _writeEnd;
  var _readClosed = false;
  var _writeClosed = false;

  /// The reading end — hand to a pseudoconsole as its input source, or read
  /// from it directly.
  Win32Handle get readEnd => _readEnd;

  /// The writing end — hand to a pseudoconsole as its output sink, or write
  /// to it directly.
  Win32Handle get writeEnd => _writeEnd;

  /// Writes [bytes] to the write end via `WriteFile`. The count written may
  /// be short.
  PipeWriteResult write(List<int> bytes) {
    if (_writeClosed) {
      return const PipeWriteFailed(
        Win32Failure.withoutCode('WriteFile', 'pipe write end is closed'),
      );
    }
    if (bytes.isEmpty) return const PipeWriteSucceeded(0);

    final buffer = calloc<Uint8>(bytes.length);
    final written = calloc<UnsignedLong>();
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final ok = _bindings.WriteFile(
        _writeEnd,
        buffer.cast<Void>(),
        bytes.length,
        written,
        nullptr,
      );
      if (ok == 0) {
        return PipeWriteFailed(
          Win32Failure.fromLastError(_bindings, 'WriteFile'),
        );
      }
      return PipeWriteSucceeded(written.value);
    } finally {
      calloc
        ..free(buffer)
        ..free(written);
    }
  }

  /// Closes the read end. Idempotent.
  void closeReadEnd() {
    if (_readClosed) return;
    _readClosed = true;
    _bindings.CloseHandle(_readEnd);
  }

  /// Closes the write end. Idempotent.
  void closeWriteEnd() {
    if (_writeClosed) return;
    _writeClosed = true;
    _bindings.CloseHandle(_writeEnd);
  }

  /// Closes whichever ends are still open. Idempotent.
  void close() {
    closeReadEnd();
    closeWriteEnd();
  }
}

sealed class PipeOpenResult {
  const PipeOpenResult();
}

final class PipeOpenSucceeded extends PipeOpenResult {
  const PipeOpenSucceeded(this.pipe);
  final Pipe pipe;
}

final class PipeOpenFailed extends PipeOpenResult {
  const PipeOpenFailed(this.failure);
  final Win32Failure failure;
}

sealed class PipeWriteResult {
  const PipeWriteResult();
}

final class PipeWriteSucceeded extends PipeWriteResult {
  const PipeWriteSucceeded(this.bytesWritten);
  final int bytesWritten;
}

final class PipeWriteFailed extends PipeWriteResult {
  const PipeWriteFailed(this.failure);
  final Win32Failure failure;
}
