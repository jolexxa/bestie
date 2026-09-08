import 'package:agentic_terminal/src/agent_terminal.dart';
import 'package:agentic_terminal/src/terminal_spawn_result.dart';
import 'package:process_host/process_host.dart';

/// Spawns [AgentTerminal]s for a caller that must not know how terminals
/// are created on this platform.
// ignore: one_member_abstracts
abstract interface class TerminalHost {
  /// Spawns a terminal running [executable] in [environment], retaining
  /// [scrollbackBytes] of history, confined by [sandbox] if one is given.
  Future<TerminalSpawnResult> spawn({
    required int rows,
    required int cols,
    required int scrollbackBytes,
    required Map<String, String> environment,
    String? executable,
    List<String> arguments,
    ShellLaunchMode launchMode,
    bool forwardHostResize,
    Sandbox? sandbox,
  });
}

/// Spawns terminals through a [ProcessHost] and attaches a screen model
/// to whatever comes back.
final class ProcessHostTerminalHost implements TerminalHost {
  /// Spawns the underlying processes through [host].
  const ProcessHostTerminalHost(this.host);

  /// Spawns the processes this host wraps in a screen model.
  final ProcessHost host;

  @override
  Future<TerminalSpawnResult> spawn({
    required int rows,
    required int cols,
    required int scrollbackBytes,
    required Map<String, String> environment,
    String? executable,
    List<String> arguments = const [],
    ShellLaunchMode launchMode = ShellLaunchMode.login,
    bool forwardHostResize = true,
    Sandbox? sandbox,
  }) async {
    final clampedRows = rows < 1 ? 1 : rows;
    final clampedCols = cols < 1 ? 1 : cols;
    return switch (host.terminal(
      executable: executable,
      arguments: arguments,
      environment: environment,
      launchMode: launchMode,
      initialRows: clampedRows,
      initialCols: clampedCols,
      forwardHostResize: forwardHostResize,
      sandbox: sandbox,
    )) {
      ProcessSpawnSucceeded(:final process) => TerminalSpawnSucceeded(
        AgentTerminal.attach(
          process,
          rows: clampedRows,
          cols: clampedCols,
          scrollbackBytes: scrollbackBytes,
        ),
      ),
      ProcessSpawnFailed(:final failure) => TerminalSpawnFailed(failure),
    };
  }
}
