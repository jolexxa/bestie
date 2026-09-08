import 'dart:math' as math;

import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// Pointer capture is not part of nocterm's public barrel.
// ignore: implementation_imports
import 'package:nocterm/src/binding/mouse_router.dart';
// Custom scrollbar style demands it.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';
// Absorbing the hit test on grip rows demands the mouse result type.
// ignore: implementation_imports
import 'package:nocterm/src/rendering/mouse_hit_test.dart';
// The mouse tracker that owns pointer capture is not exported either.
// ignore: implementation_imports
import 'package:nocterm/src/rendering/mouse_tracker.dart';

/// Light box-drawing vertical for the always-present rail.
const String railGlyph = '│';

/// Heavy box-drawing vertical for the grip.
const String gripGlyph = '┃';

/// Full block for a hot grip.
const String gripHotGlyph = '█';

/// A scrollbar that can be optionally shown for scrollable widgets.
///
/// Typically used by wrapping a scrollable widget like [SingleChildScrollView]
/// or [ListView]. The scrollbar automatically detects whether the scrollable
/// is reversed from the controller's axis direction.
@view
class AppScrollbar extends StatefulComponent {
  const AppScrollbar({
    required this.child,
    super.key,
    this.controller,
    this.thumbVisibility = false,
    this.showRailWhenEmpty = true,
    this.thickness = 1.0,
    this.trackColor,
    this.thumbColor,
  });

  /// The widget below this widget in the tree.
  ///
  /// The scrollbar will be painted on top of this child. The child should be
  /// a scrollable widget.
  final Component child;

  /// The [ScrollController] used to control the scrollable widget.
  ///
  /// If null, the scrollbar will attempt to find a controller from the child.
  final ScrollController? controller;

  /// Indicates whether the scrollbar thumb should be always visible.
  ///
  /// When false, the scrollbar will only be visible while scrolling.
  /// When true, the scrollbar will always be visible.
  final bool thumbVisibility;

  /// Whether the full-height rail is drawn even when the content fits and
  /// there is nothing to scroll.
  final bool showRailWhenEmpty;

  /// The thickness of the scrollbar in the cross axis of the scrollable.
  final double thickness;

  /// The color of the scrollbar track.
  final Color? trackColor;

  /// The color of the scrollbar thumb.
  final Color? thumbColor;

  @override
  State<AppScrollbar> createState() => _ScrollbarState();
}

class _ScrollbarState extends State<AppScrollbar> {
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = component.controller;
  }

  @override
  void didUpdateComponent(AppScrollbar oldWidget) {
    super.didUpdateComponent(oldWidget);
    if (component.controller != oldWidget.controller) {
      _controller = component.controller;
    }
  }

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    return _ScrollbarRenderObjectWidget(
      controller: _controller,
      thumbVisibility: component.thumbVisibility,
      showRailWhenEmpty: component.showRailWhenEmpty,
      thickness: component.thickness,
      trackColor: component.trackColor ?? appTheme.mutedAccent,
      thumbColor: component.thumbColor ?? appTheme.scrollGrip,
      hoverColor: appTheme.info,
      dragColor: appTheme.highVisibility,
      child: component.child,
    );
  }
}

class _ScrollbarRenderObjectWidget extends SingleChildRenderObjectComponent {
  const _ScrollbarRenderObjectWidget({
    required this.controller,
    required this.thumbVisibility,
    required this.showRailWhenEmpty,
    required this.thickness,
    required this.trackColor,
    required this.thumbColor,
    required this.hoverColor,
    required this.dragColor,
    required super.child,
  });

  final ScrollController? controller;
  final bool thumbVisibility;
  final bool showRailWhenEmpty;
  final double thickness;
  final Color trackColor;
  final Color thumbColor;
  final Color hoverColor;
  final Color dragColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderScrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      showRailWhenEmpty: showRailWhenEmpty,
      thickness: thickness,
      trackColor: trackColor,
      thumbColor: thumbColor,
      hoverColor: hoverColor,
      dragColor: dragColor,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderScrollbar renderObject) {
    renderObject
      ..controller = controller
      ..thumbVisibility = thumbVisibility
      ..showRailWhenEmpty = showRailWhenEmpty
      ..thickness = thickness
      ..trackColor = trackColor
      ..thumbColor = thumbColor
      ..hoverColor = hoverColor
      ..dragColor = dragColor;
  }
}

/// Render object for a scrollbar.
@view
class RenderScrollbar extends RenderObject
    with
        RenderObjectWithChildMixin<RenderObject>,
        MouseTrackerAnnotationProvider {
  RenderScrollbar({
    required bool thumbVisibility,
    required bool showRailWhenEmpty,
    required double thickness,
    required Color trackColor,
    required Color thumbColor,
    required Color hoverColor,
    required Color dragColor,
    ScrollController? controller,
  }) : _controller = controller,
       _thumbVisibility = thumbVisibility,
       _showRailWhenEmpty = showRailWhenEmpty,
       _thickness = thickness,
       _trackColor = trackColor,
       _thumbColor = thumbColor,
       _hoverColor = hoverColor,
       _dragColor = dragColor {
    _controller?.addListener(_handleScrollUpdate);
    _annotation = MouseTrackerAnnotation(
      onHover: _handleMouse,
      onExit: (_) => _setHovered(value: false),
      renderObject: this,
    );
  }

  ScrollController? _controller;
  ScrollController? get controller => _controller;
  set controller(ScrollController? value) {
    if (_controller != value) {
      _controller?.removeListener(_handleScrollUpdate);
      _controller = value;
      _controller?.addListener(_handleScrollUpdate);
      markNeedsPaint();
    }
  }

  Color _trackColor;
  Color get trackColor => _trackColor;
  set trackColor(Color value) {
    if (_trackColor != value) {
      _trackColor = value;
      markNeedsPaint();
    }
  }

  Color _thumbColor;
  Color get thumbColor => _thumbColor;
  set thumbColor(Color value) {
    if (_thumbColor != value) {
      _thumbColor = value;
      markNeedsPaint();
    }
  }

  Color _hoverColor;
  Color get hoverColor => _hoverColor;
  set hoverColor(Color value) {
    if (_hoverColor != value) {
      _hoverColor = value;
      markNeedsPaint();
    }
  }

  Color _dragColor;
  Color get dragColor => _dragColor;
  set dragColor(Color value) {
    if (_dragColor != value) {
      _dragColor = value;
      markNeedsPaint();
    }
  }

  /// Whether the bar is reversed from the controller's axis direction.
  bool get _isReversed => _controller?.isReversed ?? false;

  bool _thumbVisibility;
  bool get thumbVisibility => _thumbVisibility;
  set thumbVisibility(bool value) {
    if (_thumbVisibility != value) {
      _thumbVisibility = value;
      markNeedsPaint();
    }
  }

  bool _showRailWhenEmpty;
  bool get showRailWhenEmpty => _showRailWhenEmpty;
  set showRailWhenEmpty(bool value) {
    if (_showRailWhenEmpty != value) {
      _showRailWhenEmpty = value;
      markNeedsPaint();
    }
  }

  double _thickness;
  double get thickness => _thickness;
  set thickness(double value) {
    if (_thickness != value) {
      _thickness = value;
      markNeedsLayout();
    }
  }

  void _handleScrollUpdate() {
    markNeedsPaint();
  }

  MouseTrackerAnnotation? _annotation;

  @override
  MouseTrackerAnnotation? get annotation => _annotation;

  bool _hovered = false;
  bool _dragging = false;

  /// Rows between the pointer and the grip's top edge at press time, so the
  /// grip doesn't jump to center itself under the pointer.
  int _dragAnchor = 0;

  /// The binding's mouse tracker, used for pointer capture during a drag.
  MouseTracker? get _mouseTracker {
    final binding = NoctermBinding.instance;
    return binding is MouseRouter ? binding.mouseTracker : null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _annotation?.validForMouseTracker = true;
  }

  @override
  void detach() {
    // The render object can detach mid-dispatch; invalidating the annotation
    // keeps the mouse tracker from calling back into a disposed object.
    _annotation?.validForMouseTracker = false;
    super.detach();
  }

  @override
  void dispose() {
    // Unmount disposes without detaching; stale annotations must not keep
    // receiving events from the mouse tracker's hovered set.
    _annotation?.validForMouseTracker = false;
    _controller?.removeListener(_handleScrollUpdate);
    super.dispose();
  }

  /// Grip geometry in track cells, shared by paint and input.
  ///
  /// Null when there is nothing to scroll. The grip is capped one cell short
  /// of the track so tiny overflows still leave room to drag.
  _GripGeometry? get _grip {
    final controller = _controller;
    if (controller == null || controller.maxScrollExtent <= 0) return null;

    final trackCells = size.height.toInt();
    final scrollFraction =
        controller.viewportDimension /
        (controller.maxScrollExtent + controller.viewportDimension);

    final gripCells = (size.height * scrollFraction)
        .ceil()
        .clamp(1, math.max(1, trackCells - 1))
        .toInt();

    // offset 0 → top, maxScrollExtent → bottom; inverted when reversed.
    final scrollProgress = _isReversed
        ? 1.0 - (controller.offset / controller.maxScrollExtent)
        : controller.offset / controller.maxScrollExtent;

    final maxStart = math.max(0, trackCells - gripCells);
    final thumbStart = (scrollProgress * maxStart).round().clamp(0, maxStart);
    return _GripGeometry(
      thumbStart: thumbStart,
      gripCells: gripCells,
      maxStart: maxStart,
    );
  }

  bool _isOnGrip(int localY) {
    final grip = _grip;
    if (grip == null) return false;
    return localY >= grip.thumbStart &&
        localY < grip.thumbStart + grip.gripCells;
  }

  /// A captured drag arrives as hover events with no hit testing, so press,
  /// move and release are derived from button-state transitions.
  void _handleMouse(MouseEvent event) {
    // Wheel events arrive with pressed=true and must never read as a press.
    if (event.button == MouseButton.wheelUp ||
        event.button == MouseButton.wheelDown) {
      return;
    }

    final localY = (event.y - globalPaintOffsetOf(this).dy).round();
    final leftDown = event.pressed || event.isPrimaryButtonDown;

    if (_dragging) {
      if (leftDown) {
        _dragTo(localY);
        return;
      }
      _dragging = false;
      _mouseTracker?.releaseCapture();
      _setHovered(value: _isOnGrip(localY));
      markNeedsPaint();
      return;
    }

    final grip = _grip;
    if (leftDown && grip != null && _isOnGrip(localY)) {
      _dragging = true;
      _dragAnchor = localY - grip.thumbStart;
      _mouseTracker?.capture(annotation!, event);
      markNeedsPaint();
      return;
    }

    _setHovered(value: _isOnGrip(localY));
  }

  /// Maps the pointer row to a scroll offset. A captured pointer routinely
  /// leaves the track, so progress is clamped rather than trusted.
  void _dragTo(int localY) {
    final grip = _grip;
    if (grip == null || grip.maxStart == 0) return;

    final controller = _controller!;
    final progress = ((localY - _dragAnchor) / grip.maxStart).clamp(0.0, 1.0);
    final target = _isReversed ? 1.0 - progress : progress;
    controller.jumpTo(target * controller.maxScrollExtent);
  }

  void _setHovered({required bool value}) {
    if (_hovered == value) return;
    _hovered = value;
    markNeedsPaint();
  }

  @override
  bool hitTestSelf(Offset position) {
    // Hit test if position is on the scrollbar area
    return position.dx >= size.width - thickness;
  }

  @override
  bool hitTest(HitTestResult result, {required Offset position}) {
    if (!Rect.fromLTWH(0, 0, size.width, size.height).contains(position)) {
      return false;
    }

    if (hitTestChildren(result, position: position)) return true;
    if (!hitTestSelf(position)) return false;

    if (result is MouseHitTestResult) {
      result.addWithPosition(target: this, localPosition: position);
      if (_isOnGrip(position.dy.toInt())) result.absorb();
    }
    return true;
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    // Layout child with slightly reduced width to make room for scrollbar
    final childConstraints = BoxConstraints(
      minWidth: math.max(0, constraints.minWidth - thickness),
      maxWidth: math.max(0, constraints.maxWidth - thickness),
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );

    child!.layout(childConstraints, parentUsesSize: true);

    // Our size includes the scrollbar
    size = constraints.constrain(
      Size(
        child!.size.width + thickness,
        child!.size.height,
      ),
    );
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (child == null) return;

    // Paint the child first
    child!.paint(canvas, offset);

    // Paint scrollbar if we have a controller and should show it
    if (_controller != null && thumbVisibility) {
      _paintScrollbar(canvas, offset);
    }
  }

  void _paintScrollbar(TerminalCanvas canvas, Offset offset) {
    final controller = _controller!;

    // Nothing to scroll and the rail isn't wanted as a divider — draw
    // nothing so the screen stays clean until content overflows.
    if (!_showRailWhenEmpty && controller.maxScrollExtent <= 0) return;

    final scrollbarX = size.width - thickness;
    final trackHeight = size.height;

    // Draw the full-height rail (no arrows). When [showRailWhenEmpty] it
    // reads as a gapless divider even with nothing to scroll.
    for (var y = 0; y < trackHeight.toInt(); y++) {
      canvas.drawText(
        offset + Offset(scrollbarX, y.toDouble()),
        railGlyph,
        style: TextStyle(color: _trackColor),
      );
    }

    // No grip when there is nothing to scroll — just the bare rail.
    final grip = _grip;
    if (grip == null) return;

    final thumbEnd = grip.thumbStart + grip.gripCells;
    final hot = _dragging || _hovered;
    final gripColor = _dragging
        ? _dragColor
        : _hovered
        ? _hoverColor
        : _thumbColor;
    final glyph = hot ? gripHotGlyph : gripGlyph;

    for (var y = grip.thumbStart; y < thumbEnd; y++) {
      canvas.drawText(
        offset + Offset(scrollbarX, y.toDouble()),
        glyph,
        style: TextStyle(color: gripColor),
      );
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child == null) return false;

    // Check if the position is in the scrollbar area
    if (position.dx >= size.width - thickness) {
      // Click is on scrollbar, don't pass to child
      return false;
    }

    return child!.hitTest(result, position: position);
  }
}

/// Where the grip sits on the track, in whole cells.
class _GripGeometry {
  const _GripGeometry({
    required this.thumbStart,
    required this.gripCells,
    required this.maxStart,
  });

  /// Row of the grip's top cell.
  final int thumbStart;

  /// Rows the grip covers.
  final int gripCells;

  /// Rows of travel available to [thumbStart].
  final int maxStart;
}
