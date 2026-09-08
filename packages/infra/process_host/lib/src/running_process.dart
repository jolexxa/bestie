import 'dart:async';

import 'package:process_host/src/process_exit.dart';
import 'package:process_host/src/sandbox.dart';

/// A live handle to a supervised child process: separate `stdout` /
/// `stderr` streams and a **reliable** [exit] future, plus stdin,
/// resize, and lifecycle controls.
abstract interface class RunningProcess {
  /// The target's pid, once the platform reports it. Diagnostics /
  /// direct signalling; most callers use [kill].
  Future<int> get pid;

  /// Child output. Merged pty stream in terminal mode; the child's
  /// stdout only in piped mode.
  Stream<List<int>> get stdout;

  /// The child's stderr — a separate stream in piped mode; empty (and
  /// closed) in terminal mode, where output is merged onto the pty.
  Stream<List<int>> get stderr;

  /// Resolves when the child exits, with a decoded [ProcessExit].
  Future<ProcessExit> get exit;

  /// The confinement this child was spawned under, or null if it was
  /// spawned free.
  Sandbox? get sandbox;

  /// Write raw [bytes] to the child's stdin. Throws [StateError] once
  /// [closeStdin] has been called.
  void writeBytes(List<int> bytes);

  /// Write a UTF-8 encoded [input] string to the child's stdin. Throws
  /// [StateError] once [closeStdin] has been called.
  void writeString(String input);

  /// Mark stdin closed so subsequent writes throw. In piped mode this
  /// also closes the stdin channel so the child sees EOF; in terminal
  /// mode there is no separate stdin end, so it is a Dart-layer guard
  /// only (send EOT via [writeBytes] to signal the child).
  Future<void> closeStdin();

  /// Resize the terminal. Terminal mode only; a no-op in piped mode.
  void resize({required int rows, required int cols});

  /// Whether [resize] makes the child redraw the whole screen rather
  /// than just notifying it of the new size.
  bool get childRepaintsOnResize;

  /// Ask the child to stop. [force] requests immediate, uncatchable
  /// termination (`SIGKILL`, `TerminateProcess`); otherwise the child
  /// is asked politely and may clean up first (`SIGTERM`).
  ///
  /// Returns `false` if there was no live target to signal.
  Future<bool> kill({bool force = false});

  /// Tear down: release the underlying process resources. Does NOT stop
  /// the child — call [kill] first if you need it dead. Idempotent.
  Future<void> close();
}
