import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A vertical group of content rows with a shared left gutter indicator
/// and a soft divider below.
///
/// The gutter encodes selection / modified state:
/// - `selected` → delegated to [SelectionGutter] (`┃` in `theme.primary`)
/// - `modified` → `│` in `theme.info`
/// - else → `' '` (invisible) in `theme.muted`
///
/// The gutter is painted across every visual row of the rendered content
/// — including multi-line text, wrapped descriptions, or a `maxLines: N`
/// editor — so the indicator is always continuous.
@view
class SelectableBlock extends StatelessComponent {
  const SelectableBlock({
    required this.rows,
    this.selected = false,
    this.modified = false,
    this.hovered = false,
    this.showSeparator = true,
    super.key,
  });

  final List<Component> rows;
  final bool selected;
  final bool modified;
  final bool hovered;
  final bool showSeparator;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );

    final guttered = selected
        ? SelectionGutter(selected: true, child: inner)
        : Guttered(
            glyph: modified ? '│' : ' ',
            color: modified ? theme.info : theme.muted,
            child: inner,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(color: hovered ? theme.hover : null, child: guttered),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Divider(),
          ),
      ],
    );
  }
}
