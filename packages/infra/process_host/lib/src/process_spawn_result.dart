import 'package:process_host/src/running_process.dart';
import 'package:process_host/src/spawn_failure.dart';

/// The outcome of asking a `ProcessHost` to spawn a child: either a
/// live [RunningProcess] or the [SpawnFailure] that stopped it.
sealed class ProcessSpawnResult {
  const ProcessSpawnResult();
}

/// The child is running; [process] is the live handle.
final class ProcessSpawnSucceeded extends ProcessSpawnResult {
  /// Wraps the live [process].
  const ProcessSpawnSucceeded(this.process);

  /// The live child handle.
  final RunningProcess process;
}

/// The child never started. Nothing was spawned, so there is nothing to
/// close.
final class ProcessSpawnFailed extends ProcessSpawnResult {
  /// Wraps the [failure] that prevented the spawn.
  const ProcessSpawnFailed(this.failure);

  /// Why the spawn was refused.
  final SpawnFailure failure;
}
