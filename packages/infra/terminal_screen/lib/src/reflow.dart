import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';

/// The rows a reflow pass reads, addressed as one continuous sequence
/// oldest first, so the scrollback/viewport seam is translated once by
/// the implementation rather than everywhere it is read.
abstract interface class ReflowSource {
  /// Rows available to read.
  int get rowCount;

  /// Columns every source row holds.
  int get cols;

  /// `true` when [row] continues the soft-wrapped line above it.
  bool wrappedAt(int row);

  /// `true` when the cell at [row], [col] carries nothing a reader
  /// would see.
  bool isBlankAt(int row, int col);

  /// Width of the cell at [row], [col].
  CellWidth widthAt(int row, int col);

  /// Columns of [row] that must survive trimming because a tracked
  /// position sits on them — one past the rightmost such column. Zero
  /// when [row] holds no pin.
  int pinnedLengthAt(int row);
}

/// Where re-wrapped rows are written.
abstract interface class RowSink {
  /// Columns every destination row holds.
  int get cols;

  /// Start a destination row, told whether it continues the one above,
  /// and report the row index pins landing on it should record.
  int beginRow({required bool wrapped});

  /// Copy [count] cells from source [row], [col] into the open
  /// destination row at [destColumn].
  void copyCells({
    required int row,
    required int col,
    required int destColumn,
    required int count,
  });

  /// Blank [count] cells of the open destination row from [destColumn].
  void blankCells(int destColumn, int count);

  /// Mark [destColumn] of the open destination row as the column a
  /// break gave up rather than split a cluster across it.
  void markSpacerHead(int destColumn);
}

/// A position carried through a reflow, rewritten in place as the cell
/// it sits on is copied.
class ReflowPin {
  /// Track the position at [row], [col].
  ReflowPin({required this.row, required this.col});

  /// Source row on the way in, destination row on the way out.
  int row;

  /// Source column on the way in, destination column on the way out.
  int col;
}

/// `true` when [row]'s content continues onto the row below.
///
/// The last available row has no successor, so it never wraps; the
/// pending-wrap state carries that case until the next row arrives.
bool wrapsToNext(ReflowSource source, int row) =>
    row + 1 < source.rowCount && source.wrappedAt(row + 1);

/// Columns of [row] that hold real content.
///
/// A row that continues onto the next one keeps all of its cells: the
/// blanks between its last glyph and the margin sit inside the logical
/// line, so they are content. Otherwise trailing blanks are dropped,
/// except that a pinned column always survives — a position parked
/// past the last glyph has nowhere to land if its cell is trimmed.
///
/// The exception is the column a break gave up rather than split a
/// double-width cluster: it is a gap the line never occupied, and
/// counting it as content grows the line by one space on every pass.
/// Printing tags that column, so it is told apart from a space the
/// child actually emitted rather than guessed at.
int trimmedLengthAt(ReflowSource source, int row) {
  if (wrapsToNext(source, row)) {
    final last = source.cols - 1;
    if (source.widthAt(row, last) == CellWidth.spacerHead) return last;
    return source.cols;
  }
  var length = source.cols;
  while (length > 0 && source.isBlankAt(row, length - 1)) {
    length--;
  }
  final pinned = source.pinnedLengthAt(row);
  return length > pinned ? length : pinned;
}

/// The row after the last one of the logical line starting at
/// [firstRow].
int logicalLineEnd(ReflowSource source, int firstRow) {
  var row = firstRow;
  while (row + 1 < source.rowCount && source.wrappedAt(row + 1)) {
    row++;
  }
  return row + 1;
}

/// Total content columns of the logical line starting at [firstRow].
int logicalLineLength(ReflowSource source, int firstRow) {
  final end = logicalLineEnd(source, firstRow);
  var total = 0;
  for (var row = firstRow; row < end; row++) {
    total += trimmedLengthAt(source, row);
  }
  return total;
}

/// Walks the content columns of one logical line, mapping each back to
/// the source row and column holding it.
class LogicalCursor {
  /// Create a cursor reading from [source]. Call [reset] before use.
  LogicalCursor(this.source);

  /// Where the columns are read from.
  final ReflowSource source;

  /// Row after the last one of the current logical line.
  int end = 0;

  /// Content columns the current logical line holds.
  int total = 0;

  /// Source row holding the current column.
  int row = 0;

  /// Column within [row].
  int col = 0;

  /// Content columns [row] holds.
  int length = 0;

  /// Aim at the first content column of the line beginning at
  /// [firstRow], measuring the line on the way.
  void reset(int firstRow) {
    end = logicalLineEnd(source, firstRow);
    row = firstRow;
    col = 0;
    length = trimmedLengthAt(source, firstRow);
    total = length;
    for (var next = firstRow + 1; next < end; next++) {
      total += trimmedLengthAt(source, next);
    }
  }

  /// Columns left in the current source row.
  int get available => length - col;

  /// Move [columns] content columns forward.
  void advance(int columns) {
    var left = columns;
    while (left > 0) {
      if (left < available) {
        col += left;
        return;
      }
      left -= available;
      row++;
      col = 0;
      length = row < end ? trimmedLengthAt(source, row) : 0;
    }
  }

  /// Width of the content column [offset] columns ahead of this one.
  CellWidth widthAhead(int offset) {
    var probeRow = row;
    var probeCol = col;
    var probeLength = length;
    var left = offset;
    while (left > 0) {
      final step = probeLength - probeCol;
      if (left < step) {
        probeCol += left;
        break;
      }
      left -= step;
      probeRow++;
      probeCol = 0;
      probeLength = probeRow < end ? trimmedLengthAt(source, probeRow) : 0;
    }
    return source.widthAt(probeRow, probeCol);
  }
}

/// Columns the next output row takes from a logical line with
/// [remaining] content columns left.
int breakLength(
  LogicalCursor cursor, {
  required int remaining,
  required int newCols,
}) {
  var take = remaining < newCols ? remaining : newCols;
  if (take >= remaining) return take;
  if (cursor.widthAhead(take - 1) == CellWidth.wide) take--;
  return take < 1 ? 1 : take;
}

/// Rows the line [cursor] is aimed at occupies once re-wrapped to
/// [newCols]. Leaves the cursor at the end of that line.
int _rowsFor(LogicalCursor cursor, int newCols) {
  final total = cursor.total;
  if (total == 0) return 1;

  var rows = 0;
  var placed = 0;
  while (placed < total) {
    final take = breakLength(
      cursor,
      remaining: total - placed,
      newCols: newCols,
    );
    cursor.advance(take);
    placed += take;
    rows++;
  }
  return rows;
}

/// Rows the logical line starting at [firstRow] occupies once
/// re-wrapped to [newCols].
int plannedRowCount(
  ReflowSource source, {
  required int firstRow,
  required int newCols,
}) => _rowsFor(LogicalCursor(source)..reset(firstRow), newCols);

/// Rows every logical line in [source] occupies once re-wrapped to
/// [newCols].
int plannedTotalRowCount(ReflowSource source, {required int newCols}) {
  final cursor = LogicalCursor(source);
  var rows = 0;
  var row = 0;
  while (row < source.rowCount) {
    cursor.reset(row);
    rows += _rowsFor(cursor, newCols);
    row = cursor.end;
  }
  return rows;
}

/// Re-wraps a source's logical lines into a sink at the sink's width,
/// carrying tracked positions along with the cells they sit on.
class ReflowWriter {
  /// Re-wrap [source] into [sink], rewriting each of [pins] as its cell
  /// is copied.
  ReflowWriter({
    required this.source,
    required this.sink,
    this.pins = const <ReflowPin>[],
  });

  /// Rows being re-wrapped.
  final ReflowSource source;

  /// Where the re-wrapped rows go.
  final RowSink sink;

  /// Positions rewritten in place as the pass runs.
  final List<ReflowPin> pins;

  /// Blank lines held back until content arrives, so trailing blanks
  /// are never written at all.
  int _heldBlanks = 0;

  /// Pins already moved to where their cell went.
  ///
  /// A relocated pin holds a destination row, and destination rows are
  /// counted in the same numbers as source rows. Without this, a pin
  /// sent to row `n` would match again the moment the read cursor
  /// reached *source* row `n` and move a second time — which narrowing
  /// makes routine, since it lands most pins ahead of rows still to be
  /// read.
  late final Uint8List _placed = Uint8List(pins.length);

  late final LogicalCursor _cursor = LogicalCursor(source);

  /// Re-wrap every logical line from [firstRow] onward.
  void run({int firstRow = 0}) {
    var row = firstRow;
    while (row < source.rowCount) {
      _cursor.reset(row);
      final end = _cursor.end;
      if (_cursor.total == 0) {
        _heldBlanks++;
      } else {
        _releaseBlanks();
        _emitLine();
      }
      row = end;
    }
  }

  void _releaseBlanks() {
    while (_heldBlanks > 0) {
      sink
        ..beginRow(wrapped: false)
        ..blankCells(0, sink.cols);
      _heldBlanks--;
    }
  }

  void _emitLine() {
    final cursor = _cursor;
    final total = cursor.total;
    var placed = 0;
    var continues = false;

    while (placed < total) {
      final take = breakLength(
        cursor,
        remaining: total - placed,
        newCols: sink.cols,
      );
      final destRow = sink.beginRow(wrapped: continues);
      continues = true;

      var destColumn = 0;
      var left = take;
      while (left > 0) {
        final step = left < cursor.available ? left : cursor.available;
        sink.copyCells(
          row: cursor.row,
          col: cursor.col,
          destColumn: destColumn,
          count: step,
        );
        _carryPins(
          cursor,
          destRow: destRow,
          destColumn: destColumn,
          count: step,
        );
        cursor.advance(step);
        destColumn += step;
        left -= step;
      }

      placed += take;
      if (destColumn < sink.cols) {
        sink.blankCells(destColumn, sink.cols - destColumn);
        // A row short of the margin with content still to come gave its
        // last column up to a cluster that would not fit.
        if (placed < total) sink.markSpacerHead(destColumn);
      }
    }
  }

  void _carryPins(
    LogicalCursor cursor, {
    required int destRow,
    required int destColumn,
    required int count,
  }) {
    // Indexed rather than for-in: this runs once per copied range, and
    // an iterator per range is the one allocation left on the path.
    for (var i = 0; i < pins.length; i++) {
      if (_placed[i] != 0) continue;
      final pin = pins[i];
      if (pin.row != cursor.row) continue;
      final offset = pin.col - cursor.col;
      if (offset < 0 || offset >= count) continue;
      _placed[i] = 1;
      pin
        ..row = destRow
        ..col = destColumn + offset;
    }
  }
}
