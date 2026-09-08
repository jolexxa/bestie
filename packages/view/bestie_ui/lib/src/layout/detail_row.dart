import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The left inset every row in a detail pane starts at.
///
/// One rail, never varied — it is most of what makes a column of unrelated
/// blocks read as a single object rather than stacked components. [DetailRow]
/// pads to it, and anything sharing a pane with one measures from it too,
/// which is why it lives here rather than beside any single caller.
const double detailRailInset = 1;

/// A stacked label-over-value row used in detail panels.
///
/// The label sits above its value so a field stays readable in the narrow
/// detail pane, where a fixed two-column layout would wrap or clip. Set
/// [highlighted] on alternating rows for a zebra background that keeps each
/// label/value pair visually grouped.
@view
class DetailRow extends StatelessComponent {
  const DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.highlighted = false,
    super.key,
  });

  /// Row label, shown in secondary color above the value.
  final String label;

  /// Row value.
  final String value;

  /// Optional override for the value text color.
  final Color? valueColor;

  /// Whether to paint the zebra-stripe background behind this row.
  final bool highlighted;

  /// Columns held for the label before the value starts, when both fit on
  /// one row.
  static const int _labelColumn = 13;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final labelStyle = TextStyle(color: theme.secondary);
    final valueStyle = TextStyle(color: valueColor ?? theme.onSurface);

    return Container(
      color: highlighted ? theme.surface : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: detailRailInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Most facts are a short label and a short value, and spending
            // three rows on `path` / `a.dart` / blank is most of why a detail
            // table outgrows the pane it sits in. Pair them on one row when
            // they fit, and only stack when the value genuinely needs the
            // width.
            final width = constraints.maxWidth.floor();
            final paired =
                label.isNotEmpty &&
                !value.contains('\n') &&
                UnicodeWidth.stringWidth(label) < _labelColumn &&
                UnicodeWidth.stringWidth(value) <= width - _labelColumn;

            if (paired) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelColumn.toDouble(),
                    child: Text(label, style: labelStyle),
                  ),
                  Expanded(child: Text(value, style: valueStyle)),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty) Text(label, style: labelStyle),
                Text(value, style: valueStyle),
                const SizedBox(height: 1),
              ],
            );
          },
        ),
      ),
    );
  }
}
