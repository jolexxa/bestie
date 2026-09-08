import 'package:bestie_ui/src/layout/detail_row.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// One row of a [DetailTable]: a label, its value, and an optional value color.
@model
final class DetailRowData {
  const DetailRowData(this.label, this.value, {this.color});

  /// Row label, shown above or beside the value.
  final String label;

  /// Row value.
  final String value;

  /// Optional override for the value text color.
  final Color? color;
}

/// A zebra-striped column of [DetailRow]s.
@view
class DetailTable extends StatelessComponent {
  const DetailTable({required this.rows, super.key});

  /// The rows to draw, top to bottom.
  final List<DetailRowData> rows;

  @override
  Component build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, row) in rows.indexed)
        DetailRow(
          label: row.label,
          value: row.value,
          valueColor: row.color,
          highlighted: i.isOdd,
        ),
    ],
  );
}
