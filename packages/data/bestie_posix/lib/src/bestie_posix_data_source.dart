import 'dart:io';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_posix/src/native_fd_sink.dart';
import 'package:intentions/intentions.dart';
import 'package:posix_dart/posix_dart.dart';

/// POSIX implementation of [TerminalEnvironmentDataSource], shared by
/// macOS and Linux.
@dataSource
class BestiePosixDataSource implements TerminalEnvironmentDataSource {
  /// Every dependency defaults to the host — libc for [fdApi] and
  /// [termios], the process's own streams for [stdoutSink] and
  /// [stdinStream]. Pass them to substitute doubles.
  BestiePosixDataSource({
    required this.platform,
    PosixFd? fdApi,
    TermiosControl? termios,
    Stdout? stdoutSink,
    Stdin? stdinStream,
  }) : _fd = fdApi ?? posixFd,
       _termios = termios ?? platformTermiosControl,
       _stdout = stdoutSink ?? stdout,
       _stdin = stdinStream ?? stdin;

  /// Resolved platform configuration for the running host.
  final OSPlatform platform;
  final PosixFd _fd;
  final TermiosControl _termios;
  final Stdout _stdout;
  final Stdin _stdin;

  static const _stdinFd = 0;
  static const _stderrFd = 2;

  @override
  TerminalOverride? redirectStderr({required String targetPath}) {
    final savedDup = _fd.dup(_stderrFd);
    if (savedDup is! FdDupSucceeded) return null;
    final savedFd = savedDup.fd;

    final opened = _fd.open(targetPath, oWronly | oCreat | oTrunc);
    if (opened is! FdOpenSucceeded) {
      _fd.close(savedFd);
      return null;
    }
    final fd = opened.fd;

    final dup2Res = _fd.dup2(fd, _stderrFd);
    if (dup2Res is! FdDup2Succeeded) {
      _fd
        ..close(fd)
        ..close(savedFd);
      return null;
    }
    _fd.close(fd);

    return _StderrRedirectOverride(
      fdApi: _fd,
      savedFd: savedFd,
      sink: ioSinkForFd(fd: savedFd, fdApi: _fd),
    );
  }

  @override
  TerminalOverride? setWindowTitle(String title) {
    if (!_stdout.hasTerminal) return null;
    // CSI 22;0t — push current icon+window title onto the terminal's title
    // stack. OSC 0 ; <title> BEL — set both icon and window title.
    _stdout.write('\x1b[22;0t\x1b]0;$title\x07');
    return _WindowTitleOverride(_stdout);
  }

  @override
  TerminalOverride? captureInput(Set<InputCapture> groups) {
    if (groups.isEmpty) return null;
    if (!_stdin.hasTerminal) return null;

    var iflagMask = 0;
    var lflagMask = 0;
    for (final group in groups) {
      switch (group) {
        case InputCapture.controlKeys:
          lflagMask |= isigBit;
        case InputCapture.editingKeys:
          lflagMask |= iextenBit;
        case InputCapture.flowControl:
          iflagMask |= ixonBit;
      }
    }

    final result = _termios.clearFlags(
      _stdinFd,
      iflagMask: iflagMask,
      lflagMask: lflagMask,
    );
    if (result is! TermiosClearFlagsSucceeded) return null;

    return _TtyOverride(termios: _termios, original: result.originalSnapshot);
  }
}

class _StderrRedirectOverride extends TerminalOverride {
  _StderrRedirectOverride({
    required this.fdApi,
    required this.savedFd,
    required this.sink,
  });

  final PosixFd fdApi;
  final int savedFd;
  final IOSink sink;

  @override
  IOSink? get originalSink => sink;

  @override
  Future<void> revert() async {
    fdApi
      ..dup2(savedFd, 2)
      ..close(savedFd);
  }
}

class _WindowTitleOverride extends TerminalOverride {
  const _WindowTitleOverride(this._stdout);

  final Stdout _stdout;

  @override
  Future<void> revert() async {
    // CSI 23;0t — pop the icon+window title we previously pushed.
    _stdout.write('\x1b[23;0t');
  }
}

class _TtyOverride extends TerminalOverride {
  _TtyOverride({required this.termios, required this.original});

  final TermiosControl termios;
  final TermiosSnapshot original;

  @override
  Future<void> revert() async {
    termios
      ..restore(0, original)
      ..freeSnapshot(original);
  }
}
