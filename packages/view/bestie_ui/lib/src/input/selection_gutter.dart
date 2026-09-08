import 'package:bestie_ui/src/layout/guttered.dart';
import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A 2-col left gutter that paints a vertical selection bar across every
/// visual row of its child when [selected] is true.
@view
class SelectionGutter extends StatelessComponent {
  const SelectionGutter({
    required this.selected,
    required this.child,
    this.hovered = false,
    super.key,
  });

  final bool selected;
  final bool hovered;
  final Component child;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Guttered(
      glyph: selected || hovered ? '┃' : ' ',
      color: selected ? theme.primary : theme.muted,
      child: child,
    );
  }
}
