import 'package:agentic_terminal/src/agent_terminal.dart';
import 'package:process_host/process_host.dart';

/// The outcome of asking a `TerminalHost` for a terminal: either a
/// wired-up [AgentTerminal] or the [SpawnFailure] that stopped it.
sealed class TerminalSpawnResult {
  const TerminalSpawnResult();
}

/// The terminal is live; [terminal] drives it.
final class TerminalSpawnSucceeded extends TerminalSpawnResult {
  /// Wraps the live [terminal].
  const TerminalSpawnSucceeded(this.terminal);

  /// The wired-up terminal session.
  final AgentTerminal terminal;
}

/// No terminal was created. Nothing was spawned, so there is nothing to
/// close.
final class TerminalSpawnFailed extends TerminalSpawnResult {
  /// Wraps the [failure] that prevented the spawn.
  const TerminalSpawnFailed(this.failure);

  /// Why the spawn was refused.
  final SpawnFailure failure;
}
