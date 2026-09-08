import 'package:bestie_chat_view/src/view/details/state/agent_shell_data.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_input.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_output.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/shell_repository.dart';

/// Base state for what a tool call shows of its shell.
@model
sealed class AgentShellState extends StateLogic<AgentShellState> {
  AgentShellState() {
    on<AttachmentPublished>(_onPublished);
  }

  AgentShellData get data => get<AgentShellData>();

  Transition _onPublished(AttachmentPublished input) {
    final drawn = data.surface;
    final wasLoading = this is AgentShellPending;
    switch (input.attachment) {
      case AgentShellLive(:final session):
        if (identical(session, data.session)) return toSelf();
        data.session = session;
        data.releaseRecorded();
      case AgentShellReplay(:final surface):
        data
          ..session = null
          ..releaseRecorded()
          ..recorded = surface;
      case AgentShellLoading():
        data.session = null;
        data.releaseRecorded();
      case AgentShellNone():
        data.session = null;
        data.releaseRecorded();
    }

    final loading = input.attachment is AgentShellLoading;

    if (identical(drawn, data.surface) && loading == wasLoading) {
      return toSelf();
    }

    return _route(loading: loading);
  }

  /// Lands on whether there is a terminal to draw, a record on its way, or
  /// nothing — telling the view each time the answer changes.
  Transition _route({required bool loading}) {
    output(const AttachmentChanged());
    if (data.surface != null) {
      return this is AgentShellAttached ? toSelf() : to<AgentShellAttached>();
    }
    if (loading) {
      return this is AgentShellPending ? toSelf() : to<AgentShellPending>();
    }
    return this is NoAgentShell ? toSelf() : to<NoAgentShell>();
  }
}

/// The call has nothing to show — it is not a shell call, or it ran one and
/// kept no record of it.
@model
final class NoAgentShell extends AgentShellState {}

/// The call left a record and it is being read and parsed off the main
/// isolate; the chrome is drawn while the contents are on their way.
@model
final class AgentShellPending extends AgentShellState {}

/// There is a terminal to draw, live or replayed.
@model
final class AgentShellAttached extends AgentShellState {
  TerminalSurface get surface => data.surface!;

  /// Whether what is drawn is the shell itself rather than a record of it.
  bool get isLive => data.session != null;
}
