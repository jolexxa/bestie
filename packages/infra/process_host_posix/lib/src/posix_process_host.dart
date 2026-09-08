import 'package:posix_spawner/posix_spawner.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/src/posix_host_winsize_source.dart';
import 'package:process_host_posix/src/posix_running_process.dart';
import 'package:process_host_posix/src/posix_sandbox.dart';
import 'package:process_host_posix/src/wait_status.dart';

/// Spawns children through the native `spawner` supervisor: a pty in
/// [terminal] mode, three pipes in [piped] mode.
class PosixProcessHost implements ProcessHost {
  /// [spawnerBinaryPath] is the absolute path of the native `spawner`
  /// helper (e.g. bestie's `OSPlatform.spawnerBinaryPath`).
  const PosixProcessHost({
    required this.spawnerBinaryPath,
    this.winsizeSource = const PosixHostWinsizeSource(),
  });

  /// Absolute path of the native `spawner` helper binary.
  final String spawnerBinaryPath;

  /// Supplies the host terminal's size, and changes to it.
  final HostWinsizeSource winsizeSource;

  @override
  ProcessSpawnResult terminal({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments = const [],
    int? initialRows,
    int? initialCols,
    ShellLaunchMode launchMode = ShellLaunchMode.login,
    bool forwardHostResize = true,
    covariant PosixSandbox? sandbox,
  }) {
    if (executable == null) return _missingExecutable;

    final host = winsizeSource.current;
    final result = PosixSupervisedSpawn.terminal(
      spawnerBinaryPath: spawnerBinaryPath,
      executable: executable,
      arguments: [...launchMode.flags, ...arguments],
      environment: environment,
      rows: initialRows ?? host.rows,
      cols: initialCols ?? host.cols,
      confineProgram: sandbox?.confineProgram,
    );
    return switch (result) {
      PosixSupervisedSpawnSucceeded(:final process) => ProcessSpawnSucceeded(
        PosixRunningProcess(
          process,
          sandbox: sandbox,
          hostResizeStream: forwardHostResize ? winsizeSource.changes : null,
        ),
      ),
      PosixSupervisedSpawnFailed(:final failure) => ProcessSpawnFailed(
        spawnFailureFrom(failure),
      ),
    };
  }

  @override
  ProcessSpawnResult piped({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments = const [],
    ShellLaunchMode launchMode = ShellLaunchMode.raw,
    covariant PosixSandbox? sandbox,
  }) {
    if (executable == null) return _missingExecutable;

    final result = PosixSupervisedSpawn.piped(
      spawnerBinaryPath: spawnerBinaryPath,
      executable: executable,
      arguments: [...launchMode.flags, ...arguments],
      environment: environment,
      confineProgram: sandbox?.confineProgram,
    );
    return switch (result) {
      PosixSupervisedSpawnSucceeded(:final process) => ProcessSpawnSucceeded(
        PosixRunningProcess(process, sandbox: sandbox),
      ),
      PosixSupervisedSpawnFailed(:final failure) => ProcessSpawnFailed(
        spawnFailureFrom(failure),
      ),
    };
  }

  static const _missingExecutable = ProcessSpawnFailed(
    SpawnFailure(
      function: 'posix_spawnp',
      message: 'No executable was named for the child to run.',
    ),
  );
}
