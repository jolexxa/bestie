import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';

/// A position pinned to scrollback content.
class LinePin {
  /// Pins [offset] cells into [line].
  LinePin({required this.line, required this.offset});

  /// The pinned line, or null for the front of whatever history remains.
  LogicalLine? line;

  /// Cell offset within [line].
  int offset;
}

/// Where a row that scrolled off ended up: [count] cells of [line] from
/// [start]. Fewer than the row held, when its trailing blanks were trimmed.
class RowLanding {
  /// The row's cells sit at [start] of [line], [count] of them.
  const RowLanding({
    required this.line,
    required this.start,
    required this.count,
  });

  /// The line the row was appended to.
  final LogicalLine line;

  /// Cell offset within [line] where the row begins.
  final int start;

  /// Cells of the row that were kept.
  final int count;
}

/// Where a display row lands inside scrollback.
class LineSlice {
  /// Display row [rowWithinLine] of [line], held at [lineIndex].
  const LineSlice({
    required this.line,
    required this.lineIndex,
    required this.rowWithinLine,
  });

  /// The line holding the row.
  final LogicalLine line;

  /// The line's index among held lines (0 = oldest).
  final int lineIndex;

  /// The display row within [line].
  final int rowWithinLine;
}

/// Byte-capped scrollback: a deque of [LogicalLine]s with derived
/// row/char indexes and content pins that survive eviction.
class LineStore {
  /// Creates an empty store capped at [maxBytes], measuring selectable chars
  /// through [graphemes] — the table a cell's packed code decodes against.
  LineStore({
    required this.maxBytes,
    required GraphemeTable graphemes,
    required int cols,
    this.onEvicted,
  }) : _graphemes = graphemes,
       _cols = cols;

  /// Budget in bytes; content beyond it evicts oldest lines.
  final int maxBytes;

  /// Called with each line as it leaves the store for good, while it can
  /// still be read.
  final void Function(LogicalLine line)? onEvicted;

  final GraphemeTable _graphemes;

  /// Chars a cell contributes to the selectable text.
  int _charLen(int charCode) => _graphemes.decode(charCode).length;

  final List<LogicalLine?> _lines = [];
  final List<int> _cumRows = [];
  final List<int> _cumChars = [];
  int _head = 0;
  int _rowsEpoch = 0;
  int _charsEpoch = 0;
  int _nextSeq = 0;
  int _totalBytes = 0;
  int _cols;

  final Set<LinePin> _pins = {};

  /// Lines currently held.
  int get lineCount => _lines.length - _head;

  /// Whether the store holds no lines.
  bool get isEmpty => lineCount == 0;

  /// Bytes of content currently held.
  int get totalBytes => _totalBytes;

  /// The width the row index currently answers for.
  int get cols => _cols;

  /// The newest line, or null when empty.
  LogicalLine? get last => isEmpty ? null : _lines[_lines.length - 1];

  /// The oldest line, or null when empty.
  LogicalLine? get first => isEmpty ? null : _lines[_head];

  /// Whether the newest line is still receiving rows.
  bool get lastIsOpen => last?.open ?? false;

  /// Display rows the whole store occupies at the current width.
  int get totalRows => isEmpty ? 0 : _cumRows[_lines.length - 1] - _rowsEpoch;

  /// Chars (content plus separators) the store contributes to the
  /// selectable text.
  int get totalChars =>
      isEmpty ? 0 : _cumChars[_lines.length - 1] - _charsEpoch;

  /// Chars evicted off the front of the selectable text so far.
  int get evictedChars => _charsEpoch;

  /// Chars the history contributes to the selectable text.
  ///
  /// While the viewport carries the open tail line onward its last row is
  /// padding inside a wrapped line, so it counts and carries no separator.
  /// Once nothing carries it, that padding is trailing blanks.
  int charsUpTo({required bool tailContinues}) {
    final tail = last;
    if (tail == null) return 0;
    if (!tail.open) return totalChars;
    if (tailContinues) return totalChars + _marginGap(tail);
    return totalChars - _trailingBlankChars(tail) + 1;
  }

  /// Chars [line]'s trailing blanks contribute that a line ending here does
  /// not. Only its last row is trimmed: the rows above it wrap onward, so
  /// their padding to the margin sits inside the line and is content.
  int _trailingBlankChars(LogicalLine line) {
    final starts = line.rowStartsAt(_cols);
    final lastRow = starts[starts.length - 1];
    final trimmed = line.trimmedLength;
    return _charsIn(line, trimmed > lastRow ? trimmed : lastRow, line.length);
  }

  /// Columns [line]'s last row is short of the margin. A row carried onward
  /// reaches the margin whether or not the child wrote that far.
  int _marginGap(LogicalLine line) {
    final starts = line.rowStartsAt(_cols);
    final held = line.length - starts[starts.length - 1];
    return held < _cols ? _cols - held : 0;
  }

  /// Chars the history contributes when the viewport shows nothing: the text
  /// ends at the last line holding content, dropping the empty lines after it
  /// and the separator that would have followed it. A viewport that still
  /// carries the tail line onward ends the text on that row instead.
  int charsToLastContent({required bool tailContinues}) {
    if (tailContinues) return charsUpTo(tailContinues: true);
    var empty = 0;
    while (empty < lineCount && _contentCharsAt(lineCount - 1 - empty) == 0) {
      empty++;
    }
    if (empty == lineCount) return 0;
    return charsUpTo(tailContinues: false) - empty - 1;
  }

  int _contentCharsAt(int index) {
    final line = lineAt(index);
    if (!line.open) return line.charLength;
    return line.charLength - _trailingBlankChars(line);
  }

  /// The line at [index] (0 = oldest).
  LogicalLine lineAt(int index) => _lines[_head + index]!;

  /// The index of [line], or null if it was evicted.
  int? indexOf(LogicalLine line) {
    final index = line.seq - _lines[_head]!.seq;
    if (index < 0 || index >= lineCount) return null;
    return index;
  }

  int _charContribution(LogicalLine line) =>
      line.charLength + (line.open ? 0 : 1);

  /// Chars cells [from] up to [to] of [line] contribute to selectable text.
  int _charsIn(LogicalLine line, int from, int to) {
    var chars = 0;
    for (var i = from; i < to; i++) {
      if (styleWidth(line.styleAt(i)) == CellWidth.continuation) continue;
      final length = _charLen(line.charCodeAt(i));
      chars += length == 0 ? 1 : length;
    }
    return chars;
  }

  /// Closes [line], dropping the padding a row kept because it wrapped
  /// onward. Nothing is coming to make those blanks content now.
  void _close(LogicalLine line) {
    final end = line.trimmedLength;
    if (end < line.length) {
      _totalBytes -= (line.length - end) * bytesPerCell;
      line
        ..charLength -= _charsIn(line, end, line.length)
        ..truncateTo(end);
    }
    line.close();
  }

  void _refreshTail() {
    final tail = _lines.length - 1;
    final line = _lines[tail]!;
    final beforeRows = tail == _head ? _rowsEpoch : _cumRows[tail - 1];
    final beforeChars = tail == _head ? _charsEpoch : _cumChars[tail - 1];
    _cumRows[tail] = beforeRows + line.rowsAt(_cols);
    _cumChars[tail] = beforeChars + _charContribution(line);
  }

  static bool _isBlankCell(int char, int bg, int style) =>
      char == blankCharCode &&
      bg == packedDefaultBg &&
      styleAttrs(style) == CellAttrs.none;

  /// Appends one viewport row scrolling off into history, answering with
  /// where its cells landed so a caller can follow a position on that row.
  RowLanding appendRow({
    required Uint32List chars,
    required Uint32List fg,
    required Uint32List bg,
    required Uint16List style,
    required int base,
    required int cols,
    required bool continuesAbove,
    required bool continuesOnward,
  }) {
    var count = cols;
    if (continuesOnward) {
      if (count > 0 &&
          styleWidth(style[base + count - 1]) == CellWidth.spacerHead) {
        count--;
      }
    } else {
      while (count > 0 &&
          _isBlankCell(
            chars[base + count - 1],
            bg[base + count - 1],
            style[base + count - 1],
          )) {
        count--;
      }
    }

    final LogicalLine line;
    if (continuesAbove && lastIsOpen) {
      line = last!;
    } else {
      final ending = last;
      if (ending != null) _close(ending);
      if (!isEmpty) _refreshTail();
      line = LogicalLine(seq: _nextSeq++);
      _lines.add(line);
      final onlyLine = _lines.length == _head + 1;
      _cumRows.add(onlyLine ? _rowsEpoch : _cumRows[_lines.length - 2]);
      _cumChars.add(onlyLine ? _charsEpoch : _cumChars[_lines.length - 2]);
      _totalBytes += lineOverheadBytes;
    }

    _totalBytes -= line.length * bytesPerCell;
    line.append(
      chars: chars,
      fg: fg,
      bg: bg,
      style: style,
      base: base,
      count: count,
    );
    _totalBytes += line.length * bytesPerCell;

    final start = line.length - count;
    line.charLength += _charsIn(line, start, line.length);

    if (!continuesOnward) _close(line);
    _refreshTail();
    _evictWhileOver();

    // Closing the line can trim the row's tail, never its start.
    final kept = line.length - start;
    return RowLanding(line: line, start: start, count: kept < 0 ? 0 : kept);
  }

  void _evictWhileOver() {
    while (_totalBytes > maxBytes && lineCount > 1) {
      _evictFirst();
    }
  }

  void _evictFirst() {
    final line = _lines[_head]!;
    onEvicted?.call(line);
    _rowsEpoch += line.rowsAt(_cols);
    _charsEpoch += _charContribution(line);
    _totalBytes -= line.byteSize;
    _lines[_head] = null;
    _head++;
    for (final pin in _pins) {
      if (identical(pin.line, line)) {
        pin
          ..line = null
          ..offset = 0;
      }
    }
    if (_head * 2 > _lines.length) _compact();
  }

  void _compact() {
    _lines.removeRange(0, _head);
    _cumRows.removeRange(0, _head);
    _cumChars.removeRange(0, _head);
    _head = 0;
  }

  /// Removes and returns the newest line so a growing viewport can
  /// reclaim it, or null when the store is empty.
  LogicalLine? removeLast() {
    if (isEmpty) return null;
    final tail = _lines.length - 1;
    final line = _lines[tail]!;
    _lines.removeLast();
    _cumRows.removeLast();
    _cumChars.removeLast();
    _totalBytes -= line.byteSize;
    // Held seqs must stay contiguous; the tail is always the max seq,
    // so its number is free to hand out again.
    _nextSeq = line.seq;
    for (final pin in _pins) {
      if (identical(pin.line, line)) {
        pin
          ..line = isEmpty ? null : last
          ..offset = isEmpty ? 0 : last!.length;
      }
    }
    return line;
  }

  /// Declares the width the row index answers for, rebuilding it.
  void setCols(int cols) {
    if (cols == _cols) return;
    _cols = cols;
    var rows = _rowsEpoch;
    for (var i = _head; i < _lines.length; i++) {
      rows += _lines[i]!.rowsAt(cols);
      _cumRows[i] = rows;
    }
  }

  int _lowerBound(List<int> cum, int target) {
    var low = _head;
    var high = _lines.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (cum[mid] <= target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// The line and row-within-line displayed at absolute [row]
  /// (0 = oldest held display row).
  LineSlice sliceAtRow(int row) {
    final index = _lowerBound(_cumRows, row + _rowsEpoch);
    final line = _lines[index]!;
    final before = index == _head ? _rowsEpoch : _cumRows[index - 1];
    return LineSlice(
      line: line,
      lineIndex: index - _head,
      rowWithinLine: row + _rowsEpoch - before,
    );
  }

  /// Whether display row [row] continues the row above it, without
  /// materializing a slice.
  bool rowContinuesAbove(int row) {
    final index = _lowerBound(_cumRows, row + _rowsEpoch);
    final before = index == _head ? _rowsEpoch : _cumRows[index - 1];
    return row + _rowsEpoch - before > 0;
  }

  /// The absolute display row where [line] begins, or null if evicted.
  int? firstRowOf(LogicalLine line) {
    final index = indexOf(line);
    if (index == null) return null;
    final absolute = _head + index;
    final before = absolute == _head ? _rowsEpoch : _cumRows[absolute - 1];
    return before - _rowsEpoch;
  }

  /// The char offset in the joined selectable text where [pin] sits.
  int charOffsetOf(LinePin pin) {
    final line = pin.line;
    if (line == null) return 0;
    final index = indexOf(line);
    if (index == null) return 0;
    final absolute = _head + index;
    final before = absolute == _head ? _charsEpoch : _cumChars[absolute - 1];
    var within = 0;
    final limit = pin.offset < line.length ? pin.offset : line.length;
    for (var i = 0; i < limit; i++) {
      if (styleWidth(line.styleAt(i)) == CellWidth.continuation) continue;
      final len = _charLen(line.charCodeAt(i));
      within += len == 0 ? 1 : len;
    }
    return before - _charsEpoch + within;
  }

  /// A pin at char offset [offset] of the joined selectable text,
  /// clamped into the store; null when [offset] lands past the store
  /// (i.e. in the viewport's portion of the text).
  LinePin? pinAtCharOffset(int offset) {
    if (isEmpty || offset >= totalChars) return null;
    final index = _lowerBound(_cumChars, offset + _charsEpoch);
    final line = _lines[index]!;
    final before = index == _head ? _charsEpoch : _cumChars[index - 1];
    var remaining = offset + _charsEpoch - before;
    var cell = 0;
    while (cell < line.length && remaining > 0) {
      if (styleWidth(line.styleAt(cell)) != CellWidth.continuation) {
        final len = _charLen(line.charCodeAt(cell));
        remaining -= len == 0 ? 1 : len;
      }
      cell++;
    }
    return track(LinePin(line: line, offset: cell));
  }

  /// Registers [pin] for relocation across eviction; returns it.
  LinePin track(LinePin pin) {
    _pins.add(pin);
    return pin;
  }

  /// Forgets [pin].
  void untrack(LinePin pin) {
    _pins.remove(pin);
  }

  /// Drops every line and pin, handing over each line on the way out — what
  /// is taken off the screen was still printed, and a recorder is owed it.
  void clear() {
    while (lineCount > 0) {
      _evictFirst();
    }
    _lines.clear();
    _cumRows.clear();
    _cumChars.clear();
    _head = 0;
    _rowsEpoch = 0;
    _charsEpoch = 0;
    _totalBytes = 0;
    for (final pin in _pins) {
      pin
        ..line = null
        ..offset = 0;
    }
  }
}
