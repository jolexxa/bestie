import 'dart:async';

import 'package:bestie_chat_view/src/view/details/state/agent_shell_data.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_input.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_output.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_state.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';
import 'package:logic_blocks/logic_blocks.dart';

// ── Logic block ───────────────────────────────────────

@PartOf(AgentShellCubit)
final class AgentShellLogic extends LogicBlock<AgentShellState> {
  AgentShellLogic({required ShellUseCase shell, required String toolCallId}) {
    set(AgentShellData(toolCallId: toolCallId));
    set(shell);
    set(NoAgentShell());
    set(AgentShellPending());
    set(AgentShellAttached());
  }

  StreamSubscription<AgentShellAttachment>? _attachments;

  /// Opens holding nothing — the first attachment arrives a microtask later,
  /// before any frame, so a call with something to show is never seen empty.
  @override
  Transition getInitialState() => to<NoAgentShell>();

  @override
  void onStart() {
    _attachments = get<ShellUseCase>()
        .agentShellFor(get<AgentShellData>().toolCallId)
        .listen((attachment) => input(AttachmentPublished(attachment)));
  }

  @override
  void onStop() {
    unawaited(_attachments?.cancel());
    _attachments = null;
    get<AgentShellData>().releaseRecorded();
  }
}

/// View model for what a tool call has to show of its shell.
@viewModel
class AgentShellCubit extends LogicBloc<AgentShellState> {
  AgentShellCubit({required AgentShellLogic logic}) : super(logic) {
    binding.onOutput<AttachmentChanged>((_) => emit(state));
  }
}
