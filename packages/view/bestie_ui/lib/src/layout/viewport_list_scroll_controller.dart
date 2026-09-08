import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// An [AutoScrollController] for a lazy list that can also answer questions
/// about what its viewport is showing, so a page can decide between moving
/// the viewport by a fraction and stepping onto a neighboring item.
@model
class ViewportListScrollController extends AutoScrollController {
  ViewportListScrollController({super.autoScrollThreshold});

  RenderListViewport? _viewport;

  @override
  void attach(Object renderObject) {
    super.attach(renderObject);
    if (renderObject is RenderListViewport) _viewport = renderObject;
  }

  @override
  void detach(Object renderObject) {
    super.detach(renderObject);
    if (identical(_viewport, renderObject)) _viewport = null;
  }

  /// Moves the viewport by [fraction] of its height, stopping at the ends.
  void pageBy(double fraction, {required bool up}) {
    final distance = viewportDimension * fraction;
    scrollBy(up ? -distance : distance);
  }

  /// Whether item [index] is laid out with any part of it in the viewport.
  bool isItemVisible(int index) {
    final placement = _viewport?.getItemOffsetAndExtent(index);
    if (placement == null) return false;
    final (itemOffset, itemExtent) = placement;
    return itemOffset < _viewportEnd && itemOffset + itemExtent > offset;
  }

  /// Whether item [index] is laid out with its first line in the viewport.
  bool isItemStartVisible(int index) {
    final placement = _viewport?.getItemOffsetAndExtent(index);
    if (placement == null) return false;
    final (itemOffset, _) = placement;
    return itemOffset >= offset && itemOffset < _viewportEnd;
  }

  /// The lowest index among the visible items, or null when nothing is.
  int? firstVisibleIndex(int itemCount) {
    for (var index = 0; index < itemCount; index++) {
      if (isItemVisible(index)) return index;
    }
    return null;
  }

  /// The highest index among the visible items, or null when nothing is.
  int? lastVisibleIndex(int itemCount) {
    for (var index = itemCount - 1; index >= 0; index--) {
      if (isItemVisible(index)) return index;
    }
    return null;
  }

  double get _viewportEnd => offset + viewportDimension;
}
