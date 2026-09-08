import 'package:bestie_ui/src/controls/app_scrollbar.dart';
import 'package:bestie_ui/src/terminal/terminal_grid.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// Presentational terminal surface: renders a [Screen] with a scrollback
/// scrollbar and text selection, and reports the size it was laid out at.
///
/// It holds no session and routes no keyboard input — an interactive pane
/// wraps this to add those. The read-only agent-session viewer uses it
/// directly. Either way the surface reflows with its size; the owner acts on
/// [onResize].
@view
class TerminalView extends StatefulComponent {
  const TerminalView({
    required this.screen,
    this.showCursor = true,
    this.onResize,
    this.onSelectionCompleted,
    this.gridKey,
    super.key,
  });

  /// The screen to render.
  final Screen screen;

  /// Keys the inner grid so an owner can locate its render object — an
  /// interactive pane needs the grid's origin to translate host mouse
  /// coordinates into the child's space.
  final Key? gridKey;

  /// Whether the cursor cell is drawn.
  final bool showCursor;

  /// Reports the cell dimensions the surface was laid out at, each time they
  /// change. The owner resizes the session; the screen follows.
  final void Function({required int rows, required int cols})? onResize;

  /// A completed, non-empty text selection, for the owner to copy however it
  /// likes.
  final void Function(String text)? onSelectionCompleted;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final ScrollController _scrollController = ScrollController();

  /// True while the screen's state is being pushed into the controller.
  /// `updateMetrics` reports a metrics change back synchronously, and that is
  /// our own echo rather than a user drag.
  bool _syncingScroll = false;

  /// The offset last pushed into the controller. The same metrics change is
  /// also reported *after* the frame, long past [_syncingScroll] — a
  /// notification still carrying this offset is that echo arriving late.
  double? _pushedOffset;

  /// The last box we actually laid out at.
  Size? _lastFiniteSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollbarDragged);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollbarDragged)
      ..dispose();
    super.dispose();
  }

  /// The grip was dragged: mirror the controller's offset onto the screen's
  /// viewport. Only a genuine drag moves the controller away from the offset
  /// [_syncScrollController] last pushed, so everything else is our own echo
  /// and must not move the view — a resize re-anchors the screen's offset,
  /// and honouring a stale echo would undo that.
  void _onScrollbarDragged() {
    if (_syncingScroll) return;
    if (_scrollController.offset == _pushedOffset) return;
    _moveView(_scrollController.offset.round());
  }

  /// Mirror the screen's scrollback into the [ScrollController] so the
  /// scrollbar paints a thumb that tracks scrollback growth.
  void _syncScrollController(Screen screen) {
    _syncingScroll = true;
    try {
      _scrollController.updateMetrics(
        minScrollExtent: 0,
        maxScrollExtent: screen.maxViewOffset.toDouble(),
        viewportDimension: screen.rows.toDouble(),
        axisDirection: AxisDirection.up,
      );
      final offset = screen.viewOffset.toDouble();
      _pushedOffset = offset;
      if (_scrollController.offset != offset) {
        _scrollController.jumpTo(offset);
      }
    } finally {
      _syncingScroll = false;
    }
  }

  /// Moves the displayed viewport and rebuilds if it actually moved.
  void _moveView(int offset) {
    final screen = component.screen;
    final before = screen.viewOffset;
    if (screen.setViewOffset(offset) == before) return;
    _syncScrollController(screen);
    setState(() {});
  }

  @override
  Component build(BuildContext context) {
    final screen = component.screen;
    _syncScrollController(screen);

    return LayoutBuilder(
      builder: (context, outer) {
        // A `changes`-driven relayout can hand this subtree an unbounded
        // constraint in isolation. A terminal has no pixels to turn into a
        // cell grid then, and `TerminalGrid` sizes itself to the constraint,
        // so an unbounded height would balloon the grid to its full screen and
        // spill out of the pane. Fall back to the last box we laid out at —
        // the real pane — and, failing that, the screen's own size.
        final bounded = outer.maxWidth.isFinite && outer.maxHeight.isFinite;
        if (bounded) {
          _lastFiniteSize = Size(outer.maxWidth, outer.maxHeight);
        }
        final fallback = _lastFiniteSize;
        final maxWidth = outer.maxWidth.isFinite
            ? outer.maxWidth
            : fallback?.width ?? screen.cols.toDouble();
        final maxHeight = outer.maxHeight.isFinite
            ? outer.maxHeight
            : fallback?.height ?? screen.rows.toDouble();
        // Report a resize whenever the box is a real pane measurement — a live
        // bound, or the remembered one we are reflowing back toward. Only a
        // pure screen-size placeholder (never yet laid out) is withheld.
        final reflowing = bounded || fallback != null;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: SelectionArea(
            onSelectionCompleted: (text) {
              if (text.isEmpty) return;
              component.onSelectionCompleted?.call(text);
            },
            child: AppScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth.toInt();
                  final rows = constraints.maxHeight.toInt();
                  if (reflowing &&
                      (rows != screen.rows || cols != screen.cols)) {
                    component.onResize?.call(rows: rows, cols: cols);
                  }
                  return TerminalGrid(
                    key: component.gridKey,
                    screen: screen,
                    showCursor: component.showCursor,
                    onScrolled: () => _syncScrollController(screen),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
