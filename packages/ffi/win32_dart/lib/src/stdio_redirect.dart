import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/constants.dart';
import 'package:win32_dart/src/crt_fd.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

const int _stderrFd = 2;

/// Points the process's stderr at a file.
///
/// Windows reaches stderr two independent ways: the CRT fd table, which the
/// Dart VM and any `/MD`-linked native library write through, and the
/// standard-handle slot, which `WriteFile(GetStdHandle(...))` reads. A
/// redirect is both or neither.
class StdioRedirect {
  StdioRedirect(this._bindings);

  final WindowsBindings _bindings;

  /// Truncates [path] and points stderr at it.
  StderrRedirectResult redirectStderr(String path) {
    final saved = _bindings.dup(_stderrFd);
    if (saved < 0) {
      return StderrRedirectFailed(
        Win32Failure.fromCrtErrno(_bindings, '_dup'),
      );
    }

    final file = Win32Handle(
      withWideString(
        path,
        (name) => _bindings.CreateFileW(
          name,
          GENERIC_WRITE,
          FILE_SHARE_READ | FILE_SHARE_WRITE,
          nullptr,
          CREATE_ALWAYS,
          FILE_ATTRIBUTE_NORMAL,
          nullptr,
        ),
      ),
    );
    if (!file.isValid) {
      final failure = Win32Failure.fromLastError(_bindings, 'CreateFileW');
      _bindings.close(saved);
      return StderrRedirectFailed(failure);
    }

    // Ownership of the handle passes to the descriptor here, so from now on
    // it is released by closing the descriptor and never by CloseHandle.
    final fd = _bindings.open_osfhandle(file.address, O_WRONLY | O_APPEND);
    if (fd < 0) {
      final failure = Win32Failure.fromCrtErrno(_bindings, '_open_osfhandle');
      _bindings
        ..CloseHandle(file)
        ..close(saved);
      return StderrRedirectFailed(failure);
    }

    if (_bindings.dup2(fd, _stderrFd) != 0) {
      final failure = Win32Failure.fromCrtErrno(_bindings, '_dup2');
      _bindings
        ..close(fd)
        ..close(saved);
      return StderrRedirectFailed(failure);
    }
    _bindings.close(fd);

    // Not `file`: that handle belonged to `fd`, which is now closed. `_dup2`
    // gave descriptor 2 a duplicate, and that is the one still open.
    final redirected = _bindings.get_osfhandle(_stderrFd);
    if (redirected == invalidHandleAddress ||
        redirected == noStreamHandleAddress) {
      final failure = Win32Failure.fromCrtErrno(_bindings, '_get_osfhandle');
      return StderrRedirectFailed(_restoreFd(saved, failure));
    }

    final original = _bindings.GetStdHandle(STD_ERROR_HANDLE);
    final replacement = Pointer<Void>.fromAddress(redirected);
    if (_bindings.SetStdHandle(STD_ERROR_HANDLE, replacement) == 0) {
      final failure = Win32Failure.fromLastError(_bindings, 'SetStdHandle');
      return StderrRedirectFailed(_restoreFd(saved, failure));
    }

    return StderrRedirectSucceeded(
      StderrRedirection._(
        savedStderr: CrtFd(saved, _bindings),
        originalStdError: original,
        bindings: _bindings,
      ),
    );
  }

  Win32Failure _restoreFd(int saved, Win32Failure failure) {
    _bindings
      ..dup2(saved, _stderrFd)
      ..close(saved);
    return failure;
  }
}

/// Undoes a [StdioRedirect.redirectStderr].
class StderrRedirection {
  StderrRedirection._({
    required this.savedStderr,
    required HANDLE originalStdError,
    required WindowsBindings bindings,
  }) : _originalStdError = originalStdError,
       _bindings = bindings;

  /// The original stderr, still writable. Dart's own `stderr` sink caches a
  /// handle from when it was constructed and does not follow the redirect,
  /// so this is the only way back to the real terminal.
  final CrtFd savedStderr;

  final HANDLE _originalStdError;
  final WindowsBindings _bindings;

  /// Restores both layers, reporting the first problem but always attempting
  /// all of them. [savedStderr] is closed and unusable afterwards.
  StderrRestoreResult revert() {
    final failures = <Win32Failure>[];

    if (_bindings.SetStdHandle(STD_ERROR_HANDLE, _originalStdError) == 0) {
      failures.add(Win32Failure.fromLastError(_bindings, 'SetStdHandle'));
    }
    if (_bindings.dup2(savedStderr.descriptor, _stderrFd) != 0) {
      failures.add(Win32Failure.fromCrtErrno(_bindings, '_dup2'));
    }
    final closed = savedStderr.close();
    if (closed is CrtCloseFailed) failures.add(closed.failure);

    if (failures.isEmpty) return const StderrRestoreSucceeded();
    return StderrRestoreFailed(failures.first);
  }
}

sealed class StderrRedirectResult {
  const StderrRedirectResult();
}

final class StderrRedirectSucceeded extends StderrRedirectResult {
  const StderrRedirectSucceeded(this.redirection);
  final StderrRedirection redirection;
}

final class StderrRedirectFailed extends StderrRedirectResult {
  const StderrRedirectFailed(this.failure);
  final Win32Failure failure;
}

sealed class StderrRestoreResult {
  const StderrRestoreResult();
}

final class StderrRestoreSucceeded extends StderrRestoreResult {
  const StderrRestoreSucceeded();
}

final class StderrRestoreFailed extends StderrRestoreResult {
  const StderrRestoreFailed(this.failure);
  final Win32Failure failure;
}
