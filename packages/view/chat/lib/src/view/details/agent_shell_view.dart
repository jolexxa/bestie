import 'dart:async';

import 'package:bestie_chat_view/src/view/details/state/agent_shell_cubit.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_state.dart';
import 'package:bestie_chat_view/src/workspace/shell_pane.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The shell a tool call ran in, drawn on the same read-only terminal the user
/// watches agent shells through and filling the space it is given.
@view
class AgentShellView extends StatefulComponent {
  const AgentShellView({
    required this.toolCallId,
    this.fallback,
    super.key,
  });

  /// The call whose shell to follow.
  final String toolCallId;

  /// Drawn instead when the call ran no shell and left no record of one.
  final Component? fallback;

  @override
  State<AgentShellView> createState() => _AgentShellViewState();
}

class _AgentShellViewState extends State<AgentShellView> {
  late final AgentShellCubit _cubit = AgentShellCubit(
    logic: AgentShellLogic(
      shell: RepositoryProvider.of<ShellUseCase>(context),
      toolCallId: component.toolCallId,
    ),
  );

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Component build(BuildContext context) =>
      BlocBuilder<AgentShellCubit, AgentShellState>(
        bloc: _cubit,
        builder: (context, state) => switch (state) {
          NoAgentShell() => component.fallback ?? const SizedBox.shrink(),
          AgentShellPending() => Container(
            color: AppTheme.of(context).background,
          ),
          AgentShellAttached(:final surface) => ShellPane(
            key: ValueKey(surface),
            surface: surface,
            interactive: false,
          ),
        },
      );
}
