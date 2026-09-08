import 'package:intentions/intentions.dart';
import 'package:shell_repository/shell_repository.dart';

/// What a tool call has to show of the shell it ran in: a live shell, a record
/// being read back, or nothing — the answers to one question, on one stream.
@model
sealed class AgentShellAttachment {
  const AgentShellAttachment();
}

/// The call holds a live shell.
@model
final class AgentShellLive extends AgentShellAttachment {
  const AgentShellLive(this.session);

  /// The shell itself, which is already drawable and already changing.
  final TerminalSurface session;
}

/// The call left a record, and it is being read and parsed off the main
/// isolate — draw the chrome now, the contents follow.
@model
final class AgentShellLoading extends AgentShellAttachment {
  const AgentShellLoading();
}

/// The record has been parsed into a [surface] ready to draw.
@model
final class AgentShellReplay extends AgentShellAttachment {
  const AgentShellReplay(this.surface);

  /// The transcript put back on a terminal, built off the main isolate.
  final TerminalSurface surface;
}

/// The call ran no shell, or belongs to a conversation whose records have
/// been let go of.
@model
final class AgentShellNone extends AgentShellAttachment {
  const AgentShellNone();
}
