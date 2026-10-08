import 'package:bestie_ui/src/controls/app_scrollbar.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The chrome a scrolling pane wears: the app background, a permanent
/// scrollbar, and the inset that keeps content off its rail.
///
/// Takes a [child] that already scrolls and the controller driving it, so a
/// pane can scroll a lazy list or a single document without either one
/// re-deriving what a scrolling pane looks like.
@view
class ScrollableShell extends StatefulComponent {
  const ScrollableShell({
    required this.controller,
    required this.child,
    this.trackColor,
    this.thumbColor,
    this.enableSelection = false,
    this.onSelectionCompleted,
    this.showRailWhenEmpty = true,
    super.key,
  });

  final ScrollController controller;
  final Component child;
  final Color? trackColor;
  final Color? thumbColor;
  final bool enableSelection;
  final void Function(String)? onSelectionCompleted;

  /// Whether the rail stays drawn when the content fits without scrolling.
  final bool showRailWhenEmpty;

  @override
  State<ScrollableShell> createState() => _ScrollableShellState();
}

class _ScrollableShellState extends State<ScrollableShell> {
  final SelectionController _selection = SelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// A click that never became a drag completes an empty selection.
  void _onSelectionCompleted(String text) {
    if (text.isNotEmpty) component.onSelectionCompleted?.call(text);
    _selection.clear();
  }

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    return Container(
      color: theme.background,
      child: AppScrollbar(
        controller: component.controller,
        thumbVisibility: true,
        showRailWhenEmpty: component.showRailWhenEmpty,
        trackColor: component.trackColor,
        thumbColor: component.thumbColor,
        child: Padding(
          padding: const EdgeInsets.only(right: 1),
          child: component.enableSelection
              ? SelectionArea(
                  controller: _selection,
                  onSelectionCompleted: _onSelectionCompleted,
                  child: component.child,
                )
              : component.child,
        ),
      ),
    );
  }
}
