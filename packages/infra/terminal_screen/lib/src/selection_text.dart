import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/reflow.dart';

/// The selectable text of a wrapped cell grid.
class SelectionText {
  /// Holds [text] and the [lines] it was joined from.
  const SelectionText({required this.text, required this.lines});

  /// The whole selection as one string.
  final String text;

  /// The logical lines [text] joins with `\n`.
  final List<String> lines;
}

/// Where each source row's content lands inside the selection text, so a
/// view can map cells and offsets without re-deriving the line rules.
class SelectionMetrics {
  /// Holds the offset index for a selection of [contentLength] chars.
  const SelectionMetrics({
    required this.contentLength,
    required this.rowStarts,
    required this.rowLengths,
    required this.rowContentCols,
  });

  /// Total characters the selection holds — the length of the rendered
  /// text.
  final int contentLength;

  /// Char offset in the text where each source row's content begins.
  final List<int> rowStarts;

  /// Characters each source row contributes.
  final List<int> rowLengths;

  /// Content columns of each source row — trailing blanks trimmed,
  /// wrapped rows kept full — i.e. where cell-to-offset mapping stops.
  final List<int> rowContentCols;
}

/// The last row of [source] that holds content, or `-1` when every row
/// is blank.
int lastContentRow(ReflowSource source) {
  for (var row = source.rowCount - 1; row >= 0; row--) {
    if (trimmedLengthAt(source, row) > 0) return row;
  }
  return -1;
}

/// Chars a content cell contributes: an empty grapheme still occupies a
/// column, so it counts as the one space it renders as.
int _charWidth(int length) => length == 0 ? 1 : length;

/// Measures where every source row's content lands in the selection
/// text.
SelectionMetrics measureSelection(
  ReflowSource source,
  int Function(int row, int col) charLenAt,
) {
  final rowCount = source.rowCount;
  final rowStarts = List<int>.filled(rowCount + 1, 0);
  final rowLengths = List<int>.filled(rowCount, 0);
  final rowContentCols = List<int>.filled(rowCount, 0);
  final last = lastContentRow(source);

  var offset = 0;
  for (var row = 0; row < rowCount; row++) {
    rowStarts[row] = offset;
    final cols = row <= last ? trimmedLengthAt(source, row) : 0;
    rowContentCols[row] = cols;
    var length = 0;
    for (var col = 0; col < cols; col++) {
      if (source.widthAt(row, col) == CellWidth.continuation) continue;
      length += _charWidth(charLenAt(row, col));
    }
    rowLengths[row] = length;
    offset += length;
    if (row < last && !wrapsToNext(source, row)) offset++;
  }
  rowStarts[rowCount] = offset;

  return SelectionMetrics(
    contentLength: offset,
    rowStarts: rowStarts,
    rowLengths: rowLengths,
    rowContentCols: rowContentCols,
  );
}

/// Renders the selection's logical lines, reading each cell's grapheme via
/// [charAt].
List<String> renderSelectionLines(
  ReflowSource source,
  String Function(int row, int col) charAt,
) {
  final last = lastContentRow(source);
  final lines = <String>[];
  final line = StringBuffer();

  for (var row = 0; row <= last; row++) {
    final cols = trimmedLengthAt(source, row);
    for (var col = 0; col < cols; col++) {
      if (source.widthAt(row, col) == CellWidth.continuation) continue;
      final char = charAt(row, col);
      line.write(char.isEmpty ? ' ' : char);
    }
    if (row == last || !wrapsToNext(source, row)) {
      lines.add(line.toString());
      line.clear();
    }
  }

  return lines;
}

/// Renders the selection text, reading each cell's grapheme via
/// [charAt].
SelectionText renderSelection(
  ReflowSource source,
  String Function(int row, int col) charAt,
) {
  final lines = renderSelectionLines(source, charAt);
  return SelectionText(text: lines.join('\n'), lines: lines);
}
