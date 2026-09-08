import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A section boundary with its name set in: `─ Output ─────`. One muted row
/// instead of a heading plus its blank line.
@view
class DetailSectionRule extends StatelessComponent {
  const DetailSectionRule(this.label, {super.key});

  final String label;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        final head = '─ $label ';
        // Cells, not code units: a label carrying a wide glyph would overrun
        // the row it is supposed to end at.
        final fill =
            width - UnicodeWidth.stringWidth(head) - detailRailInset.floor();
        return Padding(
          padding: const EdgeInsets.only(left: detailRailInset),
          child: Text(
            fill > 0 ? '$head${'─' * fill}' : head,
            style: TextStyle(color: theme.muted),
          ),
        );
      },
    );
  }
}
