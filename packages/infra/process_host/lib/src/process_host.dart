import 'package:process_host/src/process_spawn_result.dart';
import 'package:process_host/src/sandbox.dart';
import 'package:process_host/src/shell_launch_mode.dart';

/// Spawns child processes, supervised so exit status is reliable.
abstract interface class ProcessHost {
  /// Spawn a child on a fresh terminal, sized to the host window unless
  /// [initialRows] / [initialCols] say otherwise. [environment] is the
  /// child's whole environment; [sandbox] confines it, and must be of
  /// this host's platform kind.
  ProcessSpawnResult terminal({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments,
    int? initialRows,
    int? initialCols,
    ShellLaunchMode launchMode = ShellLaunchMode.login,
    bool forwardHostResize = true,
    Sandbox? sandbox,
  });

  /// Spawn a child with dedicated pipes: stdin plus split
  /// `stdout` / `stderr`. [environment] is the child's whole environment;
  /// [sandbox] confines it, and must be of this host's platform kind.
  ProcessSpawnResult piped({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments,
    ShellLaunchMode launchMode = ShellLaunchMode.raw,
    Sandbox? sandbox,
  });
}
