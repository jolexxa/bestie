import 'package:bestie_ui/src/layout/scrollable_shell.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A lazily built list wearing the standard scrolling-pane chrome.
@view
class ScrollableListShell extends StatelessComponent {
  const ScrollableListShell({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.cacheExtent = 0,
    this.trackColor,
    this.thumbColor,
    this.enableSelection = false,
    this.onSelectionCompleted,
    this.showRailWhenEmpty = true,
    super.key,
  });

  final ScrollController controller;
  final int itemCount;
  final Component Function(BuildContext, int) itemBuilder;
  final int cacheExtent;
  final Color? trackColor;
  final Color? thumbColor;
  final bool enableSelection;
  final void Function(String)? onSelectionCompleted;
  final bool showRailWhenEmpty;

  @override
  Component build(BuildContext context) => ScrollableShell(
    controller: controller,
    trackColor: trackColor,
    thumbColor: thumbColor,
    enableSelection: enableSelection,
    onSelectionCompleted: onSelectionCompleted,
    showRailWhenEmpty: showRailWhenEmpty,
    child: ListView.builder(
      cacheExtent: cacheExtent.toDouble(),
      controller: controller,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    ),
  );
}
