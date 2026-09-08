import 'dart:io';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_windows/src/windows_fd_sink.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

/// Windows implementation of [TerminalEnvironmentDataSource].
@dataSource
class WindowsTerminalDataSource implements TerminalEnvironmentDataSource {
  /// Every dependency defaults to the host — Win32 for [redirect] and
  /// [console], the process's own streams for [stdoutSink] and
  /// [stdinStream]. Pass them to substitute doubles.
  WindowsTerminalDataSource({
    StdioRedirect? redirect,
    ConsoleMode? console,
    Stdout? stdoutSink,
    Stdin? stdinStream,
  }) : _redirect = redirect ?? StdioRedirect(win32),
       _console = console ?? ConsoleMode(win32),
       _stdout = stdoutSink ?? stdout,
       _stdin = stdinStream ?? stdin;

  final StdioRedirect _redirect;
  final ConsoleMode _console;
  final Stdout _stdout;
  final Stdin _stdin;

  @override
  TerminalOverride? redirectStderr({required String targetPath}) {
    final result = _redirect.redirectStderr(targetPath);
    if (result is! StderrRedirectSucceeded) return null;
    return _StderrRedirectOverride(result.redirection);
  }

  @override
  TerminalOverride? captureInput(Set<InputCapture> groups) {
    if (!_stdin.hasTerminal) return null;

    var mask = 0;
    for (final group in groups) {
      mask |= switch (group) {
        InputCapture.controlKeys => ENABLE_PROCESSED_INPUT,
        InputCapture.flowControl => ENABLE_PROCESSED_INPUT,
        // Nothing on Windows intercepts ^O, ^V or ^R on the way in.
        InputCapture.editingKeys => 0,
      };
    }
    if (mask == 0) return null;

    final cleared = _console.clearBits(STD_INPUT_HANDLE, mask);
    if (cleared is! ConsoleModeChangeSucceeded) return null;
    return _ConsoleModeOverride(
      console: _console,
      stdHandle: STD_INPUT_HANDLE,
      originalMode: cleared.originalMode,
    );
  }

  @override
  TerminalOverride? setWindowTitle(String title) {
    if (!_stdout.hasTerminal) return null;

    // Legacy conhost ignores the sequences below until this bit is set.
    // Windows Terminal interprets them either way.
    final enabled = _console.setBits(
      STD_OUTPUT_HANDLE,
      ENABLE_VIRTUAL_TERMINAL_PROCESSING,
    );

    // CSI 22;0t — push current icon+window title onto the terminal's title
    // stack. OSC 0 ; <title> BEL — set both icon and window title.
    _stdout.write('\x1b[22;0t\x1b]0;$title\x07');

    return _WindowTitleOverride(
      stdout: _stdout,
      console: _console,
      originalMode: switch (enabled) {
        ConsoleModeChangeSucceeded(:final originalMode) => originalMode,
        ConsoleModeChangeFailed() => null,
      },
    );
  }
}

class _StderrRedirectOverride extends TerminalOverride {
  _StderrRedirectOverride(this._redirection)
    : originalSink = ioSinkForCrtFd(_redirection.savedStderr);

  final StderrRedirection _redirection;

  @override
  final IOSink originalSink;

  @override
  Future<void> revert() async => _redirection.revert();
}

class _ConsoleModeOverride extends TerminalOverride {
  const _ConsoleModeOverride({
    required this.console,
    required this.stdHandle,
    required this.originalMode,
  });

  final ConsoleMode console;
  final int stdHandle;
  final int originalMode;

  @override
  Future<void> revert() async => console.restore(stdHandle, originalMode);
}

class _WindowTitleOverride extends TerminalOverride {
  const _WindowTitleOverride({
    required this.stdout,
    required this.console,
    required this.originalMode,
  });

  final Stdout stdout;
  final ConsoleMode console;

  /// The output mode before virtual terminal processing was enabled, or
  /// null when it could not be changed and so needs no restoring.
  final int? originalMode;

  @override
  Future<void> revert() async {
    // CSI 23;0t — pop the icon+window title we previously pushed.
    stdout.write('\x1b[23;0t');
    if (originalMode case final mode?) {
      console.restore(STD_OUTPUT_HANDLE, mode);
    }
  }
}
