import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/shell_session_request.dart';

/// Mutable state shared across one session's states.
@model
final class ShellSessionData {
  ShellSessionData({required this.host, required this.request});

  /// Brings up the terminal. Which mechanism does so — a POSIX helper
  /// binary, ConPTY — stays below this layer.
  final TerminalHost host;

  /// Describes the shell this session brings up.
  final ShellSessionRequest request;

  /// The live terminal. Non-null once the spawn has succeeded.
  AgentTerminal? terminal;

  /// The child's exit status, once it has exited.
  ProcessExit? exit;

  /// Why the last spawn was refused, if it was. Structured rather than
  /// pre-formatted — rendering a message is the view's business.
  SpawnFailure? failure;
}
