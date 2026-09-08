import 'dart:math' as math;

import 'package:bestie_ui/src/input/hoverable.dart';
import 'package:bestie_ui/src/layout/pane_resize_handle.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Split the panes started life with.
const double _defaultFraction = 2 / 3;

/// Neither pane may be dragged narrower than this unless told otherwise.
const int defaultMinPaneWidth = 20;
const String _panesOpen = '─►';
const String _panesClosed = '◄─';

/// Two panes side by side, the boundary draggable via the left pane's
/// right-most column, and the right pane collapsible from a toggle floating
/// over the left pane's top-right corner.
///
/// Requires a bounded width.
@view
class SplitPane extends StatefulComponent {
  const SplitPane({
    required this.left,
    required this.right,
    this.minLeftWidth = defaultMinPaneWidth,
    this.minRightWidth = defaultMinPaneWidth,
    super.key,
  });

  /// Narrowest terminal width at which a page shows its details pane beside
  /// its list; anything narrower gets the list alone.
  static const double breakpoint = 61;

  /// Whether [constraints] are wide enough to show both panes.
  static bool fits(BoxConstraints constraints) =>
      constraints.maxWidth >= breakpoint;

  final Component left;
  final Component right;

  /// Columns the left pane keeps however far the boundary is dragged.
  final int minLeftWidth;

  /// Columns the right pane keeps however far the boundary is dragged.
  final int minRightWidth;

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  /// Held as a fraction rather than a width so the split keeps its proportions
  /// when the terminal is resized.
  double _fraction = _defaultFraction;

  bool _collapsed = false;

  int _clampLeftWidth(int width, int total) {
    final maxLeft = total - component.minRightWidth;
    if (maxLeft < component.minLeftWidth) return (total / 2).round();
    return width.clamp(component.minLeftWidth, maxLeft);
  }

  Component _withToggle(Component left) {
    return Stack(
      children: [
        left,
        Positioned(
          top: 0,
          right: 1,
          child: _CollapseToggle(
            collapsed: _collapsed,
            onToggle: () => setState(() => _collapsed = !_collapsed),
          ),
        ),
      ],
    );
  }

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = math.max(1, constraints.maxWidth.floor());
        final leftWidth = _collapsed
            ? total
            : _clampLeftWidth((_fraction * total).round(), total);
        return Row(
          children: [
            SizedBox(
              width: leftWidth.toDouble(),
              child: PaneResizeHandle(
                enabled: !_collapsed,
                onResize: (width) => setState(() {
                  _fraction = _clampLeftWidth(width, total) / total;
                }),
                child: _withToggle(component.left),
              ),
            ),
            if (!_collapsed) Expanded(child: component.right),
          ],
        );
      },
    );
  }
}

class _CollapseToggle extends StatelessComponent {
  const _CollapseToggle({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    return Hoverable(
      onTap: onToggle,
      builder: (context, {required hovered}) => Text(
        collapsed ? _panesClosed : _panesOpen,
        style: TextStyle(
          color: hovered ? appTheme.primary : appTheme.muted,
          backgroundColor: hovered ? appTheme.hover : appTheme.background,
        ),
      ),
    );
  }
}
