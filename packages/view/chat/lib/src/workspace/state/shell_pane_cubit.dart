import 'dart:async';

import 'package:bestie_chat_view/src/workspace/state/shell_pane_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_output.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_state.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/shell_repository.dart';

// ── Logic block ───────────────────────────────────────

@PartOf(ShellPaneCubit)
final class ShellPaneLogic extends LogicBlock<ShellPaneState> {
  ShellPaneLogic({required TerminalSurface surface}) {
    set(surface);
    set(ShellPaneSpawning());
    set(ShellPaneLive());
    set(ShellPaneExited());
  }

  StreamSubscription<void>? _changes;

  /// A surface that came up before this pane mounted already published its
  /// state, so the opening state is read off it rather than waited for.
  @override
  Transition getInitialState() {
    final surface = get<TerminalSurface>();
    if (surface.screen == null) return to<ShellPaneSpawning>();
    if (surface.exited) return to<ShellPaneExited>();
    return to<ShellPaneLive>();
  }

  @override
  void onStart() {
    _changes = get<TerminalSurface>().changes.listen(
      (_) => input(const SurfaceChanged()),
    );
  }

  @override
  void onStop() {
    unawaited(_changes?.cancel());
    _changes = null;
  }
}

/// View model for one rendered shell surface.
@viewModel
class ShellPaneCubit extends LogicBloc<ShellPaneState> {
  ShellPaneCubit({required ShellPaneLogic logic}) : super(logic) {
    binding.onOutput<PaneUpdated>((_) => emit(state));
  }

  /// Sends [bytes] to the child's stdin.
  void write(List<int> bytes) => input(WriteToChild(bytes));

  /// Reports the cell size the surface was laid out at.
  void resize({required int rows, required int cols}) =>
      input(ResizeSurface(rows: rows, cols: cols));

  /// Scrolls the viewport by [rows]; positive goes up into history.
  void scrollBy(int rows) => input(ScrollView(rows));

  /// Snaps the viewport back to the live region.
  void followOutput() => input(const FollowOutput());
}
