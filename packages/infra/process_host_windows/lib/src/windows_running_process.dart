import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:process_host/process_host.dart';
import 'package:win32_dart/win32_dart.dart';

/// A [RunningProcess] backed by a child launched through ConPTY (terminal
/// mode) or three pipes (piped mode).
///
/// Exit status comes from a [ProcessExitWaiter] blocking on the process
/// handle — Windows has no signals, so a terminated child reports
/// [ProcessExited] with the terminate code, never [ProcessSignaled].
class WindowsRunningProcess implements RunningProcess {
  /// A ConPTY child: output merged onto the pseudoconsole, stdin written to
  /// the input pipe, resize forwarded to the console.
  @internal
  WindowsRunningProcess.terminal({
    required ChildProcess child,
    required PseudoConsole console,
    required Pipe inputPipe,
    required Pipe outputPipe,
    required WindowsReadLoop outputLoop,
    required ProcessExitWaiter exitWaiter,
    Sandbox? sandbox,
    Stream<Winsize>? hostResizeStream,
  }) : this._(
         child: child,
         console: console,
         stdinPipe: inputPipe,
         stdoutLoop: outputLoop,
         stderrLoop: null,
         exitWaiter: exitWaiter,
         pipes: [inputPipe, outputPipe],
         sandbox: sandbox,
         hostResizeStream: hostResizeStream,
       );

  /// A piped child: split stdout / stderr, stdin closable to signal EOF.
  @internal
  WindowsRunningProcess.piped({
    required ChildProcess child,
    required Pipe stdinPipe,
    required Pipe stdoutPipe,
    required Pipe stderrPipe,
    required WindowsReadLoop stdoutLoop,
    required WindowsReadLoop stderrLoop,
    required ProcessExitWaiter exitWaiter,
    Sandbox? sandbox,
  }) : this._(
         child: child,
         console: null,
         stdinPipe: stdinPipe,
         stdoutLoop: stdoutLoop,
         stderrLoop: stderrLoop,
         exitWaiter: exitWaiter,
         pipes: [stdinPipe, stdoutPipe, stderrPipe],
         sandbox: sandbox,
         hostResizeStream: null,
       );

  WindowsRunningProcess._({
    required ChildProcess child,
    required PseudoConsole? console,
    required Pipe stdinPipe,
    required WindowsReadLoop stdoutLoop,
    required WindowsReadLoop? stderrLoop,
    required ProcessExitWaiter exitWaiter,
    required List<Pipe> pipes,
    required this.sandbox,
    required Stream<Winsize>? hostResizeStream,
  }) : _child = child,
       _console = console,
       _stdinPipe = stdinPipe,
       _stdoutLoop = stdoutLoop,
       _stderrLoop = stderrLoop,
       _pipes = pipes,
       _waiter = exitWaiter {
    _exit = _waiter.exitCode.then(
      (code) =>
          code == null ? const ProcessSupervisorLost() : ProcessExited(code),
    );
    if (hostResizeStream != null) {
      _hostResizeSub = hostResizeStream.listen(
        (size) => resize(rows: size.rows, cols: size.cols),
      );
    }
  }

  @override
  final Sandbox? sandbox;

  final ChildProcess _child;
  final PseudoConsole? _console;
  final Pipe _stdinPipe;
  final WindowsReadLoop _stdoutLoop;
  final WindowsReadLoop? _stderrLoop;
  final List<Pipe> _pipes;
  final ProcessExitWaiter _waiter;

  late final Future<ProcessExit> _exit;
  StreamSubscription<Winsize>? _hostResizeSub;
  var _stdinClosed = false;
  var _closed = false;

  @override
  Future<int> get pid => Future.value(_child.pid);

  @override
  Stream<List<int>> get stdout => _stdoutLoop.stream;

  @override
  Stream<List<int>> get stderr =>
      _stderrLoop?.stream ?? const Stream<List<int>>.empty();

  @override
  Future<ProcessExit> get exit => _exit;

  @override
  void writeBytes(List<int> bytes) {
    _guardStdinOpen();
    _stdinPipe.write(bytes);
  }

  @override
  void writeString(String input) => writeBytes(utf8.encode(input));

  @override
  Future<void> closeStdin() async {
    _stdinClosed = true;
    // A pty has no separate stdin end — send EOT via [writeBytes] instead — so
    // this is a Dart-layer guard only in terminal mode.
    if (_console == null) _stdinPipe.closeWriteEnd();
  }

  @override
  void resize({required int rows, required int cols}) {
    _console?.resize(rows: rows, cols: cols);
  }

  /// The OpenConsole we ship re-wraps its own buffer on
  /// `ResizePseudoConsole`, then addresses the screen absolutely.
  @override
  bool get childRepaintsOnResize => _console != null;

  @override
  Future<bool> kill({bool force = false}) async =>
      _child.terminate() is ChildTerminateSucceeded;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    await _hostResizeSub?.cancel();
    _hostResizeSub = null;

    // Kill the wait isolate before the handle it holds is closed.
    await _waiter.close();

    // Closing the console emits a final frame to the output pipe, so it must
    // happen while the read loop is still draining.
    _console?.close();
    await _stdoutLoop.close();
    await _stderrLoop?.close();

    for (final pipe in _pipes) {
      pipe.close();
    }
    _child.close();
  }

  void _guardStdinOpen() {
    if (_stdinClosed) {
      throw StateError('RunningProcess stdin has been closed.');
    }
  }
}
