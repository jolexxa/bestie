import 'dart:async';

import 'package:bestie_chat_view/src/workspace/state/shell_workspace_data.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_output.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_state.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/shell_repository.dart';

// ── Logic block ───────────────────────────────────────

@PartOf(ShellWorkspaceCubit)
final class ShellWorkspaceLogic extends LogicBlock<ShellWorkspaceState> {
  ShellWorkspaceLogic({required ShellUseCase shell}) {
    set(ShellWorkspaceData()..shells = shell.userShells);
    set(shell);
    set(DetailsActiveState());
    set(ShellFocusedState());
    set(ShellUnfocusedState());
  }

  StreamSubscription<List<ShellSessionSummary>>? _rosterSub;

  @override
  Transition getInitialState() => to<DetailsActiveState>();

  @override
  void onStart() {
    final shell = get<ShellUseCase>();
    get<ShellWorkspaceData>().shells = shell.userShells;
    _rosterSub = shell.userShellsStream.listen(
      (shells) => input(RosterUpdated(shells)),
    );
  }

  @override
  void onStop() {
    unawaited(_rosterSub?.cancel());
    _rosterSub = null;
  }
}

/// View model for the shell workspace tab host.
@viewModel
class ShellWorkspaceCubit extends LogicBloc<ShellWorkspaceState> {
  ShellWorkspaceCubit({required ShellWorkspaceLogic logic}) : super(logic) {
    binding.onOutput<StateUpdated>((_) => emit(state));
  }

  /// Shows the tab registered under [id].
  void select(String id) => input(SelectTab(id));

  /// Adopts the pinned tabs the current selection can show, in strip order.
  void syncPinnedTabs(List<String> pinnedIds) =>
      input(PinnedTabsSynced(pinnedIds));

  /// Brings the pinned area forward on its sticky tab, past any shell tab.
  void showPinnedArea() => input(const PinnedAreaShown());

  /// Opens a user shell sized to the content area and shows it.
  void openShell({required int rows, required int cols}) =>
      input(OpenShell(rows: rows, cols: cols));

  /// Closes the tab registered under [id], tearing down its shell.
  void closeTab(ShellSessionId id) => input(CloseTab(id));

  /// Routes a raw left press: over the active pane takes the keyboard,
  /// anywhere else releases it.
  void clickedAt({required bool overActivePane}) =>
      input(ClickedAt(overActivePane: overActivePane));
}
