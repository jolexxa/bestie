import 'package:process_host/src/process_exit.dart';
import 'package:process_host/src/sandbox.dart';
import 'package:process_host/src/spawn_failure.dart';

/// The outcome of a captured `ProcessRunner.runCaptured`: either the child ran
/// to completion with its output collected, or it never started.
sealed class ProcessCaptureResult {
  const ProcessCaptureResult();
}

/// The child ran and terminated; [exit] describes how, and [stdout] / [stderr]
/// hold every byte it wrote.
final class ProcessCaptureCompleted extends ProcessCaptureResult {
  /// Wraps the child's [exit] status, captured [stdout] / [stderr], and
  /// the [sandbox] it ran under.
  const ProcessCaptureCompleted({
    required this.exit,
    required this.stdout,
    required this.stderr,
    this.sandbox,
  });

  /// How the child terminated.
  final ProcessExit exit;

  /// Everything the child wrote to stdout.
  final List<int> stdout;

  /// Everything the child wrote to stderr.
  final List<int> stderr;

  /// The confinement the child ran under, or null if it ran free.
  final Sandbox? sandbox;
}

/// The child never started, so it produced no output.
final class ProcessCaptureNotStarted extends ProcessCaptureResult {
  /// Wraps the [failure] that prevented the spawn.
  const ProcessCaptureNotStarted(this.failure);

  /// Why the spawn was refused.
  final SpawnFailure failure;
}
