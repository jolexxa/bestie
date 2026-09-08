import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:posix_dart/posix_dart.dart';
import 'package:posix_spawner/src/pty/openpty.dart';
import 'package:posix_spawner/src/pty/read_loop.dart';
import 'package:posix_spawner/src/supervise/status_channel.dart';

/// Spawns a process under the native `spawner` supervisor and returns a
/// [PosixSupervisedProcess]: separate output stream(s) plus a reliable
/// exit status delivered over a status pipe (immune to the Dart VM's
/// SIGCHLD reaper — see [PosixStatusChannel]).
///
/// Two modes:
///  * [terminal] — a pty; the child's stdio is merged onto the tty and
///    surfaced as a single [PosixSupervisedProcess.stdout].
///  * [piped] — three pipes; stdout and stderr are split.
///
/// Concurrency-safe by construction: every pipe end is created
/// `FD_CLOEXEC`, so a sibling spawn's `posix_spawn` can never inherit
/// our pipe ends by number. The helper instead receives exactly the
/// ends it needs via `posix_spawn_file_actions_adddup2` (a `dup2`
/// clears `CLOEXEC` on the copy). The whole create-pipes → set-CLOEXEC
/// → file-actions → `posix_spawnp` → close-handed-ends sequence runs
/// synchronously (no `await`), so the momentary pre-CLOEXEC window is
/// unobservable on the single-threaded isolate.
abstract final class PosixSupervisedSpawn {
  /// Spawn [executable] on a fresh pty sized [rows]×[cols]. The child's
  /// output is merged (as on any terminal) and exposed via
  /// [PosixSupervisedProcess.stdout]; [PosixSupervisedProcess.stderr]
  /// is empty.
  static PosixSupervisedSpawnResult terminal({
    required String spawnerBinaryPath,
    required String executable,
    required int rows,
    required int cols,
    List<String> arguments = const [],
    Map<String, String>? environment,
    Uint8List? confineProgram,
  }) {
    final openpty = posixOpenpty.open();
    final OpenptySucceeded pty;
    switch (openpty) {
      case OpenptySucceeded():
        pty = openpty;
      case OpenptyFailed(:final failure):
        return PosixSupervisedSpawnFailed(failure);
    }

    final resize = platformWinsizeSetter.resize(
      masterFd: pty.masterFd,
      rows: rows,
      cols: cols,
    );
    if (resize is WinsizeResizeFailed) {
      posixFd
        ..close(pty.masterFd)
        ..close(pty.slaveFd);
      return PosixSupervisedSpawnFailed(resize.failure);
    }

    final status = _cloexecPipe();
    if (status == null) {
      posixFd
        ..close(pty.masterFd)
        ..close(pty.slaveFd);
      return PosixSupervisedSpawnFailed(_pipeFailure);
    }
    final statusRead = status.read;
    final statusWrite = status.write;

    // Optional confine channel: the child reads the grant program off an
    // inherited fd and jails itself before `exec`. Created here (CLOEXEC,
    // synchronously) and written *after* the spawn returns, so a program
    // larger than the pipe buffer cannot deadlock the parent.
    _Pipe? confine;
    if (confineProgram != null) {
      confine = _cloexecPipe();
      if (confine == null) {
        posixFd
          ..close(pty.masterFd)
          ..close(pty.slaveFd)
          ..close(statusRead)
          ..close(statusWrite);
        return PosixSupervisedSpawnFailed(_pipeFailure);
      }
    }
    final confineRead = confine?.read;
    final confineWrite = confine?.write;

    // Only the status write end (and the confine read end) are handed to
    // the helper; the slave is opened by the child from `slavePath`. Every
    // dest sits above all sources so `adddup2` never degenerates to a
    // `dup2(fd, fd)` no-op that keeps CLOEXEC and drops the fd at exec.
    final dest = _destsAbove(
      [
        statusWrite,
        pty.masterFd,
        pty.slaveFd,
        ?confineRead,
      ],
      confineRead != null ? 2 : 1,
    );
    final argv = <String>[
      spawnerBinaryPath,
      'terminal',
      '${dest[0]}',
      pty.slavePath,
      if (confineRead != null) ...['--confine-fd', '${dest[1]}'],
      '--',
      executable,
      ...arguments,
    ];

    final failure = _spawnHelper(
      spawnerBinaryPath: spawnerBinaryPath,
      argv: argv,
      dup2s: [
        _Dup2(statusWrite, dest[0]),
        if (confineRead != null) _Dup2(confineRead, dest[1]),
      ],
      environment: environment ?? Platform.environment,
    );

    // Dart handed the status write end and the confine read end to the
    // helper; keep only the ends it writes/reads.
    posixFd.close(statusWrite);
    if (confineRead != null) posixFd.close(confineRead);
    if (failure != null) {
      posixFd
        ..close(statusRead)
        ..close(pty.masterFd)
        ..close(pty.slaveFd);
      if (confineWrite != null) posixFd.close(confineWrite);
      return PosixSupervisedSpawnFailed(failure);
    }

    // Hand the grant program to the now-forked child, then EOF it so the
    // child's read-to-EOF completes and it confines itself.
    if (confineProgram != null && confineWrite != null) {
      _writeAll(confineWrite, confineProgram);
      posixFd.close(confineWrite);
    }

    final channel = PosixStatusChannel.start(statusRead);
    final stdoutLoop = PosixReadLoop.start(pty.masterFd);

    final process = PosixSupervisedProcess._(
      stdout: stdoutLoop.stream,
      stderr: const Stream<List<int>>.empty(),
      status: channel,
      writeFd: pty.masterFd,
      masterFd: pty.masterFd,
      slaveFd: pty.slaveFd,
      readFds: [statusRead],
      loops: [stdoutLoop],
      isTerminal: true,
    );

    // Drop the parent slave once the target exits so the master read
    // loop can see EOF (holding it open during startup avoids racing
    // the child's `open(slave_path)` into a premature EOF).
    unawaited(channel.outcome.whenComplete(process._closeSlaveOnce));
    return PosixSupervisedSpawnSucceeded(process);
  }

  /// Spawn [executable] with three dedicated pipes. stdout and stderr
  /// arrive on separate streams; stdin is written via
  /// [PosixSupervisedProcess.write] and closed with
  /// [PosixSupervisedProcess.closeStdin].
  static PosixSupervisedSpawnResult piped({
    required String spawnerBinaryPath,
    required String executable,
    List<String> arguments = const [],
    Map<String, String>? environment,
    Uint8List? confineProgram,
  }) {
    final status = _cloexecPipe();
    final stdin = _cloexecPipe();
    final stdout = _cloexecPipe();
    final stderr = _cloexecPipe();
    final confine = confineProgram != null ? _cloexecPipe() : null;
    if (status == null ||
        stdin == null ||
        stdout == null ||
        stderr == null ||
        (confineProgram != null && confine == null)) {
      for (final p in [status, stdin, stdout, stderr, confine]) {
        if (p != null) {
          posixFd
            ..close(p.read)
            ..close(p.write);
        }
      }
      return PosixSupervisedSpawnFailed(_pipeFailure);
    }
    final statusRead = status.read;
    final statusWrite = status.write;
    final stdinRead = stdin.read;
    final stdinWrite = stdin.write;
    final stdoutRead = stdout.read;
    final stdoutWrite = stdout.write;
    final stderrRead = stderr.read;
    final stderrWrite = stderr.write;
    final confineRead = confine?.read;
    final confineWrite = confine?.write;

    // Ends handed to the helper: the child reads stdin (and the confine
    // program) and writes stdout/stderr. (Dart keeps the opposite end.)
    final dest = _destsAbove(
      [
        statusWrite,
        stdinRead,
        stdoutWrite,
        stderrWrite,
        ?confineRead,
      ],
      confineRead != null ? 5 : 4,
    );
    final argv = <String>[
      spawnerBinaryPath,
      'piped',
      '${dest[0]}',
      '${dest[1]}',
      '${dest[2]}',
      '${dest[3]}',
      if (confineRead != null) ...['--confine-fd', '${dest[4]}'],
      '--',
      executable,
      ...arguments,
    ];

    final failure = _spawnHelper(
      spawnerBinaryPath: spawnerBinaryPath,
      argv: argv,
      dup2s: [
        _Dup2(statusWrite, dest[0]),
        _Dup2(stdinRead, dest[1]),
        _Dup2(stdoutWrite, dest[2]),
        _Dup2(stderrWrite, dest[3]),
        if (confineRead != null) _Dup2(confineRead, dest[4]),
      ],
      environment: environment ?? Platform.environment,
    );

    // Close the ends handed to the helper. Closing the stdout/stderr
    // write ends here is essential: once the target exits, those pipes
    // have no remaining writers and Dart's read loops see EOF.
    posixFd
      ..close(statusWrite)
      ..close(stdinRead)
      ..close(stdoutWrite)
      ..close(stderrWrite);
    if (confineRead != null) posixFd.close(confineRead);

    if (failure != null) {
      posixFd
        ..close(statusRead)
        ..close(stdinWrite)
        ..close(stdoutRead)
        ..close(stderrRead);
      if (confineWrite != null) posixFd.close(confineWrite);
      return PosixSupervisedSpawnFailed(failure);
    }

    // Hand the grant program to the forked child, then EOF it.
    if (confineProgram != null && confineWrite != null) {
      _writeAll(confineWrite, confineProgram);
      posixFd.close(confineWrite);
    }

    final channel = PosixStatusChannel.start(statusRead);
    final stdoutLoop = PosixReadLoop.start(stdoutRead);
    final stderrLoop = PosixReadLoop.start(stderrRead);

    final process = PosixSupervisedProcess._(
      stdout: stdoutLoop.stream,
      stderr: stderrLoop.stream,
      status: channel,
      writeFd: stdinWrite,
      masterFd: null,
      slaveFd: null,
      readFds: [stdoutRead, stderrRead, statusRead],
      loops: [stdoutLoop, stderrLoop],
      isTerminal: false,
    );
    return PosixSupervisedSpawnSucceeded(process);
  }
}

/// A live handle to a supervised child: output stream(s), a reliable
/// exit outcome, and stdin/resize/kill/close controls.
class PosixSupervisedProcess {
  PosixSupervisedProcess._({
    required Stream<List<int>> stdout,
    required Stream<List<int>> stderr,
    required PosixStatusChannel status,
    required int writeFd,
    required int? masterFd,
    required int? slaveFd,
    required List<int> readFds,
    required List<PosixReadLoop> loops,
    required bool isTerminal,
  }) : _stdout = stdout,
       _stderr = stderr,
       _status = status,
       _writeFd = writeFd,
       _masterFd = masterFd,
       _slaveFd = slaveFd,
       _readFds = readFds,
       _loops = loops,
       _isTerminal = isTerminal;

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final PosixStatusChannel _status;

  /// Master fd (terminal) or stdin write end (piped).
  final int _writeFd;
  final int? _masterFd;
  final int? _slaveFd;
  final List<int> _readFds;
  final List<PosixReadLoop> _loops;
  final bool _isTerminal;

  bool _closed = false;
  bool _writeFdClosed = false;
  bool _slaveClosed = false;

  /// Child output. In terminal mode this is the merged pty stream; in
  /// piped mode it is the child's stdout only.
  Stream<List<int>> get stdout => _stdout;

  /// The child's stderr. Empty (and closed) in terminal mode, where
  /// output is merged onto the pty.
  Stream<List<int>> get stderr => _stderr;

  /// The target's pid, once the supervisor's first status frame lands.
  Future<int> get pid => _status.pid;

  /// The reliable exit outcome: [PosixSupervisorExited] (carrying the
  /// raw `waitpid` status to decode) or [PosixSupervisorLost].
  Future<PosixSupervisorOutcome> get exitStatus => _status.outcome;

  void _closeSlaveOnce() {
    if (_slaveClosed) return;
    _slaveClosed = true;
    final slave = _slaveFd;
    if (slave != null) posixFd.close(slave);
  }

  /// Write [bytes] to the child's stdin (the pty master in terminal
  /// mode, the stdin pipe in piped mode).
  void write(List<int> bytes) {
    if (_closed || _writeFdClosed) {
      throw StateError('PosixSupervisedProcess stdin is closed');
    }
    posixFd.write(_writeFd, bytes);
  }

  /// Close the child's stdin so it sees EOF. Piped mode only — a pty
  /// has no separate stdin end (send EOT via [write] instead), so this
  /// is a no-op in terminal mode.
  Future<void> closeStdin() async {
    if (_isTerminal || _writeFdClosed) return;
    _writeFdClosed = true;
    posixFd.close(_writeFd);
  }

  /// Update the kernel winsize via `ioctl(TIOCSWINSZ)` (→ SIGWINCH).
  /// Terminal mode only; a no-op for piped processes. Best-effort.
  void resize({required int rows, required int cols}) {
    final master = _masterFd;
    if (master != null) {
      platformWinsizeSetter.resize(masterFd: master, rows: rows, cols: cols);
    }
  }

  /// Send [signal] (default SIGTERM) to the target's whole process
  /// group. Awaits the target pid from the status pipe first; returns
  /// `false` if the supervisor was lost before reporting a pid (nothing
  /// to signal).
  ///
  /// The helper calls `setsid()` before `exec`, so the target leads its
  /// own group and `pgid == pid` — a negative pid reaches the group.
  /// Signalling the pid alone would stop only the shell, and a
  /// non-interactive shell has no job control to forward it with, so
  /// the command it launched would outlive the kill.
  Future<bool> kill([int signal = 15]) async {
    try {
      final targetPid = await _status.pid;
      return (posixBindings.kill(-targetPid, signal)) == 0;
    } on Object {
      return false;
    }
  }

  /// Tear down: close owned fds, drop the read loops, and shut the
  /// status channel. Does NOT signal the child — call [kill] first if
  /// you need it dead. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    // Close fds before killing their loops so a blocking `read()` wakes
    // with EBADF (macOS won't interrupt a sleeping syscall when another
    // worker closes the fd — order matters).
    if (!_writeFdClosed) {
      _writeFdClosed = true;
      posixFd.close(_writeFd);
    }
    _readFds.forEach(posixFd.close);
    _closeSlaveOnce();

    for (final loop in _loops) {
      await loop.close();
    }
    await _status.shutdown();
  }
}

/// A pipe's read and write ends.
class _Pipe {
  const _Pipe(this.read, this.write);
  final int read;
  final int write;
}

/// A `posix_spawn_file_actions_adddup2` pair: duplicate [src] onto [dst].
class _Dup2 {
  const _Dup2(this.src, this.dst);
  final int src;
  final int dst;
}

/// Create a pipe with both ends `FD_CLOEXEC`, or `null` if `pipe()`
/// failed. macOS lacks `pipe2`, so CLOEXEC is stamped immediately after
/// `pipe()` within the caller's synchronous spawn block — no `await`
/// between, so the pre-CLOEXEC window is unobservable.
_Pipe? _cloexecPipe() {
  final fds = calloc<ffi.Int>(2);
  try {
    if (posixBindings.pipe(fds) != 0) return null;
    final read = fds[0];
    final write = fds[1];
    posixBindings
      ..fcntlInt(read, fSetfd, fdCloexec)
      ..fcntlInt(write, fSetfd, fdCloexec);
    return _Pipe(read, write);
  } finally {
    calloc.free(fds);
  }
}

/// Write every byte of [bytes] to blocking [fd], looping over partial writes
/// and giving up on the first error (the child then sees a short program and
/// fails closed on the magic check).
void _writeAll(int fd, List<int> bytes) {
  var offset = 0;
  while (offset < bytes.length) {
    final result = posixFd.write(fd, bytes.sublist(offset));
    switch (result) {
      case FdWriteSucceeded(:final bytesWritten):
        if (bytesWritten <= 0) return;
        offset += bytesWritten;
      case FdWriteFailed():
        return;
    }
  }
}

/// [count] contiguous fd numbers strictly above every fd in [sources],
/// so `adddup2(source, dest)` targets are guaranteed distinct from all
/// sources (avoiding the `dup2(fd, fd)` no-op that preserves CLOEXEC).
List<int> _destsAbove(List<int> sources, int count) {
  final base = sources.reduce((a, b) => a > b ? a : b) + 1;
  return List.generate(count, (i) => base + i);
}

/// `posix_spawnp` the helper with [argv], placing each [_Dup2] in
/// [dup2s] via `posix_spawn_file_actions_adddup2`. Returns `null` on
/// success or a [PosixFailure]. The supervisor pid is intentionally
/// discarded — Dart signals the target (via the status pipe), and the
/// VM's reaper collects the short-lived supervisor.
PosixFailure? _spawnHelper({
  required String spawnerBinaryPath,
  required List<String> argv,
  required List<_Dup2> dup2s,
  required Map<String, String> environment,
}) {
  final helperPathPtr = spawnerBinaryPath.toNativeUtf8();
  final pidOut = calloc<ffi.Int>();

  final argvPtrs = argv.map((s) => s.toNativeUtf8()).toList();
  final argvArr = calloc<ffi.Pointer<ffi.Char>>(argvPtrs.length + 1);
  for (var i = 0; i < argvPtrs.length; i++) {
    argvArr[i] = argvPtrs[i].cast<ffi.Char>();
  }
  argvArr[argvPtrs.length] = ffi.nullptr;

  final envPtrs = environment.entries
      .map((e) => '${e.key}=${e.value}'.toNativeUtf8())
      .toList();
  final envp = calloc<ffi.Pointer<ffi.Char>>(envPtrs.length + 1);
  for (var i = 0; i < envPtrs.length; i++) {
    envp[i] = envPtrs[i].cast<ffi.Char>();
  }
  envp[envPtrs.length] = ffi.nullptr;

  final fileActions = calloc<ffi.Uint8>(
    PosixSizes.posixSpawnFileActions,
  ).cast<ffi.Void>();
  final attr = calloc<ffi.Uint8>(PosixSizes.posixSpawnattr).cast<ffi.Void>();
  var faInited = false;
  var attrInited = false;

  void freeAll() {
    calloc
      ..free(helperPathPtr)
      ..free(pidOut)
      ..free(argvArr)
      ..free(envp)
      ..free(fileActions)
      ..free(attr);
    argvPtrs.forEach(calloc.free);
    envPtrs.forEach(calloc.free);
  }

  try {
    if ((posixBindings.posix_spawn_file_actions_init(fileActions)) != 0) {
      return PosixFailure.withoutErrno(
        'posix_spawn_file_actions_init',
        'nonzero return',
      );
    }
    faInited = true;
    for (final d in dup2s) {
      posixBindings.posix_spawn_file_actions_adddup2(fileActions, d.src, d.dst);
    }

    if ((posixBindings.posix_spawnattr_init(attr)) != 0) {
      return PosixFailure.withoutErrno(
        'posix_spawnattr_init',
        'nonzero return',
      );
    }
    attrInited = true;

    final rc = posixBindings.posix_spawnp(
      pidOut,
      helperPathPtr.cast<ffi.Char>(),
      fileActions,
      attr,
      argvArr,
      envp,
    );
    if (rc != 0) {
      return PosixFailure.fromErrno('posix_spawnp', rc);
    }
    return null;
  } finally {
    if (faInited) {
      posixBindings.posix_spawn_file_actions_destroy(fileActions);
    }
    if (attrInited) {
      posixBindings.posix_spawnattr_destroy(attr);
    }
    freeAll();
  }
}

final PosixFailure _pipeFailure = PosixFailure.withoutErrno(
  'pipe',
  'nonzero return',
);

sealed class PosixSupervisedSpawnResult {
  const PosixSupervisedSpawnResult();
}

final class PosixSupervisedSpawnSucceeded extends PosixSupervisedSpawnResult {
  const PosixSupervisedSpawnSucceeded(this.process);
  final PosixSupervisedProcess process;
}

final class PosixSupervisedSpawnFailed extends PosixSupervisedSpawnResult {
  const PosixSupervisedSpawnFailed(this.failure);
  final PosixFailure failure;
}
