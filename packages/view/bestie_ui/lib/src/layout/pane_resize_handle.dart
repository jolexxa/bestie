import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// Pointer capture is not part of nocterm's public barrel.
// ignore: implementation_imports
import 'package:nocterm/src/binding/mouse_router.dart';
// Painting the handle demands the canvas, which is not exported.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';
// The barrel exports the MouseRegion component, not its render object.
// ignore: implementation_imports
import 'package:nocterm/src/rendering/mouse_region.dart';
// The mouse tracker that owns pointer capture is not exported either.
// ignore: implementation_imports
import 'package:nocterm/src/rendering/mouse_tracker.dart';

/// Heavy box-drawing vertical, painted over the child's right-most column while
/// the handle is hot.
const String handleGlyph = '┃';

/// Marks the middle of a hot handle as the grab point.
const String grabGlyph = '╋';

/// Turns the right-most column of [child] into a drag handle.
///
/// The column is left to the child while idle — in practice the list's
/// scrollbar rail, which doubles as the divider between panes.
@view
class PaneResizeHandle extends StatelessComponent {
  const PaneResizeHandle({
    required this.child,
    required this.onResize,
    this.enabled = true,
    super.key,
  });

  final Component child;

  /// Whether the column responds to the mouse at all. A disabled handle is
  /// inert and never highlights — there is nothing on the other side to size.
  final bool enabled;

  /// The left pane's desired width in columns, reported as the handle is
  /// dragged. Values are unclamped and may fall outside the child's bounds.
  final void Function(int leftWidth) onResize;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    return _PaneResizeHandleRenderObject(
      onResize: onResize,
      enabled: enabled,
      hoverColor: appTheme.info,
      dragColor: appTheme.highVisibility,
      child: child,
    );
  }
}

class _PaneResizeHandleRenderObject extends SingleChildRenderObjectComponent {
  const _PaneResizeHandleRenderObject({
    required this.onResize,
    required this.enabled,
    required this.hoverColor,
    required this.dragColor,
    required super.child,
  });

  final void Function(int) onResize;
  final bool enabled;
  final Color hoverColor;
  final Color dragColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderPaneResizeHandle(
      onResize: onResize,
      enabled: enabled,
      hoverColor: hoverColor,
      dragColor: dragColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaneResizeHandle renderObject,
  ) {
    final restyled =
        renderObject.enabled != enabled ||
        renderObject.hoverColor != hoverColor ||
        renderObject.dragColor != dragColor;
    renderObject
      ..onResize = onResize
      ..enabled = enabled
      ..hoverColor = hoverColor
      ..dragColor = dragColor;
    if (restyled) renderObject.markNeedsPaint();
  }
}

/// Render object for a pane resize handle.
@view
class RenderPaneResizeHandle extends RenderMouseRegion {
  RenderPaneResizeHandle({
    required this.onResize,
    required this.enabled,
    required this.hoverColor,
    required this.dragColor,
  }) {
    onHover = _handleMouse;
    onExit = (_) => _setHovered(value: false);
  }

  void Function(int) onResize;
  bool enabled;
  Color hoverColor;
  Color dragColor;

  bool _hovered = false;
  bool _dragging = false;

  /// The binding's mouse tracker, used for pointer capture during a drag.
  MouseTracker? get _mouseTracker {
    final binding = NoctermBinding.instance;
    return binding is MouseRouter ? binding.mouseTracker : null;
  }

  /// A captured drag arrives as hover events with no hit testing, so press,
  /// move and release are derived from button-state transitions.
  void _handleMouse(MouseEvent event) {
    if (event.button == MouseButton.wheelUp ||
        event.button == MouseButton.wheelDown) {
      return;
    }

    if (!enabled) return _setHovered(value: false);

    final localX = event.x - globalPaintOffsetOf(this).dx;
    final leftDown = event.pressed || event.isPrimaryButtonDown;

    if (_dragging) {
      if (leftDown) {
        onResize(localX.round() + 1);
        return;
      }
      _dragging = false;
      _mouseTracker?.releaseCapture();
      _setHovered(value: _isOnHandle(localX));
      return;
    }

    if (leftDown && _isOnHandle(localX)) {
      _dragging = true;
      _mouseTracker?.capture(annotation!, event);
      markNeedsPaint();
      return;
    }

    _setHovered(value: _isOnHandle(localX));
  }

  // The upper bound matters during a capture, where the pointer — and so the
  // release that ends the drag — can land beyond the child's right edge.
  bool _isOnHandle(double localX) =>
      localX >= size.width - 1 && localX < size.width;

  void _setHovered({required bool value}) {
    if (_hovered == value) return;
    _hovered = value;
    markNeedsPaint();
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (!enabled || (!_hovered && !_dragging)) return;

    final style = TextStyle(color: _dragging ? dragColor : hoverColor);
    final x = offset.dx + size.width - 1;

    canvas
      ..fillRect(
        Rect.fromLTWH(x, offset.dy, 1, size.height),
        handleGlyph,
        style: style,
      )
      ..drawText(
        Offset(x, offset.dy + (size.height / 2).floorToDouble()),
        grabGlyph,
        style: style,
      );
  }
}
