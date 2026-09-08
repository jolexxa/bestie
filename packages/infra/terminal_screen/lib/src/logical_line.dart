import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/reflow.dart';

/// Bytes one content cell occupies across the four packed arrays.
const int bytesPerCell = 14;

/// Fixed per-line accounting overhead in bytes.
const int lineOverheadBytes = 96;

/// One unwrapped line of scrollback: trimmed content cells with no
/// padding, immutable once closed.
class LogicalLine implements ReflowSource {
  /// Creates an empty open line with [seq] as its stable position id.
  LogicalLine({required this.seq});

  /// Monotonic sequence number; index = seq - the store's front seq.
  final int seq;

  Uint32List _chars = Uint32List(0);
  Uint32List _fg = Uint32List(0);
  Uint32List _bg = Uint32List(0);
  Uint16List _style = Uint16List(0);
  int _length = 0;

  /// Decoded grapheme chars this line contributes to selectable text.
  int charLength = 0;

  /// Whether the line is still receiving rows as they scroll off.
  bool open = true;

  /// Whether any cell is double-width, forcing exact break walking.
  bool hasWide = false;

  /// Content cells held.
  int get length => _length;

  /// Bytes this line accounts for against the store's budget.
  int get byteSize => _length * bytesPerCell + lineOverheadBytes;

  /// The grapheme code at [index].
  int charCodeAt(int index) => _chars[index];

  /// The packed foreground at [index].
  int fgAt(int index) => _fg[index];

  /// The packed background at [index].
  int bgAt(int index) => _bg[index];

  /// The packed style at [index].
  int styleAt(int index) => _style[index];

  void _ensureCapacity(int needed) {
    if (needed <= _chars.length) return;
    var capacity = _chars.isEmpty ? 64 : _chars.length * 2;
    while (capacity < needed) {
      capacity *= 2;
    }
    _chars = Uint32List(capacity)..setRange(0, _length, _chars);
    _fg = Uint32List(capacity)..setRange(0, _length, _fg);
    _bg = Uint32List(capacity)..setRange(0, _length, _bg);
    _style = Uint16List(capacity)..setRange(0, _length, _style);
  }

  /// Appends [count] cells read from the packed arrays at [base].
  void append({
    required Uint32List chars,
    required Uint32List fg,
    required Uint32List bg,
    required Uint16List style,
    required int base,
    required int count,
  }) {
    _ensureCapacity(_length + count);
    final end = _length + count;
    _chars.setRange(_length, end, chars, base);
    _fg.setRange(_length, end, fg, base);
    _bg.setRange(_length, end, bg, base);
    _style.setRange(_length, end, style, base);
    if (!hasWide) {
      for (var i = _length; i < end; i++) {
        if (styleWidth(_style[i]) == CellWidth.wide) {
          hasWide = true;
          break;
        }
      }
    }
    _length = end;
    _sliceStarts = null;
  }

  /// The length this line would have with its trailing blanks dropped.
  int get trimmedLength {
    var end = _length;
    while (end > 0 && isBlankAt(0, end - 1)) {
      end--;
    }
    return end;
  }

  /// Drops every cell from [cells] on.
  void truncateTo(int cells) {
    _length = cells;
    _sliceStarts = null;
  }

  /// Closes the line and trims capacity to its content.
  void close() {
    open = false;
    if (_chars.length == _length) return;
    _chars = _chars.sublist(0, _length);
    _fg = _fg.sublist(0, _length);
    _bg = _bg.sublist(0, _length);
    _style = _style.sublist(0, _length);
  }

  @override
  int get rowCount => 1;

  @override
  int get cols => _length;

  @override
  bool wrappedAt(int row) => false;

  @override
  bool isBlankAt(int row, int col) =>
      _chars[col] == blankCharCode &&
      _bg[col] == packedDefaultBg &&
      styleAttrs(_style[col]) == CellAttrs.none;

  @override
  CellWidth widthAt(int row, int col) => styleWidth(_style[col]);

  @override
  int pinnedLengthAt(int row) => 0;

  /// Display rows this line occupies at [cols] wide.
  int rowsAt(int cols) {
    if (_length == 0) return 1;
    if (!hasWide) return (_length + cols - 1) ~/ cols;
    return plannedRowCount(this, firstRow: 0, newCols: cols);
  }

  int _sliceCols = 0;
  Uint32List? _sliceStarts;

  /// Cell offsets where each display row begins at [cols] wide,
  /// breaking exactly where a stored re-wrap would.
  Uint32List rowStartsAt(int cols) {
    final cached = _sliceStarts;
    if (cached != null && _sliceCols == cols) return cached;
    final rows = rowsAt(cols);
    final starts = Uint32List(rows);
    if (hasWide) {
      final cursor = LogicalCursor(this)..reset(0);
      var placed = 0;
      for (var r = 0; placed < cursor.total; r++) {
        starts[r] = placed;
        final take = breakLength(
          cursor,
          remaining: cursor.total - placed,
          newCols: cols,
        );
        cursor.advance(take);
        placed += take;
      }
    } else {
      for (var r = 0; r < rows; r++) {
        starts[r] = r * cols;
      }
    }
    _sliceCols = cols;
    _sliceStarts = starts;
    return starts;
  }

  /// Content cells display row [row] holds at [cols] wide.
  int rowLengthAt(int cols, int row) {
    final starts = rowStartsAt(cols);
    final end = row + 1 < starts.length ? starts[row + 1] : _length;
    return end - starts[row];
  }
}
