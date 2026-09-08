import 'dart:math' show max;

import 'package:agentic_terminal/agentic_terminal.dart' hide Color;
import 'package:bestie_chat_view/src/workspace/state/shell_pane_cubit.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart' hide MouseButton, MouseEvent;
import 'package:terminal_screen/terminal_screen.dart';

/// Interactive terminal surface: wraps [TerminalView] with keyboard/mouse input
/// routing — scrollback nav keys, mouse forwarding, kitty-sequence decoding.
@view
class InteractiveTerminalView extends StatefulComponent {
  const InteractiveTerminalView({
    required this.screen,
    required this.focused,
    required this.cubit,
    this.onSelectionCompleted,
    this.gridKey,
    super.key,
  });

  /// The screen to render.
  final Screen screen;

  /// Whether keystrokes flow to the child.
  final bool focused;

  /// Takes the decisions this view decodes its way to: what to write, and
  /// where to put the viewport.
  final ShellPaneCubit cubit;

  /// Keys the inner grid so the owner can locate its render object.
  final GlobalKey? gridKey;

  /// A completed, non-empty text selection, for the owner to copy however it
  /// likes.
  final void Function(String text)? onSelectionCompleted;

  @override
  State<InteractiveTerminalView> createState() =>
      _InteractiveTerminalViewState();
}

class _InteractiveTerminalViewState extends State<InteractiveTerminalView> {
  late final GlobalKey _gridKey = component.gridKey ?? GlobalKey();

  final MouseGestureRouter _mouseRouter = MouseGestureRouter();

  /// Routes a raw input chunk.
  bool _onTerminalKey(List<int> bytes) {
    final screen = component.screen;
    final mouseModeOn = screen.modes.mouseMode != MouseMode.off;

    if (!component.focused) {
      if (!mouseModeOn) return false;
      final parsed = parseHostInput(bytes);
      // Only a pure mouse chunk may act while unfocused — keys aren't ours.
      if (parsed.mouseEvents.isEmpty ||
          parsed.bytesWithMouseStripped.isNotEmpty) {
        return false;
      }
      return _forwardMouse(bytes, screen, wheelOnly: true);
    }

    final parsed = parseHostInput(bytes);

    final delta = _scrollKeyDelta(parsed.bytesWithMouseStripped, screen);
    if (delta != null) {
      component.cubit.scrollBy(delta);
      return true;
    }

    if (!mouseModeOn) {
      final keys = parsed.bytesWithMouseStripped;
      // A pure mouse chunk: return `false` so nocterm parses the original
      // bytes and dispatches `MouseEvent`s.
      if (keys.isEmpty) return false;
      component.cubit
        ..followOutput()
        ..write(decodeKittySequence(keys));
      return true;
    }

    // Mouse tracking on: the router decides which gestures are the child's.
    if (parsed.bytesWithMouseStripped.isNotEmpty) {
      component.cubit.followOutput();
    }
    return _forwardMouse(bytes, screen, wheelOnly: false);
  }

  /// Runs [bytes] through the gesture router, forwarding whatever survives
  /// with coordinates translated into the child's space.
  bool _forwardMouse(
    List<int> bytes,
    Screen screen, {
    required bool wheelOnly,
  }) {
    final origin = _gridOrigin();
    final routed = _mouseRouter.route(
      bytes,
      dx: origin.dx.round(),
      dy: origin.dy.round(),
      maxCol: screen.cols,
      maxRow: screen.rows,
      wheelOnly: wheelOnly,
    );
    if (routed.isEmpty) return false;
    component.cubit.write(decodeKittySequence(routed));
    return true;
  }

  /// Intercept scrollback nav keys before they reach the child. Returns the
  /// row delta (positive = up into history) or `null`.
  int? _scrollKeyDelta(List<int> bytes, Screen screen) {
    // ESC [ 5 ; 2 ~ = Shift+PgUp; ESC [ 6 ; 2 ~ = Shift+PgDn.
    if (bytes.length == 6 &&
        bytes[0] == 0x1B &&
        bytes[1] == 0x5B &&
        bytes[3] == 0x3B &&
        bytes[4] == 0x32 &&
        bytes[5] == 0x7E) {
      final page = max(1, screen.rows - 1);
      if (bytes[2] == 0x35) return page;
      if (bytes[2] == 0x36) return -page;
    }
    return null;
  }

  RenderTerminalGrid? _gridRender() {
    final render = (_gridKey.currentContext as Element?)?.renderObject;
    return render is RenderTerminalGrid ? render : null;
  }

  /// The terminal grid's top-left in host cell coordinates. Zero before the
  /// grid has been laid out, which only a same-frame input race could hit.
  Offset _gridOrigin() => _gridRender()?.globalPaintOffset ?? Offset.zero;

  void _resize({required int rows, required int cols}) =>
      component.cubit.resize(rows: rows, cols: cols);

  @override
  Component build(BuildContext context) => InputListener(
    onInput: _onTerminalKey,
    child: TerminalView(
      screen: component.screen,
      gridKey: _gridKey,
      onResize: _resize,
      onSelectionCompleted: component.onSelectionCompleted,
    ),
  );
}
