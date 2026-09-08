import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Runs a program elevated (`ShellExecuteExW` with `runas`, hidden) and waits
/// for it. Blocks the calling isolate, so it belongs on a worker.
class Elevations {
  /// Calls through the given Win32 bindings.
  const Elevations(this._bindings);

  final WindowsBindings _bindings;

  /// Runs [executable] with [arguments] elevated and waits for it to exit.
  ElevationOutcome run({
    required String executable,
    required List<String> arguments,
  }) {
    final verb = 'runas'.toNativeUtf16(allocator: calloc);
    final file = executable.toNativeUtf16(allocator: calloc);
    final parameters = commandLineOf(
      arguments,
    ).toNativeUtf16(allocator: calloc);
    final info = calloc<SHELLEXECUTEINFOW>();
    final code = calloc<UnsignedLong>();
    try {
      info.ref
        ..cbSize = sizeOf<SHELLEXECUTEINFOW>()
        ..fMask = SEE_MASK_NOCLOSEPROCESS
        ..lpVerb = verb.cast()
        ..lpFile = file.cast()
        ..lpParameters = parameters.cast()
        ..nShow = SW_HIDE;
      if (_bindings.ShellExecuteExW(info) == 0) {
        final failure = Win32Failure.fromLastError(
          _bindings,
          'ShellExecuteExW',
        );
        return failure.code == ERROR_CANCELLED
            ? const ElevationDeclined()
            : ElevationFailed(failure);
      }
      final process = info.ref.hProcess;
      try {
        if (_bindings.WaitForSingleObject(process, INFINITE) != 0) {
          return ElevationFailed(
            Win32Failure.fromLastError(_bindings, 'WaitForSingleObject'),
          );
        }
        if (_bindings.GetExitCodeProcess(process, code) == 0) {
          return ElevationFailed(
            Win32Failure.fromLastError(_bindings, 'GetExitCodeProcess'),
          );
        }
        return ElevationCompleted(code.value);
      } finally {
        _bindings.CloseHandle(process);
      }
    } finally {
      calloc
        ..free(verb)
        ..free(file)
        ..free(parameters)
        ..free(info)
        ..free(code);
    }
  }

  /// [arguments] as one command line `CommandLineToArgvW` splits back into the
  /// same list.
  static String commandLineOf(List<String> arguments) =>
      arguments.map(_quote).join(' ');

  static String _quote(String argument) {
    final out = StringBuffer('"');
    var backslashes = 0;
    for (final char in argument.split('')) {
      if (char == r'\') {
        backslashes++;
        continue;
      }
      if (char == '"') {
        out.write(r'\' * (backslashes * 2 + 1));
      } else {
        out.write(r'\' * backslashes);
      }
      backslashes = 0;
      out.write(char);
    }
    out
      ..write(r'\' * (backslashes * 2))
      ..write('"');
    return out.toString();
  }
}

/// What came of asking to run a program elevated.
sealed class ElevationOutcome {
  const ElevationOutcome();
}

/// The program ran and ended with [exitCode].
final class ElevationCompleted extends ElevationOutcome {
  const ElevationCompleted(this.exitCode);
  final int exitCode;
}

/// The user said no at the prompt.
final class ElevationDeclined extends ElevationOutcome {
  const ElevationDeclined();
}

/// The program could not be started or waited on.
final class ElevationFailed extends ElevationOutcome {
  const ElevationFailed(this.failure);
  final Win32Failure failure;
}
