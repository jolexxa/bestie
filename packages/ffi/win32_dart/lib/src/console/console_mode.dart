import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Get → modify → set → restore over a console handle's mode bits.
class ConsoleMode {
  ConsoleMode(this._bindings);

  final WindowsBindings _bindings;

  /// Clears [mask] from the mode of standard handle [stdHandle], reporting
  /// the mode as it was so the caller can [restore] it.
  ConsoleModeChangeResult clearBits(int stdHandle, int mask) =>
      _change(stdHandle, (mode) => mode & ~mask);

  /// Sets [mask] on the mode of standard handle [stdHandle], reporting the
  /// mode as it was so the caller can [restore] it.
  ConsoleModeChangeResult setBits(int stdHandle, int mask) =>
      _change(stdHandle, (mode) => mode | mask);

  /// Writes [mode] back to standard handle [stdHandle].
  ConsoleModeRestoreResult restore(int stdHandle, int mode) {
    final handle = _standardHandle(stdHandle);
    if (handle == null) {
      return ConsoleModeRestoreFailed(
        Win32Failure.fromLastError(_bindings, 'GetStdHandle'),
      );
    }
    if (_bindings.SetConsoleMode(handle, mode) == 0) {
      return ConsoleModeRestoreFailed(
        Win32Failure.fromLastError(_bindings, 'SetConsoleMode'),
      );
    }
    return const ConsoleModeRestoreSucceeded();
  }

  ConsoleModeChangeResult _change(int stdHandle, int Function(int) apply) {
    final handle = _standardHandle(stdHandle);
    if (handle == null) {
      return ConsoleModeChangeFailed(
        Win32Failure.fromLastError(_bindings, 'GetStdHandle'),
      );
    }

    final mode = calloc<UnsignedLong>();
    try {
      if (_bindings.GetConsoleMode(handle, mode) == 0) {
        return ConsoleModeChangeFailed(
          Win32Failure.fromLastError(_bindings, 'GetConsoleMode'),
        );
      }
      final original = mode.value;
      if (_bindings.SetConsoleMode(handle, apply(original)) == 0) {
        return ConsoleModeChangeFailed(
          Win32Failure.fromLastError(_bindings, 'SetConsoleMode'),
        );
      }
      return ConsoleModeChangeSucceeded(original);
    } finally {
      calloc.free(mode);
    }
  }

  Win32Handle? _standardHandle(int stdHandle) {
    final handle = Win32Handle(_bindings.GetStdHandle(stdHandle));
    return handle.isValid ? handle : null;
  }
}

sealed class ConsoleModeChangeResult {
  const ConsoleModeChangeResult();
}

final class ConsoleModeChangeSucceeded extends ConsoleModeChangeResult {
  const ConsoleModeChangeSucceeded(this.originalMode);

  /// The mode before the change.
  final int originalMode;
}

final class ConsoleModeChangeFailed extends ConsoleModeChangeResult {
  const ConsoleModeChangeFailed(this.failure);
  final Win32Failure failure;
}

sealed class ConsoleModeRestoreResult {
  const ConsoleModeRestoreResult();
}

final class ConsoleModeRestoreSucceeded extends ConsoleModeRestoreResult {
  const ConsoleModeRestoreSucceeded();
}

final class ConsoleModeRestoreFailed extends ConsoleModeRestoreResult {
  const ConsoleModeRestoreFailed(this.failure);
  final Win32Failure failure;
}
