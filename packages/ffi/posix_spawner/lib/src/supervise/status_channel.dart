import 'dart:async';
import 'dart:isolate';

import 'package:posix_dart/posix_dart.dart';
import 'package:posix_spawner/src/supervise/status_frame.dart';

/// Outcome of reading the supervisor's status pipe.
sealed class PosixSupervisorOutcome {
  const PosixSupervisorOutcome();
}

/// Both frames arrived: the target's pid and its raw `waitpid` status.
final class PosixSupervisorExited extends PosixSupervisorOutcome {
  const PosixSupervisorExited({
    required this.targetPid,
    required this.rawStatus,
  });

  final int targetPid;
  final int rawStatus;
}

/// The status pipe hit EOF (or errored) before both 4-byte frames
/// arrived — the supervisor died without reporting (fork failure,
/// crash). There is no reliable status to decode.
final class PosixSupervisorLost extends PosixSupervisorOutcome {
  const PosixSupervisorLost();
}

/// Reads the supervisor's status pipe in a background isolate. The
/// supervisor writes two fixed 4-byte native-endian frames —
/// `[target_pid][raw_status]` — then closes its write end. Unlike
/// `waitpid`, a pipe read is reaper-immune: the bytes are buffered in
/// the kernel and can only be read by us, so the exit status can't be
/// stolen by the Dart VM's SIGCHLD handler.
///
/// [pid] resolves as soon as the first frame lands (so `kill` can
/// target the real grandchild promptly); [outcome] resolves when the
/// second frame lands, or as [PosixSupervisorLost] on early EOF.
class PosixStatusChannel {
  PosixStatusChannel._(
    this._pid,
    this._outcome,
    this._receivePort,
    this._isolateCompleter,
  );

  /// Start reading [statusReadFd] (the read end of the status pipe;
  /// the caller keeps ownership and closes it during teardown).
  factory PosixStatusChannel.start(int statusReadFd) {
    final pidCompleter = Completer<int>();
    final outcomeCompleter = Completer<PosixSupervisorOutcome>();
    final receivePort = ReceivePort();
    final isolateCompleter = Completer<Isolate>();

    var targetPid = 0;
    receivePort.listen((msg) {
      if (msg is! (String, int)) return;
      final (tag, value) = msg;
      switch (tag) {
        case 'pid':
          targetPid = value;
          if (!pidCompleter.isCompleted) pidCompleter.complete(value);
        case 'exited':
          if (!outcomeCompleter.isCompleted) {
            outcomeCompleter.complete(
              PosixSupervisorExited(targetPid: targetPid, rawStatus: value),
            );
          }
          receivePort.close();
        case 'lost':
          if (!pidCompleter.isCompleted) {
            pidCompleter.completeError(const PosixSupervisorLost());
          }
          if (!outcomeCompleter.isCompleted) {
            outcomeCompleter.complete(const PosixSupervisorLost());
          }
          receivePort.close();
      }
    });

    unawaited(
      Isolate.spawn(
            _statusEntry,
            _StatusArgs(receivePort.sendPort, statusReadFd),
          )
          .then(isolateCompleter.complete)
          .catchError(isolateCompleter.completeError),
    );

    return PosixStatusChannel._(
      pidCompleter,
      outcomeCompleter,
      receivePort,
      isolateCompleter,
    );
  }

  final Completer<int> _pid;
  final Completer<PosixSupervisorOutcome> _outcome;
  final ReceivePort _receivePort;
  final Completer<Isolate> _isolateCompleter;

  /// The target pid, from the first frame. Completes with a
  /// [PosixSupervisorLost] error if the supervisor is lost before the
  /// first frame arrives.
  Future<int> get pid => _pid.future;

  /// The terminal outcome: [PosixSupervisorExited] or
  /// [PosixSupervisorLost].
  Future<PosixSupervisorOutcome> get outcome => _outcome.future;

  /// Kill the reader isolate and close the receive port. If the
  /// channel hasn't resolved yet, surfaces [PosixSupervisorLost] so
  /// pending awaiters don't hang. Mirrors `PosixReadLoop`'s
  /// kill-on-close-with-timeout so a blocked read doesn't pin a worker.
  Future<void> shutdown() async {
    try {
      final iso = await _isolateCompleter.future.timeout(
        const Duration(milliseconds: 100),
      );
      iso.kill(priority: Isolate.immediate);
    } on Object {
      // Isolate never spawned or already gone — fine.
    }
    _receivePort.close();
    if (!_pid.isCompleted) {
      _pid.completeError(const PosixSupervisorLost());
    }
    if (!_outcome.isCompleted) {
      _outcome.complete(const PosixSupervisorLost());
    }
  }
}

class _StatusArgs {
  _StatusArgs(this.sendPort, this.fd);
  final SendPort sendPort;
  final int fd;
}

/// Blocking-reads the two 4-byte frames off the status pipe,
/// forwarding `('pid', n)` after the first and `('exited', status)`
/// after the second. Any early EOF/error sends `('lost', 0)`.
void _statusEntry(_StatusArgs args) {
  final buffer = SupervisorFrameBuffer();
  var pidSent = false;
  while (!buffer.isComplete) {
    final result = posixFd.read(args.fd, buffer.remaining);
    switch (result) {
      case FdReadSucceeded(:final bytes):
        if (bytes.isEmpty) {
          // EOF before a full pair of frames → supervisor lost.
          args.sendPort.send(('lost', 0));
          return;
        }
        buffer.add(bytes);
        if (!pidSent && buffer.hasPid) {
          args.sendPort.send(('pid', buffer.targetPid));
          pidSent = true;
        }
      case FdReadFailed():
        args.sendPort.send(('lost', 0));
        return;
    }
  }
  args.sendPort.send(('exited', buffer.rawStatus));
}
