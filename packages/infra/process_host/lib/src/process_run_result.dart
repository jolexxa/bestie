import 'package:process_host/src/process_exit.dart';
import 'package:process_host/src/sandbox.dart';
import 'package:process_host/src/spawn_failure.dart';

/// The outcome of a short-lived `ProcessRunner.run`: either the child
/// ran to completion, or it never started.
sealed class ProcessRunResult {
  const ProcessRunResult();
}

/// The child ran and terminated; [exit] describes how.
final class ProcessRunCompleted extends ProcessRunResult {
  /// Wraps the child's [exit] status and the [sandbox] it ran under.
  const ProcessRunCompleted(this.exit, {this.sandbox});

  /// How the child terminated.
  final ProcessExit exit;

  /// The confinement the child ran under, or null if it ran free.
  final Sandbox? sandbox;
}

/// The child never started, so it has no exit status.
final class ProcessRunNotStarted extends ProcessRunResult {
  /// Wraps the [failure] that prevented the spawn.
  const ProcessRunNotStarted(this.failure);

  /// Why the spawn was refused.
  final SpawnFailure failure;
}
