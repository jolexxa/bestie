import 'dart:math' as math;

import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart' as ui show Cell, Color, Colors;
import 'package:nocterm/nocterm.dart' hide Cell, Color;
// TerminalCanvas is not exported via the public nocterm.dart surface
// but is needed for direct cell paint.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';
// TextLayoutResult is consumed by the Selectable mixin contract but
// not re-exported. The shape is small (just lines + dims) so the
// implementation import is contained to constructing the result.
// ignore: implementation_imports
import 'package:nocterm/src/text/text_layout_engine.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;

/// Paints a [ts.Screen] directly into nocterm's canvas via
/// [TerminalCanvas.setRaw], bypassing text layout for every cell.
@model
class TerminalGrid extends SingleChildRenderObjectComponent {
  const TerminalGrid({
    required this.screen,
    this.showCursor = true,
    this.onScrolled,
    super.key,
  });

  final ts.Screen screen;
  final bool showCursor;

  /// Called when the grid moves the displayed viewport itself, which a
  /// selection dragged past an edge does.
  final void Function()? onScrolled;

  @override
  RenderTerminalGrid createRenderObject(BuildContext context) =>
      RenderTerminalGrid(
        screen: screen,
        showCursor: showCursor,
        onScrolled: onScrolled,
      )..registrar = SelectionRegistrarScope.maybeOf(context);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderTerminalGrid renderObject,
  ) {
    renderObject
      ..screen = screen
      ..showCursor = showCursor
      ..onScrolled = onScrolled
      ..registrar = SelectionRegistrarScope.maybeOf(context);
  }
}

@model
class RenderTerminalGrid extends RenderObject
    with
        Selectable,
        SelectionRegistrant,
        TextSelectable,
        SelfScrollingSelectable,
        ScrollableRenderObjectMixin {
  RenderTerminalGrid({
    required ts.Screen screen,
    bool showCursor = true,
    this.onScrolled,
  }) : _screen = screen,
       _showCursor = showCursor;

  /// Notified when the grid moves the displayed viewport itself — a
  /// selection dragged past an edge, or a wheel tick over the grid.
  void Function()? onScrolled;

  ts.Screen _screen;
  ts.Screen get screen => _screen;
  set screen(ts.Screen value) {
    if (!identical(_screen, value)) {
      // Anchors belong to the screen that handed them out.
      _releaseAnchors();
      setSelectionRange(null, null);
    }
    _screen = value;
    markNeedsPaint();
    didLayoutSelectableText();
  }

  bool _showCursor;
  bool get showCursor => _showCursor;
  set showCursor(bool value) {
    if (_showCursor == value) return;
    _showCursor = value;
    markNeedsPaint();
  }

  /// How many rows one wheel tick scrolls.
  static const _wheelLines = 3;

  /// Wheel-over-the-grid scrolls scrollback, dispatched positionally by the
  /// binding.
  @override
  bool handleMouseWheel(MouseEvent event) {
    if (_screen.onAltScreen) return false;
    final delta = event.button == MouseButton.wheelUp
        ? _wheelLines
        : -_wheelLines;
    final before = _screen.viewOffset;
    if (_screen.setViewOffset(before + delta) == before) return false;
    markNeedsPaint();
    onScrolled?.call();
    return true;
  }

  @override
  void dispose() {
    _releaseAnchors();
    super.dispose();
  }

  @override
  void performLayout() {
    final newSize = Size(constraints.maxWidth, constraints.maxHeight);
    if (!hasSize || size != newSize) markNeedsPaint();
    size = newSize;
    didLayoutSelectableText();
  }

  // ── Selectable: text + layout cache ────────────────────────────

  int? _cachedMutation;
  int _cachedRows = 0;
  int _cachedCols = 0;
  int _cachedScrollbackLength = 0;
  int _cachedTotalRows = 0;

  ts.SelectionMetrics? _metrics;
  List<List<int>?> _cellOffsetsForRow = const [];

  /// Where the selection is pinned.

  ts.SelectionAnchor? _startAnchor;
  ts.SelectionAnchor? _endAnchor;

  int? _cachedContentLength;
  String? _cachedText;
  List<String>? _cachedLines;

  /// Resets every layer if the cache key has changed. Call before
  /// reading any cached field. Atomic — either everything is from
  /// the new key or everything is from the old.
  void _invalidateCacheIfStale() {
    final mutation = _screen.mutationCount;
    final sbLen = _screen.scrollbackLength;
    if (mutation == _cachedMutation &&
        _cachedRows == _screen.rows &&
        _cachedCols == _screen.cols &&
        _cachedScrollbackLength == sbLen) {
      return;
    }
    _cachedMutation = mutation;
    _cachedRows = _screen.rows;
    _cachedCols = _screen.cols;
    _cachedScrollbackLength = sbLen;
    _cachedTotalRows = sbLen + _screen.rows;
    _metrics = null;
    _cellOffsetsForRow = const [];
    _cachedContentLength = null;
    _cachedText = null;
    _cachedLines = null;
    _syncSelection();
  }

  /// Puts the edges back on the content they were drawn around.
  ///
  /// Offsets move whenever the text does — history evicting, a wrapped line
  /// ending, a re-wrap — so the anchors are what the selection really is and
  /// the edges are re-read off them whenever the screen changes.
  void _syncSelection() {
    final start = _offsetOf(_startAnchor);
    final end = _offsetOf(_endAnchor);
    if (start != selectionStart || end != selectionEnd) {
      setSelectionRange(start, end);
    }
  }

  /// A drag, a select-all, a clear: the edges just moved on purpose, against
  /// text that has not changed underneath them, so this is the moment to take
  /// the anchors from them.
  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    final result = super.dispatchSelectionEvent(event);
    _retakeAnchors();
    return result;
  }

  void _retakeAnchors() {
    _releaseAnchors();
    _startAnchor = _anchorAt(selectionStart);
    _endAnchor = _anchorAt(selectionEnd);
  }

  ts.SelectionAnchor? _anchorAt(int? offset) =>
      offset == null ? null : _screen.anchorAt(offset);

  int? _offsetOf(ts.SelectionAnchor? anchor) =>
      anchor == null ? null : _screen.offsetOfAnchor(anchor);

  void _releaseAnchors() {
    final start = _startAnchor;
    final end = _endAnchor;
    if (start != null) _screen.releaseAnchor(start);
    if (end != null) _screen.releaseAnchor(end);
    _startAnchor = null;
    _endAnchor = null;
  }

  /// The selection offset index for the current buffer, built only once
  /// something actually needs to address the text — it costs a walk over the
  /// whole of history, which no frame should pay just to be drawn.
  ts.SelectionMetrics _ensureMetrics() {
    final held = _metrics;
    if (held != null) return held;
    _cellOffsetsForRow = List<List<int>?>.filled(_cachedTotalRows, null);
    return _metrics = _screen.selectionMetrics();
  }

  /// Returns the per-cell char-offset table for buffer row `r`,
  /// building it on first access.
  List<int> _cellOffsetsForBufferRow(int r) {
    final cached = _cellOffsetsForRow[r];
    if (cached != null) return cached;
    final contentCols = _ensureMetrics().rowContentCols[r];
    final sbLen = _cachedScrollbackLength;
    final offsets = List<int>.filled(_cachedCols + 1, 0);
    var pos = 0;
    for (var c = 0; c < _cachedCols; c++) {
      offsets[c] = pos;
      if (c >= contentCols) continue;
      final cell = (r < sbLen)
          ? _screen.scrollbackCellAt(r, c)
          : _screen.cellAt(r - sbLen, c);
      if (cell.width == ts.CellWidth.continuation) continue;
      pos += cell.char.isEmpty ? 1 : cell.char.length;
    }
    offsets[_cachedCols] = pos;
    _cellOffsetsForRow[r] = offsets;
    return offsets;
  }

  /// Fetches the full selection text and its logical lines from
  /// on first access.
  void _ensureText() {
    if (_cachedText != null) return;
    final selection = _screen.selectionText();
    _cachedText = selection.text;
    _cachedLines = selection.lines;
  }

  /// Total joined-text length, which the screen answers from a running count
  /// of history plus a walk of the viewport. Read on every layout, so it must
  /// not scale with how much scrollback is being kept.
  @override
  int get contentLength {
    _invalidateCacheIfStale();
    return _cachedContentLength ??= _screen.selectionContentLength();
  }

  /// Geometry from row metrics in viewport coordinates. Columns are
  /// approximated by char offset within the row; rects are a bounding box
  /// of the visible selected rows. Paint does its own precise
  /// highlighting from the char range.
  @override
  SelectionGeometry computeSelectionGeometry() {
    final hasContent = contentLength > 0;
    final start = selectionStart;
    final end = selectionEnd;
    if (start == null || end == null || _cachedTotalRows == 0) {
      return SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: hasContent,
      );
    }
    _ensureMetrics();

    final selStart = math.min(start, end);
    final selEnd = math.max(start, end);
    final firstViewportRow = _viewportRowForBufferRow(
      _bufferRowForOffset(selStart),
    );
    final lastViewportRow = _viewportRowForBufferRow(
      _bufferRowForOffset(math.max(selStart, selEnd - 1)),
    );
    final visibleFirst = math.max(firstViewportRow, 0);
    final visibleLast = math.min(lastViewportRow, _screen.rows - 1);

    return SelectionGeometry(
      status: start == end
          ? SelectionStatus.collapsed
          : SelectionStatus.uncollapsed,
      hasContent: hasContent,
      startSelectionPoint: SelectionPoint(
        localPosition: _viewportPositionForOffset(start),
      ),
      endSelectionPoint: SelectionPoint(
        localPosition: _viewportPositionForOffset(end),
      ),
      selectionRects: [
        if (selStart < selEnd && visibleFirst <= visibleLast)
          Rect.fromLTWH(
            0,
            visibleFirst.toDouble(),
            _cachedCols.toDouble(),
            (visibleLast - visibleFirst + 1).toDouble(),
          ),
      ],
    );
  }

  int _bufferRowForOffset(int offset) {
    final starts = _ensureMetrics().rowStarts;
    var low = 0;
    var high = _cachedTotalRows - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (starts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  int _viewportRowForBufferRow(int bufferRow) =>
      bufferRow - _cachedScrollbackLength + _screen.viewOffset;

  Offset _viewportPositionForOffset(int offset) {
    final row = _bufferRowForOffset(offset);
    final metrics = _ensureMetrics();
    final column = (offset - metrics.rowStarts[row]).clamp(
      0,
      metrics.rowLengths[row],
    );
    return Offset(
      column.toDouble(),
      _viewportRowForBufferRow(row).toDouble(),
    );
  }

  @override
  String get selectableText {
    _invalidateCacheIfStale();
    _ensureText();
    return _cachedText!;
  }

  @override
  TextLayoutResult? get selectableLayout {
    _invalidateCacheIfStale();
    _ensureText();
    final lines = _cachedLines!;
    return TextLayoutResult(
      lines: lines,
      actualWidth: _cachedCols,
      actualHeight: lines.length,
      didOverflowWidth: false,
      didOverflowHeight: false,
    );
  }

  /// Translates a position local to this render box (viewport coords)
  /// into a char index in [selectableText] (buffer coords). Round-to-
  /// nearest column boundary so click feel matches typical text
  /// selection — anything past the midpoint of a cell counts as the
  /// next column.
  @override
  int getCharacterIndexAtLocalPosition(Offset localPos) {
    _invalidateCacheIfStale();
    if (_cachedTotalRows == 0) return 0;
    _ensureMetrics();
    final viewportRow = localPos.dy.toInt().clamp(0, _screen.rows - 1);
    final bufferRow =
        (_cachedScrollbackLength + viewportRow - _screen.viewOffset).clamp(
          0,
          _cachedTotalRows - 1,
        );
    final cellOffsets = _cellOffsetsForBufferRow(bufferRow);
    // targetCol clamps to _cachedCols and cellOffsets has _cachedCols + 1
    // entries, so the lookup is always in bounds.
    final targetCol = (localPos.dx + 0.5).floor().clamp(0, _cachedCols);
    return _ensureMetrics().rowStarts[bufferRow] + cellOffsets[targetCol];
  }

  /// Positive [rows] means the drag sits past the bottom edge, toward live
  /// content — which for scrollback is a *decreasing* view offset, hence
  /// the negation. Because [getCharacterIndexAtLocalPosition] reads the
  /// screen's view offset live, each revealed row joins the selection.
  @override
  bool scrollSelectionBy(int rows) {
    final before = _screen.viewOffset;
    if (_screen.scrollViewportBy(-rows) == before) return false;
    markNeedsPaint();
    onScrolled?.call();
    return true;
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);

    final screen = _screen;

    if (screen.modes.syncOutput) return;

    screen.flushPending();

    final cursor = screen.cursor;
    final cursorVisible =
        _showCursor && cursor.visible && screen.viewOffset == 0;
    final ox = offset.dx.round();
    final oy = offset.dy.round();

    final hasSel = hasSelection;
    var selStart = 0;
    var selEnd = 0;
    if (hasSel) {
      selStart = math.min(selectionStart!, selectionEnd!);
      selEnd = math.max(selectionStart!, selectionEnd!);
      _invalidateCacheIfStale();
      _ensureMetrics();
    }
    final scrollbackLen = screen.scrollbackLength;
    final viewOffset = screen.viewOffset;
    final selBg = selection ?? const ui.Color.fromRGB(50, 100, 200);
    final selFg = onSelection ?? ui.Colors.white;

    final rows = math.min(screen.rows, size.height.floor());
    final cols = math.min(screen.cols, size.width.floor());

    // A clipped canvas moves where [TerminalCanvas.setRaw] writes but does
    // not bound it — unlike `drawText` and `fillRect`, which every other
    // component draws through. So a grid scrolled out of a viewport would
    // keep painting, onto whatever now holds those cells.
    final area = canvas.area;
    final firstRow = math.max(0, -oy);
    final lastRow = math.min(rows, area.height.floor() - oy);
    final firstCol = math.max(0, -ox);
    final lastCol = math.min(cols, area.width.floor() - ox);

    for (var r = firstRow; r < lastRow; r++) {
      final bufferRow = scrollbackLen + r - viewOffset;
      final rowVisibleForSelection =
          hasSel && bufferRow >= 0 && bufferRow < _cachedTotalRows;
      final rowStart = rowVisibleForSelection
          ? _metrics!.rowStarts[bufferRow]
          : 0;
      final cellOffsets = rowVisibleForSelection
          ? _cellOffsetsForBufferRow(bufferRow)
          : null;

      final rowBase = screen.viewportRowBase(r);

      for (var c = firstCol; c < lastCol; c++) {
        if (screen.widthAt(rowBase, c) == ts.CellWidth.continuation) {
          canvas.setRaw(ox + c, oy + r, ui.Cell(char: '​'));
          continue;
        }

        final isCursor = cursorVisible && r == cursor.row && c == cursor.col;
        final baseStyle = isCursor
            ? _cursorStyle
            : _cellStyle(
                screen.attrsAt(rowBase, c),
                screen.fgAt(rowBase, c),
                screen.bgAt(rowBase, c),
              );

        final inSelection =
            cellOffsets != null &&
            _isCellInRange(rowStart, cellOffsets, c, selStart, selEnd);

        final style = inSelection
            ? baseStyle.copyWith(color: selFg, backgroundColor: selBg)
            : baseStyle;

        final cluster = screen.charAt(rowBase, c);
        final ch = cluster.isEmpty ? ' ' : cluster;
        canvas.setRaw(ox + c, oy + r, ui.Cell(char: ch, style: style));
      }
    }
  }

  /// True when the cell at column `col` in this row (whose row text
  /// starts at `rowStart` in [_cachedText]) overlaps `[selStart,
  /// selEnd)`. Continuation cells (`width == 0`) have zero char range
  /// and so report false here — they get painted with the default
  /// zero-width-space treatment in the paint loop.
  static bool _isCellInRange(
    int rowStart,
    List<int> cellOffsets,
    int col,
    int selStart,
    int selEnd,
  ) {
    final cellCharStart = rowStart + cellOffsets[col];
    final cellCharEnd = rowStart + cellOffsets[col + 1];
    if (cellCharStart == cellCharEnd) return false;
    return cellCharStart < selEnd && cellCharEnd > selStart;
  }

  static const _cursorStyle = TextStyle(
    color: ui.Colors.black,
    backgroundColor: ui.Colors.white,
  );

  static TextStyle _cellStyle(int attrs, int packedFg, int packedBg) {
    var fg = _toUiColor(packedFg) ?? ui.Colors.white;
    var bg = _toUiColor(packedBg);

    if (ts.CellAttrs.isInverse(attrs)) {
      final tmp = fg;
      fg = bg ?? const ui.Color.fromRGB(0, 0, 0);
      bg = tmp;
    }

    if (ts.CellAttrs.isFaint(attrs)) {
      fg = _dimColor(fg);
    }

    final hasUnderline = ts.CellAttrs.hasUnderline(attrs);
    final hasStrike = ts.CellAttrs.isStrikethrough(attrs);
    final decoration = hasUnderline && hasStrike
        ? TextDecoration.combine(
            [TextDecoration.underline, TextDecoration.lineThrough],
          )
        : hasUnderline
        ? TextDecoration.underline
        : hasStrike
        ? TextDecoration.lineThrough
        : TextDecoration.none;

    return TextStyle(
      color: fg,
      backgroundColor: bg,
      fontWeight: ts.CellAttrs.isBold(attrs)
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: ts.CellAttrs.isItalic(attrs)
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: decoration,
    );
  }

  static ui.Color _dimColor(ui.Color color) =>
      ui.Color.fromRGB(color.red ~/ 2, color.green ~/ 2, color.blue ~/ 2);

  /// Converts a packed terminal color without materializing a
  /// [ts.Color], so the paint loop allocates nothing per cell.
  static ui.Color? _toUiColor(int packed) => switch (ts.colorKind(packed)) {
    ts.ColorKind.defaultForeground => null,
    ts.ColorKind.defaultBackground => null,
    ts.ColorKind.indexed => _ansi256ToUi(ts.colorIndex(packed)),
    ts.ColorKind.rgb => ui.Color.fromRGB(
      ts.colorRed(packed),
      ts.colorGreen(packed),
      ts.colorBlue(packed),
    ),
  };

  static ui.Color _ansi256ToUi(int index) {
    if (index < 16) return _ansi16[index];
    if (index < 232) {
      final i = index - 16;
      final r = ((i ~/ 36) % 6) * 51;
      final g = ((i ~/ 6) % 6) * 51;
      final b = (i % 6) * 51;
      return ui.Color.fromRGB(r, g, b);
    }
    final gray = 8 + (index - 232) * 10;
    return ui.Color.fromRGB(gray, gray, gray);
  }
}

const _ansi16 = <ui.Color>[
  ui.Color.fromRGB(0, 0, 0),
  ui.Color.fromRGB(205, 0, 0),
  ui.Color.fromRGB(0, 205, 0),
  ui.Color.fromRGB(205, 205, 0),
  ui.Color.fromRGB(0, 0, 238),
  ui.Color.fromRGB(205, 0, 205),
  ui.Color.fromRGB(0, 205, 205),
  ui.Color.fromRGB(229, 229, 229),
  ui.Color.fromRGB(127, 127, 127),
  ui.Color.fromRGB(255, 0, 0),
  ui.Color.fromRGB(0, 255, 0),
  ui.Color.fromRGB(255, 255, 0),
  ui.Color.fromRGB(92, 92, 255),
  ui.Color.fromRGB(255, 0, 255),
  ui.Color.fromRGB(0, 255, 255),
  ui.Color.fromRGB(255, 255, 255),
];
