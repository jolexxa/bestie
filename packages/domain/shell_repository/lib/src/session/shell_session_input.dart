import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:intentions/intentions.dart';

/// Inputs to one shell session's state machine.
@model
sealed class ShellSessionInput {
  const ShellSessionInput();
}

/// Bring the shell up. Sent once when the session is created, and again by
/// `ShellSession.restart` after an exit.
@model
final class StartShell extends ShellSessionInput {
  const StartShell();
}

/// The async spawn settled — with a terminal, or with the reason there
/// isn't one.
@model
final class SpawnSettled extends ShellSessionInput {
  const SpawnSettled(this.result);

  /// What the host answered with.
  final TerminalSpawnResult result;
}

/// The child process exited.
@model
final class ShellExited extends ShellSessionInput {
  const ShellExited(this.exit);

  /// How the child terminated.
  final ProcessExit exit;
}
