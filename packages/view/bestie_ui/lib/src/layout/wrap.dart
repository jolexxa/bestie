import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A flow layout that wraps children onto the next row when they
/// exceed the available width.
///
/// Each child is provided as a record with its known cell width
/// and the child component. Measure text with
/// [UnicodeWidth.stringWidth]; character count is wrong for wide
/// and multi-codepoint glyphs.
@view
class Wrap extends StatelessComponent {
  const Wrap({
    required this.items,
    this.spacing = 0,
    this.runSpacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  /// Children with their known widths in terminal cells.
  final List<({int width, Component child})> items;

  /// Horizontal spacing between items (in cells).
  final int spacing;

  /// Vertical spacing between rows (in cells).
  final int runSpacing;

  /// Vertical alignment of items within each row when their heights
  /// differ. Defaults to [CrossAxisAlignment.center] for parity with
  /// the underlying [Row], but flow layouts of labelled columns
  /// (e.g. `HintColumns`) typically want [CrossAxisAlignment.start]
  /// so titles sit atop their hints across columns.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.toInt();
        final rows = <List<Component>>[];
        var currentRow = <Component>[];
        var currentWidth = 0;

        for (final item in items) {
          final needed = currentRow.isEmpty ? item.width : spacing + item.width;

          if (currentWidth + needed > maxWidth && currentRow.isNotEmpty) {
            rows.add(currentRow);
            currentRow = <Component>[];
            currentWidth = 0;
          }

          if (currentRow.isNotEmpty && spacing > 0) {
            currentRow.add(SizedBox(width: spacing.toDouble()));
            currentWidth += spacing;
          }

          currentRow.add(item.child);
          currentWidth += item.width;
        }

        if (currentRow.isNotEmpty) rows.add(currentRow);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0 && runSpacing > 0)
                SizedBox(height: runSpacing.toDouble()),
              Row(
                crossAxisAlignment: crossAxisAlignment,
                children: rows[i],
              ),
            ],
          ],
        );
      },
    );
  }
}
