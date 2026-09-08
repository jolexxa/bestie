import 'package:intentions/intentions.dart';
import 'package:shell_repository/shell_repository.dart';

/// Shared mutable data stored on the agent shell blackboard.
@model
class AgentShellData {
  AgentShellData({required this.toolCallId});

  /// The call whose shell this follows.
  final String toolCallId;

  /// The live shell that call holds now, or null while it holds none.
  TerminalSurface? session;

  /// The call's output put back on a terminal, held once the live shell is
  /// gone. Built off the main isolate by the domain and adopted here.
  TerminalSurface? recorded;

  /// What there is to draw: the live shell, else its recorded replay, else
  /// null.
  TerminalSurface? get surface => session ?? recorded;

  /// Lets go of the recorded terminal, if there is one.
  void releaseRecorded() {
    final surface = recorded;
    recorded = null;
    if (surface is RecordedShell) surface.dispose().ignore();
  }
}
