import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/console/conpty.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Opens pseudoconsoles on the console host bestie ships.
class PseudoConsoles {
  /// Opens consoles through [_conpty].
  const PseudoConsoles(this._conpty);

  final Conpty _conpty;

  /// Creates a pseudoconsole [rows]×[cols] drawing input from [input] and
  /// writing output to [output] — the pty-side ends of two pipes.
  PseudoConsoleCreateResult open({
    required int rows,
    required int cols,
    required HANDLE input,
    required HANDLE output,
    int flags = 0,
  }) {
    final size = calloc<COORD>()
      ..ref.X = cols
      ..ref.Y = rows;
    final out = calloc<HPCON>();
    try {
      final hr = _conpty.createPseudoConsole(
        size.ref,
        input,
        output,
        flags,
        out,
      );
      if (hr != 0) {
        return PseudoConsoleCreateFailed(
          _hresultFailure('CreatePseudoConsole', hr),
        );
      }
      return PseudoConsoleCreateSucceeded(PseudoConsole._(_conpty, out.value));
    } finally {
      calloc
        ..free(size)
        ..free(out);
    }
  }
}

/// An open pseudoconsole.
class PseudoConsole {
  PseudoConsole._(this._conpty, this._handle);

  final Conpty _conpty;
  final HPCON _handle;
  bool _closed = false;

  /// Whether [close] has already run.
  bool get isClosed => _closed;

  /// The raw `HPCON`, for wiring into a child's attribute list.
  HPCON get handle => _handle;

  /// Resizes the console to [rows]×[cols]. The child sees the new size on its
  /// next render.
  PseudoConsoleResizeResult resize({required int rows, required int cols}) {
    if (_closed) {
      return const PseudoConsoleResizeFailed(
        Win32Failure.withoutCode(
          'ResizePseudoConsole',
          'pseudoconsole is closed',
        ),
      );
    }
    final size = calloc<COORD>()
      ..ref.X = cols
      ..ref.Y = rows;
    try {
      final hr = _conpty.resizePseudoConsole(_handle, size.ref);
      if (hr != 0) {
        return PseudoConsoleResizeFailed(
          _hresultFailure('ResizePseudoConsole', hr),
        );
      }
      return const PseudoConsoleResizeSucceeded();
    } finally {
      calloc.free(size);
    }
  }

  /// Closes the pseudoconsole. Emits a final frame to the output pipe first,
  /// so the reader must stay alive through teardown or it deadlocks. Closing
  /// an already-closed console does nothing.
  void close() {
    if (_closed) return;
    _closed = true;
    _conpty.closePseudoConsole(_handle);
  }
}

/// A `CreatePseudoConsole` / `ResizePseudoConsole` HRESULT carries its own
/// code, not `GetLastError`.
Win32Failure _hresultFailure(String function, int hr) => Win32Failure(
  function: function,
  code: hr,
  message: 'HRESULT 0x${hr.toUnsigned(32).toRadixString(16)}',
  channel: Win32ErrorChannel.none,
);

sealed class PseudoConsoleCreateResult {
  const PseudoConsoleCreateResult();
}

final class PseudoConsoleCreateSucceeded extends PseudoConsoleCreateResult {
  const PseudoConsoleCreateSucceeded(this.console);
  final PseudoConsole console;
}

final class PseudoConsoleCreateFailed extends PseudoConsoleCreateResult {
  const PseudoConsoleCreateFailed(this.failure);
  final Win32Failure failure;
}

sealed class PseudoConsoleResizeResult {
  const PseudoConsoleResizeResult();
}

final class PseudoConsoleResizeSucceeded extends PseudoConsoleResizeResult {
  const PseudoConsoleResizeSucceeded();
}

final class PseudoConsoleResizeFailed extends PseudoConsoleResizeResult {
  const PseudoConsoleResizeFailed(this.failure);
  final Win32Failure failure;
}
