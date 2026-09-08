import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:posix_spawner/posix_spawner.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/src/wait_status.dart';

const _sigkill = 9;
const _sigterm = 15;

/// A [RunningProcess] backed by a child under the native `spawner`
/// supervisor.
class PosixRunningProcess implements RunningProcess {
  /// Wraps a posix_dart supervised process. When [hostResizeStream] is
  /// provided, host resize events are forwarded to the child's tty
  /// until [close].
  @internal
  PosixRunningProcess(
    this._process, {
    this.sandbox,
    Stream<Winsize>? hostResizeStream,
  }) {
    _exit = _process.exitStatus.then(processExitFromOutcome);
    if (hostResizeStream != null) {
      _hostResizeSub = hostResizeStream.listen(
        (size) => resize(rows: size.rows, cols: size.cols),
      );
    }
  }

  @override
  final Sandbox? sandbox;

  final PosixSupervisedProcess _process;
  late final Future<ProcessExit> _exit;
  StreamSubscription<Winsize>? _hostResizeSub;
  var _stdinClosed = false;

  @override
  Future<int> get pid => _process.pid;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<ProcessExit> get exit => _exit;

  @override
  void writeBytes(List<int> bytes) {
    _guardStdinOpen();
    _process.write(bytes);
  }

  @override
  void writeString(String input) {
    _guardStdinOpen();
    _process.write(utf8.encode(input));
  }

  @override
  Future<void> closeStdin() async {
    _stdinClosed = true;
    await _process.closeStdin();
  }

  @override
  void resize({required int rows, required int cols}) {
    _process.resize(rows: rows, cols: cols);
  }

  /// A pty resize raises `SIGWINCH`; what the child does about it is up
  /// to the child, and the grid is left as it was.
  @override
  bool get childRepaintsOnResize => false;

  /// Sends `SIGTERM`, or `SIGKILL` when [force] is set. Returns `false`
  /// if there was no live target to signal — either the supervisor was
  /// lost before reporting a pid, or the target is already gone.
  @override
  Future<bool> kill({bool force = false}) =>
      _process.kill(force ? _sigkill : _sigterm);

  @override
  Future<void> close() async {
    await _hostResizeSub?.cancel();
    _hostResizeSub = null;
    await _process.close();
  }

  void _guardStdinOpen() {
    if (_stdinClosed) {
      throw StateError('RunningProcess stdin has been closed.');
    }
  }
}
