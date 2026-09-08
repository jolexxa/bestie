import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/line_bytes.dart';
import 'package:terminal_screen/src/line_store.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/pen_lines.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:terminal_screen/src/resize_behavior.dart';
import 'package:terminal_screen/src/selection_anchor.dart';
import 'package:terminal_screen/src/selection_text.dart';

/// Reads a resize's source rows — pulled scrollback lines sliced at the
/// old width, then the viewport — as one sequence, oldest first.
class _ResizeSource implements ReflowSource {
  _ResizeSource({
    required this.buffer,
    required this.pulled,
    required this.oldCols,
    required List<ReflowPin> pins,
  }) : _pinRows = Uint32List(pins.length),
       _pinCols = Uint32List(pins.length) {
    var rows = 0;
    for (final line in pulled) {
      rows += line.rowsAt(oldCols);
    }
    pulledRows = rows;
    for (var i = 0; i < pins.length; i++) {
      _pinRows[i] = pins[i].row;
      _pinCols[i] = pins[i].col;
    }
  }

  final Buffer buffer;
  final List<LogicalLine> pulled;
  final int oldCols;
  late final int pulledRows;
  final Uint32List _pinRows;
  final Uint32List _pinCols;

  @override
  int get rowCount => pulledRows + buffer.rows;

  @override
  int get cols => oldCols;

  int _sliceRow = -1;
  late LogicalLine _sliceLine;
  int _sliceStart = 0;
  int _sliceLength = 0;
  bool _sliceLastOfLine = true;

  /// Points the slice fields at the pulled row [row] names.
  ///
  /// [row] always lands on a pulled line: [pulledRows] is the sum of the same
  /// `rowsAt(oldCols)` walked here, and every caller checks [_isPulled] first.
  /// Walking by index rather than searching for a match keeps that an
  /// invariant of the loop instead of something to check for and report on.
  void _resolve(int row) {
    if (_sliceRow == row) return;
    var r = row;
    var index = 0;
    var rows = pulled[index].rowsAt(oldCols);
    while (r >= rows) {
      r -= rows;
      rows = pulled[++index].rowsAt(oldCols);
    }
    final line = pulled[index];
    _sliceRow = row;
    _sliceLine = line;
    _sliceStart = line.rowStartsAt(oldCols)[r];
    _sliceLength = line.rowLengthAt(oldCols, r);
    _sliceLastOfLine = r == rows - 1;
  }

  bool _isPulled(int row) => row < pulledRows;

  int _viewportBase(int row) => buffer.rowBase(row - pulledRows);

  /// The grapheme code at [row], [col].
  int charCodeAt(int row, int col) {
    if (!_isPulled(row)) return buffer.charCodeAt(_viewportBase(row), col);
    _resolve(row);
    return col < _sliceLength
        ? _sliceLine.charCodeAt(_sliceStart + col)
        : blankCharCode;
  }

  /// The packed foreground at [row], [col].
  int fgAt(int row, int col) {
    if (!_isPulled(row)) return buffer.fgAt(_viewportBase(row), col);
    _resolve(row);
    return col < _sliceLength
        ? _sliceLine.fgAt(_sliceStart + col)
        : packedDefaultFg;
  }

  /// The packed background at [row], [col].
  int bgAt(int row, int col) {
    if (!_isPulled(row)) return buffer.bgAt(_viewportBase(row), col);
    _resolve(row);
    return col < _sliceLength
        ? _sliceLine.bgAt(_sliceStart + col)
        : packedDefaultBg;
  }

  /// The packed style at [row], [col].
  int styleAt(int row, int col) {
    if (!_isPulled(row)) return buffer.styleAt(_viewportBase(row), col);
    _resolve(row);
    if (col < _sliceLength) return _sliceLine.styleAt(_sliceStart + col);
    if (col == _sliceLength && col == oldCols - 1 && !_sliceLastOfLine) {
      return packStyle(attrs: CellAttrs.none, width: CellWidth.spacerHead);
    }
    return blankStyle;
  }

  @override
  bool wrappedAt(int row) {
    if (!_isPulled(row)) return buffer.wrappedAt(row - pulledRows);
    var r = row;
    for (final line in pulled) {
      final rows = line.rowsAt(oldCols);
      if (r < rows) return r > 0;
      r -= rows;
    }
    return false;
  }

  @override
  bool isBlankAt(int row, int col) =>
      charCodeAt(row, col) == blankCharCode &&
      bgAt(row, col) == packedDefaultBg &&
      styleAttrs(styleAt(row, col)) == CellAttrs.none;

  @override
  CellWidth widthAt(int row, int col) => styleWidth(styleAt(row, col));

  @override
  int pinnedLengthAt(int row) {
    var length = 0;
    for (var i = 0; i < _pinRows.length; i++) {
      if (_pinRows[i] != row) continue;
      final needed = _pinCols[i] + 1;
      if (needed > length) length = needed;
    }
    return length;
  }
}

/// Collects re-wrapped rows as fresh packed arrays.
class _RowListSink implements RowSink, WrittenRows {
  _RowListSink({required this.cols, required this.source});

  @override
  final int cols;

  final _ResizeSource source;

  final List<Uint32List> chars = [];
  final List<Uint32List> fg = [];
  final List<Uint32List> bg = [];
  final List<Uint16List> style = [];
  final List<bool> wrapped = [];

  @override
  int get count => chars.length;

  @override
  bool continuesAbove(int row) => wrapped[row];

  @override
  int beginRow({required bool wrapped}) {
    chars.add(Uint32List(cols)..fillRange(0, cols, blankCharCode));
    fg.add(Uint32List(cols)..fillRange(0, cols, packedDefaultFg));
    bg.add(Uint32List(cols)..fillRange(0, cols, packedDefaultBg));
    style.add(Uint16List(cols)..fillRange(0, cols, blankStyle));
    this.wrapped.add(wrapped);
    return chars.length - 1;
  }

  @override
  void copyCells({
    required int row,
    required int col,
    required int destColumn,
    required int count,
  }) {
    final destChars = chars.last;
    final destFg = fg.last;
    final destBg = bg.last;
    final destStyle = style.last;
    for (var i = 0; i < count; i++) {
      destChars[destColumn + i] = source.charCodeAt(row, col + i);
      destFg[destColumn + i] = source.fgAt(row, col + i);
      destBg[destColumn + i] = source.bgAt(row, col + i);
      destStyle[destColumn + i] = source.styleAt(row, col + i);
    }
  }

  @override
  void blankCells(int destColumn, int count) {}

  @override
  void markSpacerHead(int destColumn) {
    style.last[destColumn] = packStyle(
      attrs: CellAttrs.none,
      width: CellWidth.spacerHead,
    );
  }
}

/// Reads scrollback slices and the viewport as one trimmed sequence for
/// the selection walk.
class _JoinedSelectionSource implements ReflowSource {
  _JoinedSelectionSource(this.buffer) : sbRows = buffer.scrollbackLength;

  final Buffer buffer;
  final int sbRows;

  @override
  int get rowCount => sbRows + buffer.rows;

  @override
  int get cols => buffer.cols;

  int _base(int row) => row < sbRows
      ? Buffer.scrollbackHandle(row)
      : buffer.rowBase(row - sbRows);

  /// The grapheme code at [row], [col].
  int charCodeAt(int row, int col) => buffer.charCodeAt(_base(row), col);

  /// The packed foreground at [row], [col].
  int fgAt(int row, int col) => buffer.fgAt(_base(row), col);

  /// The packed background at [row], [col].
  int bgAt(int row, int col) => buffer.bgAt(_base(row), col);

  /// The attribute bitfield at [row], [col].
  int attrsAt(int row, int col) => styleAttrs(buffer.styleAt(_base(row), col));

  @override
  bool wrappedAt(int row) {
    if (row < sbRows) return buffer.scrollbackWrappedAt(row);
    if (row == sbRows) {
      return buffer.wrappedAt(0) && (buffer._store?.lastIsOpen ?? false);
    }
    return buffer.wrappedAt(row - sbRows);
  }

  @override
  bool isBlankAt(int row, int col) {
    final base = _base(row);
    return buffer.charCodeAt(base, col) == blankCharCode &&
        buffer.bgAt(base, col) == packedDefaultBg &&
        styleAttrs(buffer.styleAt(base, col)) == CellAttrs.none;
  }

  @override
  CellWidth widthAt(int row, int col) =>
      styleWidth(buffer.styleAt(_base(row), col));

  @override
  int pinnedLengthAt(int row) => 0;
}

/// Where a [SelectionAnchor]'s content currently is: a live viewport cell
/// while it is on screen, a pinned scrollback cell once it has scrolled off,
/// and neither once it is gone for good.
class _Anchored {
  _Anchored.live(this.live);
  _Anchored.pinned(this.pinned);

  /// The viewport cell, while the content is still on screen. Carried
  /// through a re-wrap by the same machinery as every other tracked
  /// position.
  ReflowPin? live;

  /// The scrollback cell, once the content has scrolled into history.
  LinePin? pinned;

  /// Whether the content went somewhere nothing can follow.
  bool get stranded => live == null && pinned == null;

  void strand() {
    live = null;
    pinned = null;
  }
}

/// Reads the live viewport alone, for the half of the selectable text that
/// has to be walked because it is still changing.
class _ViewportSelectionSource implements ReflowSource {
  _ViewportSelectionSource(this.buffer);

  final Buffer buffer;

  @override
  int get rowCount => buffer.rows;

  @override
  int get cols => buffer.cols;

  /// The grapheme code at [row], [col].
  int charCodeAt(int row, int col) =>
      buffer.charCodeAt(buffer.rowBase(row), col);

  @override
  bool wrappedAt(int row) => buffer.wrappedAt(row);

  @override
  bool isBlankAt(int row, int col) {
    final base = buffer.rowBase(row);
    return buffer.charCodeAt(base, col) == blankCharCode &&
        buffer.bgAt(base, col) == packedDefaultBg &&
        styleAttrs(buffer.styleAt(base, col)) == CellAttrs.none;
  }

  @override
  CellWidth widthAt(int row, int col) =>
      styleWidth(buffer.styleAt(buffer.rowBase(row), col));

  @override
  int pinnedLengthAt(int row) => 0;
}

/// A fixed-size viewport of `rows × cols` cells over a byte-capped
/// scrollback of logical lines.
///
/// The viewport is the only mutable grid; rows scrolling off its top
/// are trimmed into the [LineStore], and scrollback display rows are
/// derived by slicing stored lines at the current width. Cell
/// accessors take a row handle: non-negative for a viewport flat base,
/// negative (see [scrollbackHandle]) for a scrollback display row.
class Buffer {
  /// Create a buffer with the given dimensions. When [scrollbackBytes]
  /// is `0` the buffer has no history — useful for the alt screen.
  /// [graphemes] is the table a cell's packed code decodes against, for
  /// selection accounting. [onEvicted] is told about each line the
  /// history drops, while it can still be read.
  Buffer({
    required int rows,
    required int cols,
    required int scrollbackBytes,
    GraphemeTable? graphemes,
    void Function(LogicalLine line)? onEvicted,
  }) : _graphemes = graphemes ??= GraphemeTable(),
       _rows = rows,
       _cols = cols,
       _chars = Uint32List(rows * cols),
       _fg = Uint32List(rows * cols),
       _bg = Uint32List(rows * cols),
       _style = Uint16List(rows * cols),
       _wrapped = Uint8List(rows),
       _ring = Uint32List(rows),
       _dirty = Uint8List(rows),
       _store = scrollbackBytes <= 0
           ? null
           : LineStore(
               maxBytes: scrollbackBytes,
               graphemes: graphemes,
               cols: cols,
               onEvicted: onEvicted,
             ) {
    _blankAll();
    _resetRing();
    _markAllDirty();
  }

  /// The table a cell's packed code decodes against, shared with the store so
  /// a code means the same thing on either side of the seam.
  final GraphemeTable _graphemes;

  int _rows;
  int _cols;

  Uint32List _chars;
  Uint32List _fg;
  Uint32List _bg;
  Uint16List _style;

  /// Soft-wrap marker per slot: 1 when the row exists because the
  /// previous one overflowed the right margin (DECAWM soft wrap).
  Uint8List _wrapped;

  /// Slot index backing each viewport row. Rotated via [_head] so that
  /// scrolling is O(1).
  Uint32List _ring;

  int _head = 0;

  final LineStore? _store;

  /// Per-row dirty bits. 1 means the row has changed since the
  /// last call to [clearDirty].
  Uint8List _dirty;

  /// Number of rows in the visible viewport.
  int get rows => _rows;

  /// Number of columns in every row.
  int get cols => _cols;

  /// Scrollback display rows at the current width.
  int get scrollbackLength => _store?.totalRows ?? 0;

  /// Bytes of history currently held.
  int get scrollbackBytes => _store?.totalBytes ?? 0;

  /// The scrollback store, or null when this buffer keeps no history.
  LineStore? get store => _store;

  /// Drops every line of history and leaves the viewport alone, which is what
  /// `ESC[3J` asks for.
  void clearScrollback() => _store?.clear();

  /// Iterable of currently-dirty row indices.
  Iterable<int> get dirtyRows sync* {
    for (var i = 0; i < _rows; i++) {
      if (_dirty[i] != 0) yield i;
    }
  }

  /// Clear the dirty-row bitmap. Called by renderers after
  /// repainting.
  void clearDirty() {
    _dirty.fillRange(0, _rows, 0);
  }

  /// Mark [row] dirty.
  void markDirty(int row) {
    if (row >= 0 && row < _rows) _dirty[row] = 1;
  }

  /// Mark every visible row dirty — used on scroll, alt-buffer
  /// swap, and resize.
  void markAllDirty() => _markAllDirty();

  void _markAllDirty() {
    for (var i = 0; i < _rows; i++) {
      _dirty[i] = 1;
    }
  }

  void _resetRing() {
    for (var i = 0; i < _ring.length; i++) {
      _ring[i] = i;
    }
    _head = 0;
  }

  void _blankAll() {
    _chars.fillRange(0, _chars.length, blankCharCode);
    _fg.fillRange(0, _fg.length, packedDefaultFg);
    _bg.fillRange(0, _bg.length, packedDefaultBg);
    _style.fillRange(0, _style.length, blankStyle);
    _wrapped.fillRange(0, _wrapped.length, 0);
  }

  int _slotOf(int row) => _ring[(_head + row) % _rows];

  /// Flat index where viewport [row]'s cells begin. Add a column to
  /// address a cell.
  int rowBase(int row) => _slotOf(row) * _cols;

  /// The handle addressing scrollback display row [line] (0 = oldest)
  /// through the cell accessors.
  static int scrollbackHandle(int line) => -(line + 1);

  int _sbCacheRow = -1;
  LogicalLine? _sbCacheLine;
  int _sbCacheStart = 0;
  int _sbCacheLength = 0;
  bool _sbCacheLastOfLine = true;

  void _sbResolve(int row) {
    if (_sbCacheRow == row) return;
    final slice = _store!.sliceAtRow(row);
    final starts = slice.line.rowStartsAt(_cols);
    _sbCacheRow = row;
    _sbCacheLine = slice.line;
    _sbCacheStart = starts[slice.rowWithinLine];
    _sbCacheLength = slice.line.rowLengthAt(_cols, slice.rowWithinLine);
    _sbCacheLastOfLine = slice.rowWithinLine == starts.length - 1;
  }

  void _sbInvalidate() {
    _sbCacheRow = -1;
    _sbCacheLine = null;
  }

  int _sbChar(int row, int col) {
    _sbResolve(row);
    return col < _sbCacheLength
        ? _sbCacheLine!.charCodeAt(_sbCacheStart + col)
        : blankCharCode;
  }

  int _sbFg(int row, int col) {
    _sbResolve(row);
    return col < _sbCacheLength
        ? _sbCacheLine!.fgAt(_sbCacheStart + col)
        : packedDefaultFg;
  }

  int _sbBg(int row, int col) {
    _sbResolve(row);
    return col < _sbCacheLength
        ? _sbCacheLine!.bgAt(_sbCacheStart + col)
        : packedDefaultBg;
  }

  int _sbStyle(int row, int col) {
    _sbResolve(row);
    if (col < _sbCacheLength) {
      return _sbCacheLine!.styleAt(_sbCacheStart + col);
    }
    if (col == _sbCacheLength && col == _cols - 1 && !_sbCacheLastOfLine) {
      return packStyle(attrs: CellAttrs.none, width: CellWidth.spacerHead);
    }
    return blankStyle;
  }

  /// The grapheme code at [base] + [col].
  int charCodeAt(int base, int col) =>
      base >= 0 ? _chars[base + col] : _sbChar(-base - 1, col);

  /// The packed foreground color at [base] + [col].
  int fgAt(int base, int col) =>
      base >= 0 ? _fg[base + col] : _sbFg(-base - 1, col);

  /// The packed background color at [base] + [col].
  int bgAt(int base, int col) =>
      base >= 0 ? _bg[base + col] : _sbBg(-base - 1, col);

  /// The packed attributes and width at [base] + [col].
  int styleAt(int base, int col) =>
      base >= 0 ? _style[base + col] : _sbStyle(-base - 1, col);

  /// Overwrite every field of the cell at [base] + [col].
  void setCell(
    int base,
    int col, {
    required int charCode,
    required int fg,
    required int bg,
    required int style,
  }) {
    final index = base + col;
    _chars[index] = charCode;
    _fg[index] = fg;
    _bg[index] = bg;
    _style[index] = style;
  }

  /// Overwrite only the grapheme code at [base] + [col].
  void setCharCodeAt(int base, int col, int charCode) {
    _chars[base + col] = charCode;
  }

  /// Overwrite only the packed style at [base] + [col].
  void setStyleAt(int base, int col, int style) {
    _style[base + col] = style;
  }

  /// Blank [count] cells from [base] + [from], filling with
  /// [background].
  void eraseCells(int base, int from, int count, int background) {
    final start = base + from;
    final end = start + count;
    _chars.fillRange(start, end, blankCharCode);
    _fg.fillRange(start, end, packedDefaultFg);
    _bg.fillRange(start, end, background);
    _style.fillRange(start, end, blankStyle);
  }

  /// Copy [count] cells within one row, from column [from] to column
  /// [to]. Ranges may overlap.
  void moveCells(
    int base, {
    required int from,
    required int to,
    required int count,
  }) {
    _carryAnchorsAlongRow(base, from: from, to: to, count: count);
    final source = base + from;
    final start = base + to;
    final end = start + count;
    _chars.setRange(start, end, _chars, source);
    _fg.setRange(start, end, _fg, source);
    _bg.setRange(start, end, _bg, source);
    _style.setRange(start, end, _style, source);
  }

  /// Moves anchors with the cells they name when a run of one row slides
  /// sideways.
  void _carryAnchorsAlongRow(
    int base, {
    required int from,
    required int to,
    required int count,
  }) {
    for (final held in _anchors.values) {
      final live = held.live;
      if (live == null || rowBase(live.row) != base) continue;
      if (live.col < from || live.col >= from + count) continue;
      live.col += to - from;
    }
  }

  /// `true` when viewport [row] continues a soft-wrapped line.
  bool wrappedAt(int row) => _wrapped[_slotOf(row)] != 0;

  /// `true` when scrollback display row [line] continues the one
  /// above it.
  bool scrollbackWrappedAt(int line) => _store!.rowContinuesAbove(line);

  /// Set the soft-wrap marker on viewport [row].
  void setWrappedAt(int row, {required bool wrapped}) {
    _wrapped[_slotOf(row)] = wrapped ? 1 : 0;
  }

  void _blankSlot(int slot, int background) {
    final start = slot * _cols;
    final end = start + _cols;
    _chars.fillRange(start, end, blankCharCode);
    _fg.fillRange(start, end, packedDefaultFg);
    _bg.fillRange(start, end, background);
    _style.fillRange(start, end, blankStyle);
    _wrapped[slot] = 0;
  }

  /// Blank every cell of viewport [row], filling with [background],
  /// and clear its soft-wrap marker.
  void eraseRow(int row, {int background = packedDefaultBg}) {
    _blankSlot(_slotOf(row), background);
  }

  RowLanding _appendViewportRowToStore(
    LineStore store,
    int row, {
    required bool continuesOnward,
  }) {
    final landed = store.appendRow(
      chars: _chars,
      fg: _fg,
      bg: _bg,
      style: _style,
      base: rowBase(row),
      cols: _cols,
      continuesAbove: wrappedAt(row),
      continuesOnward: continuesOnward,
    );
    _sbInvalidate();
    return landed;
  }

  /// Scroll the whole viewport up by one row. The top row is
  /// trimmed into scrollback (when history is kept); the bottom row
  /// is cleared. O(1) beyond the top row's copy into its line.
  void scrollUpOne({int background = packedDefaultBg}) {
    final store = _store;
    // A buffer that keeps no history has nowhere to put the row, so anything
    // anchored to it has nowhere to follow.
    _carryAnchorsOffTop(
      store == null
          ? null
          : _appendViewportRowToStore(
              store,
              0,
              continuesOnward: _rows > 1 && wrappedAt(1),
            ),
    );
    _head = (_head + 1) % _rows;
    eraseRow(_rows - 1, background: background);
    _markAllDirty();
  }

  /// Scroll only the rows in the half-open interval `[top,
  /// bottom]` (inclusive) up by one, matching DECSTBM semantics.
  /// Rows outside the region are untouched; the row at [top] is
  /// dropped (not retained in scrollback) and recycled into
  /// [bottom].
  void scrollRegionUp(
    int top,
    int bottom, {
    int background = packedDefaultBg,
  }) {
    _carryAnchorsInRegion(top, bottom, by: -1, dropped: top);
    final recycled = _slotOf(top);
    for (var r = top; r < bottom; r++) {
      _ring[(_head + r) % _rows] = _ring[(_head + r + 1) % _rows];
      markDirty(r);
    }
    _ring[(_head + bottom) % _rows] = recycled;
    _blankSlot(recycled, background);
    markDirty(bottom);
  }

  /// Scroll a top-anchored region `[0, bottom]` up by one, with
  /// the row at index `0` evicted into **scrollback** like a
  /// full-screen scroll. Rows below the region are preserved in
  /// place. Used for SU / IND on regions whose top is row 0,
  /// matching xterm's behavior — required so ratatui-style
  /// inline TUIs (codex) can push content above the inline
  /// viewport into history.
  void scrollTopRegionUpToScrollback(
    int bottom, {
    int background = packedDefaultBg,
  }) {
    if (bottom == _rows - 1) {
      scrollUpOne(background: background);
      return;
    }
    scrollUpOne(background: background);
    // Every row shifted up a slot, including those below the region.
    // Rotate that block back down so it keeps its contents.
    _carryAnchorsInRegion(bottom, _rows - 2, by: 1, dropped: null);
    final blanked = _slotOf(_rows - 1);
    for (var r = _rows - 1; r > bottom; r--) {
      _ring[(_head + r) % _rows] = _ring[(_head + r - 1) % _rows];
    }
    _ring[(_head + bottom) % _rows] = blanked;
  }

  /// Scroll only the rows in the half-open interval `[top,
  /// bottom]` (inclusive) down by one. The row at [bottom] is
  /// dropped and recycled into [top].
  void scrollRegionDown(
    int top,
    int bottom, {
    int background = packedDefaultBg,
  }) {
    _carryAnchorsInRegion(top, bottom, by: 1, dropped: bottom);
    final recycled = _slotOf(bottom);
    for (var r = bottom; r > top; r--) {
      _ring[(_head + r) % _rows] = _ring[(_head + r - 1) % _rows];
      markDirty(r);
    }
    _ring[(_head + top) % _rows] = recycled;
    _blankSlot(recycled, background);
    markDirty(top);
  }

  /// Resize the buffer to [newRows] × [newCols], re-wrapping
  /// soft-wrapped lines to the new width and carrying [pins] to
  /// wherever their cells end up.
  ///
  /// A pin's row comes back relative to the new viewport: negative
  /// values sit that many rows up in scrollback.
  ///
  void resizeReflowing({
    required int newRows,
    required int newCols,
    ReflowPin? cursor,
    List<ReflowPin> pins = const <ReflowPin>[],
    ResizeBehavior behavior = const ReflowingResize(),
  }) {
    // A live position rides the re-wrap the way the cursor does. A pinned one
    // names a line, and a new width does not move it within that line — only
    // a line the resize takes back out of history loses it, so those keep an
    // offset to fall back on.
    final riding = <_Anchored, ReflowPin>{};
    final wasPinnedTo = <_Anchored, LogicalLine>{};
    final fallback = <_Anchored, int>{};
    for (final entry in _anchors.entries) {
      final held = entry.value;
      final live = held.live;
      if (live != null) {
        riding[held] = live;
        continue;
      }
      final line = held.pinned?.line;
      final at = line == null ? null : offsetOf(entry.key);
      if (at == null) continue;
      wasPinnedTo[held] = line!;
      fallback[held] = at;
    }
    final carried = [...pins, ...riding.values];

    if (newCols == _cols || _store == null) {
      _resizeWithoutReflow(
        newRows: newRows,
        newCols: newCols,
        cursor: cursor,
        pins: carried,
        behavior: behavior,
      );
    } else {
      _resizeWithReflow(
        newRows: newRows,
        newCols: newCols,
        cursor: cursor,
        pins: carried,
        behavior: behavior,
      );
    }

    _settleAnchors(riding, wasPinnedTo, fallback);
  }

  /// Puts every anchor back on its content once the re-wrap has landed.
  void _settleAnchors(
    Map<_Anchored, ReflowPin> riding,
    Map<_Anchored, LogicalLine> wasPinnedTo,
    Map<_Anchored, int> fallback,
  ) {
    final store = _store;
    for (final MapEntry(key: held, value: pin) in riding.entries) {
      // A row that came back above the viewport now lives in history.
      if (pin.row >= 0 || store == null) {
        held.live = pin;
        continue;
      }
      final pinned = _viewPinIn(store, pin);
      if (pinned == null) {
        held.strand();
        continue;
      }
      held
        ..live = null
        ..pinned = pinned;
    }

    for (final MapEntry(key: held, value: line) in wasPinnedTo.entries) {
      final pinned = held.pinned;
      if (pinned != null && identical(pinned.line, line)) continue;
      // Its line was taken back out of history and drawn again, so the pin
      // no longer names it. The offset it sat at is all that is left.
      if (pinned != null) store?.untrack(pinned);
      final again = _anchorAt(fallback[held]!);
      if (again == null) {
        held.strand();
        continue;
      }
      held
        ..live = again.live
        ..pinned = again.pinned;
    }
  }

  void _clampPinsToViewport(List<ReflowPin> pins) {
    for (var i = 0; i < pins.length; i++) {
      final pin = pins[i];
      if (pin.row >= _rows) pin.row = _rows - 1;
      if (pin.col >= _cols) pin.col = _cols - 1;
    }
  }

  /// Chars the selectable text holds, without laying it out.
  ///
  /// History answers for itself: what has scrolled off can no longer change,
  /// so the store keeps a running count of it. Only the viewport is walked,
  /// which is bounded by the window rather than by how much has been kept.
  int selectionContentLength() {
    final source = _ViewportSelectionSource(this);
    final store = _store;
    if (store == null || store.isEmpty) return _measureRows(source);
    // Nothing live below the history: the text ends inside the store, past
    // which the empty rows and their separators do not count.
    if (lastContentRow(source) < 0) {
      return store.charsToLastContent(tailContinues: _seamLive);
    }
    return store.charsUpTo(tailContinues: _seamLive) + _measureRows(source);
  }

  int _measureRows(_ViewportSelectionSource source) =>
      _viewportMetrics(source).contentLength;

  SelectionMetrics _viewportMetrics(_ViewportSelectionSource source) =>
      measureSelection(
        source,
        (row, col) => _graphemes.decode(source.charCodeAt(row, col)).length,
      );

  // --- Anchors ---------------------------------------------------------------

  final Map<SelectionAnchor, _Anchored> _anchors = {};

  /// Chars history contributes to the selectable text, which is where the
  /// viewport's own offsets start from.
  int _historyChars() => _store?.charsUpTo(tailContinues: _seamLive) ?? 0;

  /// Pins whatever content sits at char [offset] of the selectable text, so
  /// the caller can ask later where it went. Null when the text is shorter
  /// than that.
  SelectionAnchor? anchorAt(int offset) {
    final held = _anchorAt(offset);
    if (held == null) return null;
    final anchor = SelectionAnchor();
    _anchors[anchor] = held;
    return anchor;
  }

  _Anchored? _anchorAt(int offset) {
    if (offset < 0) return null;
    final store = _store;
    if (store != null && offset < store.totalChars) {
      // The store tracks whatever it hands back, so it already survives
      // eviction from here on.
      final pin = store.pinAtCharOffset(offset);
      if (pin != null) return _Anchored.pinned(pin);
    }
    final within = offset - _historyChars();
    final at = _viewportCellAtOffset(within < 0 ? 0 : within);
    if (at == null) return null;
    return _Anchored.live(at);
  }

  /// Where the content [anchor] holds sits in the selectable text now, or
  /// null once that content is gone — or the anchor was never this buffer's.
  int? offsetOf(SelectionAnchor anchor) {
    final held = _anchors[anchor];
    if (held == null || held.stranded) return null;
    final pinned = held.pinned;
    if (pinned != null) {
      // Its line evicted: the content is gone, and what survives now begins
      // at the front of the text.
      if (pinned.line == null) return 0;
      return _store!.charOffsetOf(pinned);
    }
    final live = held.live!;
    return _historyChars() + _viewportOffsetAtCell(live.row, live.col);
  }

  /// Lets go of [anchor]. Untracked positions would otherwise pile up in the
  /// store for as long as the session lives.
  void release(SelectionAnchor anchor) {
    final held = _anchors.remove(anchor);
    final pinned = held?.pinned;
    if (pinned != null) _store?.untrack(pinned);
  }

  /// The viewport cell holding char [within] of the viewport's own
  /// contribution to the selectable text.
  ReflowPin? _viewportCellAtOffset(int within) {
    if (_rows == 0) return null;
    final source = _ViewportSelectionSource(this);
    final metrics = _viewportMetrics(source);
    if (within > metrics.contentLength) return null;

    var row = 0;
    while (row + 1 < _rows && metrics.rowStarts[row + 1] <= within) {
      row++;
    }
    var remaining = within - metrics.rowStarts[row];
    var col = 0;
    while (col < metrics.rowContentCols[row] && remaining > 0) {
      if (source.widthAt(row, col) != CellWidth.continuation) {
        final length = _graphemes.decode(source.charCodeAt(row, col)).length;
        remaining -= length == 0 ? 1 : length;
      }
      col++;
    }
    return ReflowPin(row: row, col: col);
  }

  /// Chars of the viewport's contribution that come before viewport cell
  /// [row], [col].
  int _viewportOffsetAtCell(int row, int col) {
    final source = _ViewportSelectionSource(this);
    final metrics = _viewportMetrics(source);
    final at = row.clamp(0, _rows - 1);
    var within = 0;
    final limit = col < metrics.rowContentCols[at]
        ? col
        : metrics.rowContentCols[at];
    for (var c = 0; c < limit; c++) {
      if (source.widthAt(at, c) == CellWidth.continuation) continue;
      final length = _graphemes.decode(source.charCodeAt(at, c)).length;
      within += length == 0 ? 1 : length;
    }
    return metrics.rowStarts[at] + within;
  }

  /// Moves anchors with the rows they name when a block of `[top, bottom]`
  /// shifts by [by]. Content on [dropped] is gone, so nothing can follow it.
  void _carryAnchorsInRegion(
    int top,
    int bottom, {
    required int by,
    required int? dropped,
  }) {
    for (final held in _anchors.values) {
      final live = held.live;
      if (live == null || live.row < top || live.row > bottom) continue;
      if (live.row == dropped) {
        held.strand();
        continue;
      }
      live.row += by;
    }
  }

  /// Carries anchors through the top row leaving the viewport: the ones on
  /// it follow their cells into history, and the rest move up a row with the
  /// content they name.
  void _carryAnchorsOffTop(RowLanding? landed) {
    if (_anchors.isEmpty) return;
    for (final held in _anchors.values) {
      final live = held.live;
      if (live == null) continue;
      if (live.row > 0) {
        live.row--;
        continue;
      }
      if (landed == null) {
        held.strand();
        continue;
      }
      final within = live.col < landed.count ? live.col : landed.count;
      held
        ..live = null
        ..pinned = _store!.track(
          LinePin(line: landed.line, offset: landed.start + within),
        );
    }
  }

  /// The offset index of the selectable text.
  SelectionMetrics selectionMetrics() {
    final source = _JoinedSelectionSource(this);
    return measureSelection(
      source,
      (row, col) => _graphemes.decode(source.charCodeAt(row, col)).length,
    );
  }

  /// The selectable text itself.
  SelectionText selectionText() {
    final source = _JoinedSelectionSource(this);
    return renderSelection(
      source,
      (row, col) => _graphemes.decode(source.charCodeAt(row, col)),
    );
  }

  /// The selectable text's logical lines, without the cost of joining them.
  List<String> selectionLines() {
    final source = _JoinedSelectionSource(this);
    return renderSelectionLines(
      source,
      (row, col) => _graphemes.decode(source.charCodeAt(row, col)),
    );
  }

  /// The same lines with the pen behind each of them, for recording.
  List<LineBytes> penLines() {
    final source = _JoinedSelectionSource(this);
    return renderPenLines(
      source,
      codeAt: source.charCodeAt,
      decode: _graphemes.decode,
      fgAt: source.fgAt,
      bgAt: source.bgAt,
      attrsAt: source.attrsAt,
    );
  }

  bool _isRowBlank(int row) {
    final base = rowBase(row);
    for (var col = 0; col < _cols; col++) {
      final index = base + col;
      if (_chars[index] != blankCharCode ||
          _bg[index] != packedDefaultBg ||
          styleAttrs(_style[index]) != CellAttrs.none) {
        return false;
      }
    }
    return true;
  }

  /// Rows at the bottom of the viewport holding nothing a reader would
  /// see, up to [limit] of them, stopping at [cursorRow].
  ///
  /// A shorter window eats these before it pushes anything into
  /// history, so dragging a window down over empty space costs nothing.
  int _trailingBlankRows(int limit, int? cursorRow) {
    final floor = cursorRow ?? -1;
    var count = 0;
    var row = _rows - 1;
    while (count < limit && row > floor && _isRowBlank(row)) {
      count++;
      row--;
    }
    return count;
  }

  /// Whether the open tail line and viewport row 0 form a live seam.
  bool get _seamLive =>
      _store != null && _store.lastIsOpen && _rows > 0 && wrappedAt(0);

  LinePin? _viewPinIn(LineStore store, ReflowPin pin) {
    final storeRow = store.totalRows + pin.row;
    if (storeRow < 0 || store.isEmpty) return null;
    final slice = store.sliceAtRow(storeRow);
    final start = slice.line.rowStartsAt(store.cols)[slice.rowWithinLine];
    return store.track(LinePin(line: slice.line, offset: start + pin.col));
  }

  void _viewPinOut(LineStore store, LinePin linePin, ReflowPin pin) {
    store.untrack(linePin);
    final line = linePin.line;
    final total = store.totalRows;
    if (line == null) {
      pin
        ..row = -total
        ..col = 0;
      return;
    }
    // A tracked pin naming a line is naming one the store still holds.
    final first = store.firstRowOf(line)!;
    final starts = line.rowStartsAt(store.cols);
    var within = starts.length - 1;
    while (within > 0 && starts[within] > linePin.offset) {
      within--;
    }
    pin
      ..row = first + within - total
      ..col = linePin.offset - starts[within];
  }

  void _resizeWithReflow({
    required int newRows,
    required int newCols,
    required ReflowPin? cursor,
    required List<ReflowPin> pins,
    required ResizeBehavior behavior,
  }) {
    final store = _store!;
    final oldRows = _rows;
    final oldCols = _cols;
    final narrowing = newCols < _cols;
    final cursorRow = cursor?.row;

    // A scrolled-back view arrives as a negative-row pin; it rides the
    // store as a content pin because history does not move.
    final viewPins = <(ReflowPin, LinePin)>[];
    final carried = <ReflowPin>[];
    for (final pin in [...pins, ?cursor]) {
      if (pin.row < 0) {
        final linePin = _viewPinIn(store, pin);
        if (linePin != null) viewPins.add((pin, linePin));
      } else {
        carried.add(pin);
      }
    }

    // The seam line re-wraps with the viewport
    final pulled = <LogicalLine>[];
    if (_seamLive) pulled.add(store.removeLast()!);
    final reveal =
        behavior.revealsHistoryOnGrow &&
        (cursorRow == null || cursorRow == oldRows - 1);
    var source = _ResizeSource(
      buffer: this,
      pulled: pulled,
      oldCols: oldCols,
      pins: const [],
    );
    if (reveal) {
      var planned = plannedTotalRowCount(source, newCols: newCols);
      while (planned < newRows && !store.isEmpty) {
        pulled.insert(0, store.removeLast()!);
        source = _ResizeSource(
          buffer: this,
          pulled: pulled,
          oldCols: oldCols,
          pins: const [],
        );
        planned = plannedTotalRowCount(source, newCols: newCols);
      }
    }

    final seam = ReflowPin(row: source.pulledRows, col: 0);
    final writerPins = [...carried, seam];
    for (final pin in writerPins) {
      if (identical(pin, seam)) continue;
      pin.row += source.pulledRows;
    }
    source = _ResizeSource(
      buffer: this,
      pulled: pulled,
      oldCols: oldCols,
      pins: writerPins,
    );

    final sink = _RowListSink(cols: newCols, source: source);
    ReflowWriter(source: source, sink: sink, pins: writerPins).run();

    final viewportStart = behavior.viewportStart(
      ReflowAnchor(
        rows: sink,
        seam: seam.row,
        oldest: 0,
        oldRows: oldRows,
        newRows: newRows,
        cursorRow: cursorRow,
        cursorLanded: cursor?.row,
        narrowing: narrowing,
      ),
    );

    store.setCols(newCols);

    _rows = newRows;
    _cols = newCols;
    _chars = Uint32List(newRows * newCols);
    _fg = Uint32List(newRows * newCols);
    _bg = Uint32List(newRows * newCols);
    _style = Uint16List(newRows * newCols);
    _wrapped = Uint8List(newRows);
    _ring = Uint32List(newRows);
    _dirty = Uint8List(newRows);
    _blankAll();
    _resetRing();
    _sbInvalidate();

    for (var r = 0; r < viewportStart; r++) {
      final continuesOnward = r + 1 < sink.count && sink.wrapped[r + 1];
      store.appendRow(
        chars: sink.chars[r],
        fg: sink.fg[r],
        bg: sink.bg[r],
        style: sink.style[r],
        base: 0,
        cols: newCols,
        continuesAbove: sink.wrapped[r],
        continuesOnward: continuesOnward,
      );
    }

    final below = sink.count - viewportStart;
    final viewportRows = below < newRows ? below : newRows;
    for (var r = 0; r < viewportRows; r++) {
      final sourceRow = viewportStart + r;
      final base = rowBase(r);
      _chars.setRange(base, base + newCols, sink.chars[sourceRow]);
      _fg.setRange(base, base + newCols, sink.fg[sourceRow]);
      _bg.setRange(base, base + newCols, sink.bg[sourceRow]);
      _style.setRange(base, base + newCols, sink.style[sourceRow]);
      _wrapped[_slotOf(r)] = sink.wrapped[sourceRow] ? 1 : 0;
    }

    for (final pin in writerPins) {
      if (identical(pin, seam)) continue;
      pin.row -= viewportStart;
    }
    _clampPinsToViewport(carried);
    for (final (pin, linePin) in viewPins) {
      _viewPinOut(store, linePin, pin);
    }
    _markAllDirty();
  }

  /// Resize the buffer to [newRows] × [newCols] without re-wrapping:
  /// every row keeps the breaks it has and is truncated or padded to
  /// the new width. Viewport and scrollback both survive.
  ///
  /// See [resizeReflowing] for what [cursor] decides.
  void resize({
    required int newRows,
    required int newCols,
    ReflowPin? cursor,
    List<ReflowPin> pins = const <ReflowPin>[],
    ResizeBehavior behavior = const ReflowingResize(),
  }) => _resizeWithoutReflow(
    newRows: newRows,
    newCols: newCols,
    cursor: cursor,
    pins: pins,
    behavior: behavior,
  );

  void _resizeWithoutReflow({
    required int newRows,
    required int newCols,
    required ReflowPin? cursor,
    required List<ReflowPin> pins,
    required ResizeBehavior behavior,
  }) {
    final store = _store;
    final oldRows = _rows;
    final oldCols = _cols;
    final oldChars = _chars;
    final oldFg = _fg;
    final oldBg = _bg;
    final oldStyle = _style;
    final oldBases = List<int>.generate(oldRows, rowBase);
    final oldWrapFlags = List<bool>.generate(oldRows, wrappedAt);

    final carried = <ReflowPin>[...pins, ?cursor];
    final viewPins = <(ReflowPin, LinePin)>[];
    if (store != null) {
      carried.removeWhere((pin) {
        if (pin.row >= 0) return false;
        final linePin = _viewPinIn(store, pin);
        if (linePin != null) viewPins.add((pin, linePin));
        return true;
      });
    }

    final shrink = oldRows - newRows;
    var pushed = 0;
    if (shrink > 0) {
      pushed = shrink - _trailingBlankRows(shrink, cursor?.row);
      if (store != null) {
        for (var r = 0; r < pushed; r++) {
          final continuesOnward = r + 1 < oldRows && oldWrapFlags[r + 1];
          store.appendRow(
            chars: oldChars,
            fg: oldFg,
            bg: oldBg,
            style: oldStyle,
            base: oldBases[r],
            cols: oldCols,
            continuesAbove: oldWrapFlags[r],
            continuesOnward: continuesOnward,
          );
        }
      }
    }

    // A growing viewport pulls whole closed lines back down from
    // history when the behavior reveals them and they fit.
    final revealed = <LogicalLine>[];
    var revealedRows = 0;
    if (store != null &&
        shrink < 0 &&
        behavior.revealsHistoryOnGrow &&
        cursor?.row == oldRows - 1) {
      var gain = -shrink;
      while (!store.isEmpty && !(store.lastIsOpen && wrappedAt(0))) {
        final candidate = store.last!;
        final candidateRows = candidate.rowsAt(oldCols);
        if (candidateRows > gain) break;
        revealed.insert(0, store.removeLast()!);
        revealedRows += candidateRows;
        gain -= candidateRows;
      }
    }

    _rows = newRows;
    _cols = newCols;
    _chars = Uint32List(newRows * newCols);
    _fg = Uint32List(newRows * newCols);
    _bg = Uint32List(newRows * newCols);
    _style = Uint16List(newRows * newCols);
    _wrapped = Uint8List(newRows);
    _ring = Uint32List(newRows);
    _dirty = Uint8List(newRows);
    _blankAll();
    _resetRing();
    _sbInvalidate();
    store?.setCols(newCols);

    final copyCols = oldCols < newCols ? oldCols : newCols;
    var destRow = 0;
    for (final line in revealed) {
      final starts = line.rowStartsAt(oldCols);
      for (var r = 0; r < starts.length && destRow < newRows; r++) {
        final start = starts[r];
        final length = line.rowLengthAt(oldCols, r);
        final take = length < copyCols ? length : copyCols;
        final base = rowBase(destRow);
        for (var c = 0; c < take; c++) {
          _chars[base + c] = line.charCodeAt(start + c);
          _fg[base + c] = line.fgAt(start + c);
          _bg[base + c] = line.bgAt(start + c);
          _style[base + c] = line.styleAt(start + c);
        }
        _wrapped[_slotOf(destRow)] = r > 0 ? 1 : 0;
        destRow++;
      }
    }
    for (var r = pushed; r < oldRows && destRow < newRows; r++) {
      final from = oldBases[r];
      final base = rowBase(destRow);
      _chars.setRange(base, base + copyCols, oldChars, from);
      _fg.setRange(base, base + copyCols, oldFg, from);
      _bg.setRange(base, base + copyCols, oldBg, from);
      _style.setRange(base, base + copyCols, oldStyle, from);
      _wrapped[_slotOf(destRow)] = oldWrapFlags[r] ? 1 : 0;
      destRow++;
    }

    for (final pin in carried) {
      pin.row += revealedRows - pushed;
    }
    _clampPinsToViewport(carried);
    if (store != null) {
      for (final (pin, linePin) in viewPins) {
        _viewPinOut(store, linePin, pin);
      }
    }
    _markAllDirty();
  }

  /// Reset every cell to blank, clear scrollback, and reset
  /// wrap markers.
  void fullReset() {
    _blankAll();
    _resetRing();
    _store?.clear();
    _sbInvalidate();
    _markAllDirty();
  }
}
