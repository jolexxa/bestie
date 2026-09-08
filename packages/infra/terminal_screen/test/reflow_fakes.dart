// A grid the reflow pass can read and write without a Buffer. The pass
// works in packed ints below the string boundary, so a character per
// column is a faithful stand-in and assertions stay readable.

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/reflow.dart';

/// Rows are given a column per character:
///
/// - `' '` a blank cell
/// - `'_'` a space carrying styling — visible, so never trimmed
/// - `'['` the left half of a double-width cluster, `']'` its
///   continuation
/// - `'^'` the column a break gave up to a cluster that would not fit
/// - anything else a single-width glyph
class FakeReflowSource implements ReflowSource {
  /// Build a grid from [rows], every one the same width.
  FakeReflowSource(
    this.rows, {
    List<bool>? wrapped,
    Map<int, int>? pinned,
  }) : _wrapped = wrapped ?? List<bool>.filled(rows.length, false),
       _pinned = pinned ?? const <int, int>{} {
    for (final row in rows) {
      if (row.length != cols) {
        throw ArgumentError('every row must be $cols columns: "$row"');
      }
    }
  }

  /// The grid, one string per row.
  final List<String> rows;

  final List<bool> _wrapped;
  final Map<int, int> _pinned;

  @override
  int get rowCount => rows.length;

  @override
  int get cols => rows.isEmpty ? 0 : rows.first.length;

  @override
  bool wrappedAt(int row) => _wrapped[row];

  @override
  bool isBlankAt(int row, int col) => rows[row][col] == ' ';

  @override
  CellWidth widthAt(int row, int col) => switch (rows[row][col]) {
    '[' => CellWidth.wide,
    ']' => CellWidth.continuation,
    '^' => CellWidth.spacerHead,
    _ => CellWidth.single,
  };

  @override
  int pinnedLengthAt(int row) => _pinned[row] ?? 0;
}

/// Collects what a reflow emitted. Cells never written show as `?`, so
/// a gap in the emission rules fails loudly instead of reading blank.
class FakeRowSink implements RowSink {
  /// Collect rows [cols] columns wide, reading cells out of [source].
  FakeRowSink(this.source, {required this.cols});

  /// Where copied cells come from.
  final FakeReflowSource source;

  @override
  final int cols;

  /// Emitted rows, in order.
  final List<String> rows = <String>[];

  /// Whether each emitted row continues the one above it.
  final List<bool> wrapped = <bool>[];

  final List<List<String>> _cells = <List<String>>[];

  @override
  int beginRow({required bool wrapped}) {
    _cells.add(List<String>.filled(cols, '?'));
    this.wrapped.add(wrapped);
    rows.add('');
    return _cells.length - 1;
  }

  @override
  void copyCells({
    required int row,
    required int col,
    required int destColumn,
    required int count,
  }) {
    for (var i = 0; i < count; i++) {
      _cells.last[destColumn + i] = source.rows[row][col + i];
    }
    _sync();
  }

  @override
  void blankCells(int destColumn, int count) {
    for (var i = 0; i < count; i++) {
      _cells.last[destColumn + i] = ' ';
    }
    _sync();
  }

  @override
  void markSpacerHead(int destColumn) {
    _cells.last[destColumn] = '^';
    _sync();
  }

  void _sync() => rows[rows.length - 1] = _cells.last.join();
}

/// Wrap bits for a run of [rowCount] rows that all continue the first.
List<bool> continuationRun(int rowCount) => [
  false,
  for (var i = 1; i < rowCount; i++) true,
];
