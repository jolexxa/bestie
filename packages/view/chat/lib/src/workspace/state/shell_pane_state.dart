import 'package:bestie_chat_view/src/workspace/state/shell_pane_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_output.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// Base state for one rendered shell surface, following a [TerminalSurface]
/// somebody else owns. Lifecycle is the only axis that changes what it draws.
@model
sealed class ShellPaneState extends StateLogic<ShellPaneState> {
  ShellPaneState() {
    on<SurfaceChanged>(_onSurfaceChanged);
    on<ScrollView>(_onScrollView);
    on<FollowOutput>(_onFollowOutput);
    on<WriteToChild>(_onWriteToChild);
    on<ResizeSurface>(_onResizeSurface);
  }

  /// What this pane draws — a live shell, or a transcript put back on a
  /// terminal of its own. The pane does not distinguish them.
  TerminalSurface get surface => get<TerminalSurface>();

  /// Whether the terminal cursor is worth drawing — a shell that has exited
  /// leaves a transcript, and a transcript has no cursor.
  bool get showCursor => false;

  /// Lands in the state that matches what the surface can show now.
  Transition _routeLifecycle() {
    if (surface.screen == null) return _stay<ShellPaneSpawning>();
    if (surface.exited) return _stay<ShellPaneExited>();
    return _stay<ShellPaneLive>();
  }

  /// Singleton states make `to<Current>()` a silent no-op, so a re-entry has
  /// to be spelled as staying put.
  Transition _stay<T extends ShellPaneState>() =>
      this is T ? toSelf() : to<T>();

  /// Every change re-routes, not just lifecycle ones: a first chunk of output
  /// is also how a spawning pane learns it has a screen to draw.
  Transition _onSurfaceChanged(SurfaceChanged _) {
    output(const PaneUpdated());
    return _routeLifecycle();
  }

  Transition _onScrollView(ScrollView input) =>
      _moveViewTo(surface.viewOffset + input.rows);

  Transition _onFollowOutput(FollowOutput _) => _moveViewTo(0);

  /// Repaints only when the viewport actually moved — the offset clamps to
  /// what the scrollback holds, so asking to scroll past the top is a no-op.
  Transition _moveViewTo(int offset) {
    final before = surface.viewOffset;
    if (surface.setViewOffset(offset) == before) return toSelf();
    output(const PaneUpdated());
    return toSelf();
  }

  Transition _onWriteToChild(WriteToChild input) {
    surface.write(input.bytes);
    return toSelf();
  }

  Transition _onResizeSurface(ResizeSurface input) {
    surface.resize(rows: input.rows, cols: input.cols);
    return toSelf();
  }
}

/// The shell has not put anything on screen yet — the spawn is still in
/// flight, or it was refused.
@model
final class ShellPaneSpawning extends ShellPaneState {}

/// There is a screen to draw.
@model
sealed class ShellPaneReady extends ShellPaneState {
  /// The rendered output. Non-null by construction — a surface that loses its
  /// screen routes back to [ShellPaneSpawning].
  Screen get screen => surface.screen!;
}

/// The shell is running and the surface is live.
@model
final class ShellPaneLive extends ShellPaneReady {
  @override
  bool get showCursor => true;
}

/// The shell exited, leaving its output readable.
@model
final class ShellPaneExited extends ShellPaneReady {}
