import 'dart:async';
import 'dart:convert' show utf8;

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/src/cell.dart';
import 'package:terminal_screen/src/cursor.dart';
import 'package:terminal_screen/src/diff.dart';
import 'package:terminal_screen/src/line_bytes.dart';
import 'package:terminal_screen/src/line_writer.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/modes.dart';
import 'package:terminal_screen/src/outbound.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/pen_lines.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:terminal_screen/src/region.dart';
import 'package:terminal_screen/src/resize_behavior.dart';
import 'package:terminal_screen/src/selection_anchor.dart';
import 'package:terminal_screen/src/selection_text.dart';
import 'package:terminal_screen/src/sgr.dart';
import 'package:terminal_screen/src/snapshot.dart';
import 'package:terminal_screen/src/unicode.dart';
import 'package:terminal_screen/src/wait.dart';
import 'package:vt_parser/vt_parser.dart';

/// How much of a line or display an ED / EL sequence clears.
enum _EraseExtent {
  /// From the cursor to the end.
  toEnd,

  /// From the start up to and including the cursor.
  toStart,

  /// Everything.
  all;

  /// The extent an ED / EL parameter selects, or `null` for values outside
  /// the range — including ED's 3, which asks for the scrollback and so is
  /// not an extent of the display at all. See the ED case.
  static _EraseExtent? ofParameter(int parameter) => switch (parameter) {
    0 => toEnd,
    1 => toStart,
    2 => all,
    _ => null,
  };
}

/// A live terminal screen: a mutable cell grid driven by
/// `ParserEvent`s from `vt_parser`, plus an agent-facing
/// snapshot / diff / waitFor API.
class Screen implements ParserSink {
  /// Create a screen sized to [rows] × [cols] with up to
  /// [scrollbackBytes] of main-buffer history. Pass an [outbound] sink
  /// to receive replies to DA / DSR / CPR / palette queries as raw
  /// bytes.
  ///
  /// [resizeBehavior] says what the child does once it has been told a
  /// new size, which decides how much of the re-wrap is ours to do.
  Screen({
    required int rows,
    required int cols,
    required int scrollbackBytes,
    this.resizeBehavior = const ReflowingResize(),
    this.outbound,
  }) : _rows = rows,
       _cols = cols,
       _scrollRegionBottom = rows - 1 {
    _mainBuffer = Buffer(
      rows: rows,
      cols: cols,
      scrollbackBytes: scrollbackBytes,
      graphemes: _graphemes,
      onEvicted: _publishEvicted,
    );
    _altBuffer = Buffer(
      rows: rows,
      cols: cols,
      scrollbackBytes: 0,
      graphemes: _graphemes,
    );
    _activeBuffer = _mainBuffer;
    _resetTabStops();
  }

  /// A screen sized [rows] × [cols] with the transcript [ansi] already parsed
  /// onto it and settled.
  factory Screen.fromAnsi(
    List<int> ansi, {
    required int rows,
    required int cols,
    required int scrollbackBytes,
  }) {
    final screen = Screen(
      rows: rows,
      cols: cols,
      scrollbackBytes: scrollbackBytes,
    );
    VtParser(sink: screen).advance(ansi);
    screen.flushPending();
    return screen;
  }

  /// Sink that receives replies to terminal queries. May be
  /// `null`, in which case replies are discarded.
  final Sink<List<int>>? outbound;

  /// Told about each line the history drops, in the order it drops them, with
  /// the pen behind it — a field rather than a stream because a screen is
  /// recorded by the one thing recording it, and because a screen nobody
  /// records should pay nothing for having this.
  LineSink? onEvicted;

  /// What the child does after a resize. See the constructor.
  final ResizeBehavior resizeBehavior;

  // ── Grid state ──────────────────────────────────────────

  late final Buffer _mainBuffer;
  late final Buffer _altBuffer;
  late Buffer _activeBuffer;

  /// Which buffer holds the cell the saved cursor names. DECSET 1049
  /// saves the main cursor on the way *into* the alt screen, so this
  /// is not simply whichever buffer is active when it is read.
  Buffer? _savedCursorBuffer;

  bool get _savedOnMainBuffer =>
      cursor.hasSaved && _savedCursorBuffer == _mainBuffer;

  int _rows;
  int _cols;

  /// Number of rows in the viewport.
  int get rows => _rows;

  /// Number of columns in each row.
  int get cols => _cols;

  /// The live cursor. Treat as read-only.
  final Cursor cursor = Cursor();

  /// The active pen (SGR state).
  final Pen _pen = Pen();

  /// Active terminal modes.
  final TerminalModes _modes = TerminalModes();

  /// Read-only snapshot of modes at construction time cannot
  /// change; expose the mutable object as the interface for
  /// getters that want to inspect mode state without copying.
  TerminalModes get modes => _modes;

  /// `true` if the alt buffer is active.
  bool get onAltScreen => _activeBuffer == _altBuffer;

  String? _title;
  String? _iconName;

  /// Current window title.
  String? get title => _title;

  /// Current icon name.
  String? get iconName => _iconName;

  /// DECSTBM scroll region, inclusive on both ends. Defaults to
  /// the entire viewport.
  int _scrollRegionTop = 0;
  int _scrollRegionBottom;

  /// Tab stops per column — `true` means "stop here." Defaults
  /// to every 8 columns.
  List<bool> _tabStops = <bool>[];

  /// Grapheme-cluster buffer. Code points are appended here on
  /// each `onPrint`; we commit all-but-the-last cluster on each
  /// print (the last might still extend, e.g. a base letter
  /// waiting for a combining mark or a ZWJ emoji waiting for
  /// the joined character). Non-print events and observation
  /// methods (`snapshot`, etc.) flush the buffer completely.
  final StringBuffer _pendingGrapheme = StringBuffer();

  // ── Wait ────────────────────────────────────────────────

  final List<Waiter> _waiters = <Waiter>[];

  // ── Mutation tracking ───────────────────────────────────

  int _mutationCount = 0;

  /// Monotonic counter bumped on every mutation that calls
  /// [_afterMutation]. Renderers can compare against a cached
  /// value to invalidate derived state (text projections, layout
  /// caches) without copying the whole grid.
  int get mutationCount => _mutationCount;

  // ── Construction helper ─────────────────────────────────

  /// Initialise tab stops to every 8 columns (the xterm default).
  void _resetTabStops() {
    _tabStops = List<bool>.filled(_cols, false);
    for (var c = 0; c < _cols; c += 8) {
      _tabStops[c] = true;
    }
  }

  // ── Public read-only grid access ────────────────────────

  /// Grapheme clusters longer than one code point, shared by both
  /// buffers so a cell's stored code means the same thing whichever
  /// one it came from.
  final GraphemeTable _graphemes = GraphemeTable();

  CellData _cellData(Buffer buffer, int base, int col) {
    final style = buffer.styleAt(base, col);
    return (
      char: _graphemes.decode(buffer.charCodeAt(base, col)),
      fg: unpackColor(buffer.fgAt(base, col)),
      bg: unpackColor(buffer.bgAt(base, col)),
      attrs: styleAttrs(style),
      width: styleWidth(style),
    );
  }

  /// Read a live cell. Allocates a record per call; paint loops
  /// should use [viewportRowBase] and the field accessors instead.
  CellData cellAt(int row, int col) =>
      _cellData(_activeBuffer, _activeBuffer.rowBase(row), col);

  /// Commit any pending grapheme clusters so reads see the complete
  /// grid, without materializing a snapshot.
  void flushPending() => _flushPendingGraphemes();

  /// The currently-dirty rows in the active buffer.
  Iterable<int> get dirtyRows => _activeBuffer.dirtyRows;

  /// Clear the active buffer's dirty-row bitmap.
  void clearDirty() => _activeBuffer.clearDirty();

  /// Length of the main-buffer scrollback (0 while the alt
  /// buffer is active).
  int get scrollbackLength => onAltScreen ? 0 : _mainBuffer.scrollbackLength;

  /// Read a scrollback cell.
  CellData scrollbackCellAt(int line, int col) =>
      _cellData(_mainBuffer, Buffer.scrollbackHandle(line), col);

  /// Where each held row's content lands in the selectable text.
  SelectionMetrics selectionMetrics() => _activeBuffer.selectionMetrics();

  /// Chars [selectionText] would hold, for a caller that wants the size of
  /// the selectable text rather than an index into it. Costs the viewport
  /// rather than the whole history, so it is safe to ask every frame.
  int selectionContentLength() => _activeBuffer.selectionContentLength();

  /// The selectable text of every held row, wrap-joined and trimmed the
  /// way reflow reconstructs a line.
  SelectionText selectionText() => _activeBuffer.selectionText();

  /// Renders a line on its way out of history for [onEvicted].
  void _publishEvicted(LogicalLine line) {
    final sink = onEvicted;
    if (sink == null) return;
    _recorder.reset();
    line.writeInto(_recorder, _graphemes.decode);
    sink(_recorder.text.view(), _recorder.pen.view(), _recorder.units);
  }

  /// Built the first time a line is recorded, and kept for every line after.
  late final LineWriter _recorder = LineWriter();

  /// Just the logical lines [selectionText] would hold.
  List<String> selectionLines() => _activeBuffer.selectionLines();

  /// The lines of history with the pen behind each, for a recorder that means
  /// to redraw them later rather than only read them.
  List<LineBytes> recordedLines() => _mainBuffer.penLines();

  /// Pins whatever content sits at char [offset] of the selectable text, so a
  /// caller can ask later where that content went rather than assuming it
  /// stayed put. Null when the text is shorter than [offset].
  ///
  /// The caller owns what it is given and must [releaseAnchor] it.
  SelectionAnchor? anchorAt(int offset) => _activeBuffer.anchorAt(offset);

  /// Where the content [anchor] holds sits in the selectable text now, or the
  /// front of it once that content has dropped out of history — what survived
  /// starts where the content used to be.
  int? offsetOfAnchor(SelectionAnchor anchor) => _activeBuffer.offsetOf(anchor);

  /// Lets go of [anchor].
  void releaseAnchor(SelectionAnchor anchor) {
    _mainBuffer.release(anchor);
    _altBuffer.release(anchor);
  }

  /// Chars evicted off the front of the selectable text since this
  /// screen was created.
  int get evictedSelectionChars =>
      onAltScreen ? 0 : (_mainBuffer.store?.evictedChars ?? 0);

  // ── Viewport scroll offset ──────────────────────────────

  /// Number of rows the user has scrolled the displayed viewport
  /// up into scrollback. `0` means the live viewport is shown
  /// unchanged; values up to [scrollbackLength] reveal older
  /// history at the top while pushing the live viewport off the
  /// bottom.
  int _viewOffset = 0;

  /// Current view offset. See [_viewOffset].
  int get viewOffset => _viewOffset;

  /// Maximum value [setViewOffset] will accept right now: the
  /// current [scrollbackLength], or `0` while on the alt screen.
  int get maxViewOffset => scrollbackLength;

  /// Move the displayed viewport to [offset], clamped to
  /// `[0, maxViewOffset]`. Returns the actually-applied offset.
  int setViewOffset(int offset) {
    final clamped = offset.clamp(0, maxViewOffset);
    if (clamped != _viewOffset) {
      _viewOffset = clamped;
      _activeBuffer.markAllDirty();
    }
    return _viewOffset;
  }

  /// Adjust the viewport offset by [delta]. Positive scrolls up
  /// into history; negative scrolls back down toward the live
  /// viewport. Returns the actually-applied offset.
  int scrollViewportBy(int delta) => setViewOffset(_viewOffset + delta);

  /// Flat index where the row displayed at viewport [row] begins,
  /// consulting scrollback when [viewOffset] > 0.
  int viewportRowBase(int row) {
    if (_viewOffset == 0) return _activeBuffer.rowBase(row);
    final sbLen = _activeBuffer.scrollbackLength;
    final virtual = sbLen - _viewOffset + row;
    return virtual < sbLen
        ? Buffer.scrollbackHandle(virtual)
        : _activeBuffer.rowBase(virtual - sbLen);
  }

  /// The grapheme cluster at [base] + [col]. Empty for the right half
  /// of a wide character.
  String charAt(int base, int col) =>
      _graphemes.decode(_activeBuffer.charCodeAt(base, col));

  /// The packed foreground color at [base] + [col].
  int fgAt(int base, int col) => _activeBuffer.fgAt(base, col);

  /// The packed background color at [base] + [col].
  int bgAt(int base, int col) => _activeBuffer.bgAt(base, col);

  /// The `CellAttrs` bitfield at [base] + [col].
  int attrsAt(int base, int col) =>
      styleAttrs(_activeBuffer.styleAt(base, col));

  /// The [CellWidth] at [base] + [col].
  CellWidth widthAt(int base, int col) =>
      styleWidth(_activeBuffer.styleAt(base, col));

  /// Read a cell from the displayed viewport, consulting
  /// scrollback when [viewOffset] > 0.
  CellData viewportCellAt(int row, int col) =>
      _cellData(_activeBuffer, viewportRowBase(row), col);

  // ── Resize ──────────────────────────────────────────────

  /// Resize the screen. Both buffers are resized, preserving as
  /// much content as the new dimensions allow.
  void resize({required int rows, required int cols}) {
    if (rows == _rows && cols == _cols) return;
    // The live cursor names a cell in whichever buffer is active, so it
    // rides that buffer's resize and no other.
    final live = ReflowPin(row: cursor.row, col: cursor.col);
    // A child that repaints has only the alt screen in hand while it is
    // up, so re-wrapping the main buffer now would lay out rows nobody
    // is going to redraw. It waits for the alt screen to be put away.
    if (!onAltScreen || !resizeBehavior.defersMainBufferOnAltScreen) {
      _resizeMainBuffer(
        rows: rows,
        cols: cols,
        live: onAltScreen ? null : live,
      );
    }
    _altBuffer.resize(
      newRows: rows,
      newCols: cols,
      cursor: onAltScreen ? live : null,
      behavior: resizeBehavior,
    );
    _rows = rows;
    _cols = cols;
    _scrollRegionTop = 0;
    _scrollRegionBottom = rows - 1;
    cursor.row = live.row.clamp(0, rows - 1);
    cursor.col = live.col.clamp(0, cols - 1);
    // The flag means "parked at the right margin"; it survives only if
    // that is still where the cursor's cell ended up.
    cursor.pendingWrap = cursor.pendingWrap && cursor.col == cols - 1;
    _resetTabStops();
    // Scrollback survives the resize, but a row-count change moves
    // where any given offset lands; clamp so the view stays in range.
    _viewOffset = _viewOffset.clamp(0, maxViewOffset);
    _afterMutation();
  }

  /// Resize the main buffer, carrying every position that names a cell
  /// in it across the re-wrap.
  void _resizeMainBuffer({
    required int rows,
    required int cols,
    required ReflowPin? live,
  }) {
    final saved = _savedOnMainBuffer ? cursor.savedPosition : null;
    final savedPin = saved == null
        ? null
        : ReflowPin(row: saved.row, col: saved.col);
    // A scrolled-back view names the row displayed at the top, which
    // sits `viewOffset` rows above the viewport.
    final view = _viewOffset == 0 ? null : ReflowPin(row: -_viewOffset, col: 0);

    _mainBuffer.resizeReflowing(
      newRows: rows,
      newCols: cols,
      cursor: live,
      pins: [?savedPin, ?view],
      behavior: resizeBehavior,
    );

    if (savedPin != null) {
      cursor.relocateSaved(
        row: savedPin.row < 0 ? 0 : savedPin.row,
        col: savedPin.col,
      );
    }
    if (view != null) _viewOffset = view.row < 0 ? -view.row : 0;
  }

  // ── Snapshot / diff / wait ──────────────────────────────

  /// Capture an immutable snapshot of the current state. Any
  /// pending grapheme clusters are flushed first so the snapshot
  /// reflects the complete grid.
  ScreenSnapshot snapshot({bool includeScrollback = false}) {
    _flushPendingGraphemes();
    final grid = List<List<CellData>>.generate(_rows, (r) {
      final base = _activeBuffer.rowBase(r);
      return List<CellData>.generate(
        _cols,
        (c) => _cellData(_activeBuffer, base, c),
      );
    });
    List<List<CellData>>? scrollback;
    if (includeScrollback && !onAltScreen) {
      final sbLen = _mainBuffer.scrollbackLength;
      scrollback = List<List<CellData>>.generate(sbLen, (i) {
        final base = Buffer.scrollbackHandle(i);
        return List<CellData>.generate(
          _cols,
          (c) => _cellData(_mainBuffer, base, c),
        );
      });
    }
    return ScreenSnapshot(
      rows: _rows,
      cols: _cols,
      grid: grid,
      scrollback: scrollback,
      cursor: cursor.freeze(),
      onAltScreen: onAltScreen,
      title: _title,
      iconName: _iconName,
      modes: _modes.freeze(),
    );
  }

  /// Compute the difference between the current state and
  /// [previous].
  ScreenDiff diffSince(ScreenSnapshot previous) =>
      computeDiff(previous, snapshot());

  /// Wait until [predicate] returns `true` for a fresh snapshot.
  Future<ScreenSnapshot> waitFor(
    bool Function(ScreenSnapshot snapshot) predicate, {
    required Duration timeout,
  }) {
    // Evaluate once against the current state before registering.
    final current = snapshot();
    if (predicate(current)) {
      return Future<ScreenSnapshot>.value(current);
    }
    late Waiter w;
    w = Waiter(
      predicate: predicate,
      timeout: timeout,
      onRemove: _waiters.remove,
    );
    _waiters.add(w);
    return w.completer.future;
  }

  /// Wait until the visible text contains [needle].
  Future<ScreenSnapshot> waitForText(
    String needle, {
    required Duration timeout,
    bool includeScrollback = false,
  }) {
    if (includeScrollback && !onAltScreen) {
      final full = snapshot(includeScrollback: true);
      if (full.text.contains(needle)) {
        return Future<ScreenSnapshot>.value(full);
      }
      final sb = full.scrollback;
      if (sb != null) {
        final sbText = sb
            .map(
              (row) => row
                  .where((c) => c.width != CellWidth.continuation)
                  .map((c) => c.char)
                  .join(),
            )
            .join('\n');
        if (sbText.contains(needle)) {
          return Future<ScreenSnapshot>.value(full);
        }
      }
    }
    return waitFor(
      (s) => s.text.contains(needle),
      timeout: timeout,
    );
  }

  /// Wait until the visible text matches [pattern].
  Future<ScreenSnapshot> waitForRegex(
    RegExp pattern, {
    required Duration timeout,
  }) {
    return waitFor((s) => pattern.hasMatch(s.text), timeout: timeout);
  }

  /// Wait until [test] returns `true` for the text inside [region].
  Future<ScreenSnapshot> waitForRegion(
    Region region,
    bool Function(String regionText) test, {
    required Duration timeout,
  }) {
    return waitFor((s) => test(s.textIn(region)), timeout: timeout);
  }

  /// Call after any mutation that might have changed observable
  /// state. Snapshots waiters and completes any whose predicate
  /// matches.
  void _afterMutation() {
    _mutationCount++;
    if (_waiters.isEmpty) return;
    final snap = snapshot();
    final done = <Waiter>[];
    for (final w in _waiters) {
      if (w.tryComplete(snap)) done.add(w);
    }
    if (done.isNotEmpty) {
      _waiters.removeWhere(done.contains);
    }
  }

  // ── Outbound helpers ────────────────────────────────────

  void _reply(List<int> bytes) {
    outbound?.add(bytes);
  }

  // ── ParserSink implementation ───────────────────────────

  @override
  void onPrint(int char) {
    _pendingGrapheme.write(stringForCodePoint(char));
    _drainPendingGraphemes();
    _afterMutation();
  }

  @override
  void onExecute(int byte) {
    _flushPendingGraphemes();
    switch (byte) {
      case 0x07: // BEL
        // No-op; we could forward to a bell callback in v0.2.
        break;
      case 0x08: // BS
        _backspace();
      case 0x09: // HT
        _tab();
      case 0x0A: // LF
      case 0x0B: // VT
      case 0x0C: // FF
        _lineFeed();
      case 0x0D: // CR
        cursor.col = 0;
        cursor.pendingWrap = false;
      case 0x85: // NEL
        cursor.col = 0;
        _lineFeed();
      case 0x88: // HTS
        _setTabStopAtCursor();
      case 0x8D: // RI
        _reverseIndex();
      default:
        // SI, SO, other C1 — silently ignore for v0.1.
        break;
    }
    _afterMutation();
  }

  @override
  void onCsiDispatch({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    _flushPendingGraphemes();
    _handleCsi(
      params: params,
      intermediates: intermediates,
      finalByte: finalByte,
      ignore: ignore,
    );
    _afterMutation();
  }

  @override
  void onOscDispatch({
    required List<List<int>> params,
    required bool bellTerminated,
  }) {
    _flushPendingGraphemes();
    _handleOsc(params);
    _afterMutation();
  }

  @override
  void onEscDispatch({
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    _flushPendingGraphemes();
    _handleEsc(intermediates: intermediates, finalByte: finalByte);
    _afterMutation();
  }

  @override
  void onDcsHook({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    _flushPendingGraphemes();
    // DCS is parse-and-drop for v0.1.
  }

  @override
  void onDcsPut(int byte) {
    // Ignored in v0.1.
  }

  @override
  void onDcsUnhook() {
    // Ignored in v0.1.
  }

  // ── Print path: grapheme buffering ──────────────────────

  /// Commit all-but-the-last grapheme cluster from the pending
  /// buffer. The last cluster is held back because it might still
  /// be extended by a subsequent code point (combining mark, ZWJ
  /// emoji sequence, regional indicator pair).
  void _drainPendingGraphemes() {
    if (_pendingGrapheme.isEmpty) return;
    final split = splitBufferedGraphemes(_pendingGrapheme.toString());
    split.complete.forEach(_placeCluster);
    _pendingGrapheme
      ..clear()
      ..write(split.tail);
  }

  /// Commit ALL clusters in the pending buffer — nothing held
  /// back. Called before non-print events so the cursor moves to
  /// the right place, and before observations so the caller sees
  /// the full grid.
  void _flushPendingGraphemes() {
    if (_pendingGrapheme.isEmpty) return;
    final text = _pendingGrapheme.toString();
    flushBufferedGraphemes(text).forEach(_placeCluster);
    _clearPendingGraphemes();
  }

  void _clearPendingGraphemes() => _pendingGrapheme.clear();

  /// Commit a single grapheme cluster to the grid at the current
  /// cursor position with the current pen style. Handles
  /// auto-wrap, wide characters, and combining marks that stack
  /// onto a previous base cell.
  void _placeCluster(String cluster) {
    if (cluster.isEmpty) return;
    final width = CellWidth.ofColumns(graphemeWidth(cluster));
    if (width == CellWidth.continuation) {
      // Pure combining mark / variation selector — stack onto the
      // previous base cell if there is one.
      final targetCol = cursor.col == 0 ? -1 : cursor.col - 1;
      if (targetCol < 0) return;
      final rowBase = _activeBuffer.rowBase(cursor.row);
      final existing = _graphemes.decode(
        _activeBuffer.charCodeAt(rowBase, targetCol),
      );
      final combined = existing + cluster;
      _activeBuffer.setCharCodeAt(
        rowBase,
        targetCol,
        _graphemes.encode(combined),
      );
      // VS16 (U+FE0F) widens the base to emoji presentation
      // (width 2). Retroactively expand the cell and mark the
      // next cell as continuation. Do NOT advance the cursor —
      // the child program treats VS16 as zero-width and has
      // already positioned its cursor past the base character.
      final targetStyle = _activeBuffer.styleAt(rowBase, targetCol);
      final newWidth = graphemeWidth(combined);
      if (newWidth == 2 &&
          styleWidth(targetStyle) == CellWidth.single &&
          cursor.col < _cols) {
        _activeBuffer
          ..setStyleAt(
            rowBase,
            targetCol,
            packStyle(attrs: styleAttrs(targetStyle), width: CellWidth.wide),
          )
          ..eraseCells(rowBase, cursor.col, 1, packedDefaultBg)
          ..setStyleAt(
            rowBase,
            cursor.col,
            packStyle(attrs: CellAttrs.none, width: CellWidth.continuation),
          );
      }
      _activeBuffer.markDirty(cursor.row);
      return;
    }

    var arrivedByWrap = false;
    if (cursor.pendingWrap && _modes.autoWrap) {
      cursor.col = 0;
      _lineFeed();
      arrivedByWrap = true;
      cursor.pendingWrap = false;
    }

    final packedFg = packColor(_pen.fg);
    final packedBg = packColor(_pen.bg);

    // If a width-2 cluster can't fit, wrap one column early.
    if (width == CellWidth.wide && cursor.col == _cols - 1) {
      if (_modes.autoWrap) {
        // Tag the abandoned column so reflow can tell it from a space
        // the child actually printed.
        _activeBuffer.setCell(
          _activeBuffer.rowBase(cursor.row),
          cursor.col,
          charCode: blankCharCode,
          fg: packedDefaultFg,
          bg: packedDefaultBg,
          style: packStyle(attrs: CellAttrs.none, width: CellWidth.spacerHead),
        );
        cursor.col = 0;
        _lineFeed();
        arrivedByWrap = true;
      } else {
        // DECAWM off: just place the cluster in the last column
        // (the right half is lost).
        _activeBuffer
          ..setCell(
            _activeBuffer.rowBase(cursor.row),
            cursor.col,
            charCode: _graphemes.encode(cluster),
            fg: packedFg,
            bg: packedBg,
            style: packStyle(attrs: _pen.attrs, width: CellWidth.single),
          )
          ..markDirty(cursor.row);
        return;
      }
    }

    if (_modes.insertMode) {
      _insertBlanks(width.columns);
    }

    // A row continues the one above for exactly as long as its first column
    // holds the cluster that wrapped into it. A child that addresses the row
    // and prints there instead — which is what OpenConsole does when it
    // repaints after a resize — is starting a line of its own.
    if (cursor.col == 0) {
      _activeBuffer.setWrappedAt(cursor.row, wrapped: arrivedByWrap);
    }

    final rowBase = _activeBuffer.rowBase(cursor.row);
    _activeBuffer
      ..setCell(
        rowBase,
        cursor.col,
        charCode: _graphemes.encode(cluster),
        fg: packedFg,
        bg: packedBg,
        style: packStyle(attrs: _pen.attrs, width: width),
      )
      ..markDirty(cursor.row);

    // Orphan recovery: if we just overwrote the LEFT half of a
    // wide cluster, the old right-half cell (at col + 1) is now
    // stale — clear it.
    if (cursor.col + 1 < _cols &&
        styleWidth(_activeBuffer.styleAt(rowBase, cursor.col + 1)) ==
            CellWidth.continuation) {
      _activeBuffer.eraseCells(rowBase, cursor.col + 1, 1, packedDefaultBg);
    }
    // Conversely: if we just overwrote the RIGHT half of a wide
    // cluster (we're placing a new cell here with width > 0, but
    // the cell to our left was width 2), clear that left half.
    if (cursor.col > 0 &&
        styleWidth(_activeBuffer.styleAt(rowBase, cursor.col - 1)) ==
            CellWidth.wide) {
      _activeBuffer.eraseCells(rowBase, cursor.col - 1, 1, packedDefaultBg);
    }

    if (width == CellWidth.wide) {
      _activeBuffer
        ..eraseCells(rowBase, cursor.col + 1, 1, packedDefaultBg)
        ..setStyleAt(
          rowBase,
          cursor.col + 1,
          packStyle(attrs: CellAttrs.none, width: CellWidth.continuation),
        );
    }

    cursor.col += width.columns;
    if (cursor.col >= _cols) {
      cursor.col = _cols - 1;
      cursor.pendingWrap = true;
    }
  }

  void _insertBlanks(int count) {
    final base = _activeBuffer.rowBase(cursor.row);
    final from = cursor.col;
    final shifted = _cols - from - count;
    if (shifted > 0) {
      _activeBuffer.moveCells(
        base,
        from: from,
        to: from + count,
        count: shifted,
      );
    }
    _activeBuffer
      ..eraseCells(
        base,
        from,
        count < _cols - from ? count : _cols - from,
        packColor(_pen.bg),
      )
      ..markDirty(cursor.row);
  }

  // ── Cursor movement primitives ──────────────────────────

  void _backspace() {
    if (cursor.col > 0) {
      cursor.col -= 1;
    }
    cursor.pendingWrap = false;
  }

  void _tab() {
    if (cursor.col >= _cols - 1) return;
    var col = cursor.col + 1;
    while (col < _cols - 1 && !_tabStops[col]) {
      col += 1;
    }
    cursor.col = col;
    cursor.pendingWrap = false;
  }

  void _lineFeed() {
    if (cursor.row == _scrollRegionBottom) {
      _scrollUpInRegion(1);
    } else if (cursor.row < _rows - 1) {
      cursor.row += 1;
      // A line feed starts a new logical line, so the row it lands on
      // no longer continues the one above.
      _activeBuffer.setWrappedAt(cursor.row, wrapped: false);
    }
    cursor.pendingWrap = false;
  }

  void _reverseIndex() {
    if (cursor.row == _scrollRegionTop) {
      _scrollDownInRegion(1);
    } else if (cursor.row > 0) {
      cursor.row -= 1;
    }
    cursor.pendingWrap = false;
  }

  void _scrollUpInRegion(int n) {
    // Top-anchored regions on the main screen evict their top
    // row into scrollback, matching xterm. This covers both the
    // normal full-screen case (top=0, bottom=rows-1) and the
    // partial case (top=0, bottom<rows-1) used by ratatui inline
    // mode to push content above the inline viewport into
    // history.
    if (_scrollRegionTop == 0 && !onAltScreen) {
      for (var i = 0; i < n; i++) {
        _activeBuffer.scrollTopRegionUpToScrollback(
          _scrollRegionBottom,
          background: packColor(_pen.bg),
        );
        // Keep a scrolled-up viewer pinned to the same content as
        // long as scrollback is growing; once capacity is hit the
        // oldest visible line silently falls off the top.
        if (_viewOffset > 0) {
          _viewOffset = (_viewOffset + 1).clamp(
            0,
            _activeBuffer.scrollbackLength,
          );
        }
      }
      return;
    }
    for (var i = 0; i < n; i++) {
      _activeBuffer.scrollRegionUp(
        _scrollRegionTop,
        _scrollRegionBottom,
        background: packColor(_pen.bg),
      );
    }
  }

  void _scrollDownInRegion(int n) {
    for (var i = 0; i < n; i++) {
      _activeBuffer.scrollRegionDown(
        _scrollRegionTop,
        _scrollRegionBottom,
        background: packColor(_pen.bg),
      );
    }
  }

  void _setTabStopAtCursor() {
    if (cursor.col >= 0 && cursor.col < _cols) {
      _tabStops[cursor.col] = true;
    }
  }

  // ── CSI handler ─────────────────────────────────────────

  void _handleCsi({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    int pn([int i = 0, int defaultValue = 1]) {
      if (i >= params.length || params[i].isEmpty) return defaultValue;
      final v = params[i].first;
      return v == 0 ? defaultValue : v;
    }

    int p0zero([int i = 0]) {
      if (i >= params.length || params[i].isEmpty) return 0;
      return params[i].first;
    }

    final private = intermediates.isNotEmpty && intermediates.first == 0x3F;
    final spaceIntermediate =
        intermediates.isNotEmpty && intermediates.first == 0x20;
    final bangIntermediate =
        intermediates.isNotEmpty && intermediates.first == 0x21;

    // Private markers >, <, = (0x3C-0x3F excluding ?) indicate
    // vendor-specific CSI extensions (e.g. ESC[>4m = modifyOtherKeys,
    // ESC[<u = kitty keyboard pop). Standard cases must not fire for
    // these — only cases that explicitly check intermediates should.
    final hasUnknownIntermediate =
        intermediates.isNotEmpty &&
        !private &&
        !spaceIntermediate &&
        !bangIntermediate;

    switch (finalByte) {
      case 0x40: // @ ICH
        _insertBlanks(pn());
      case 0x41: // A CUU
        cursor.row = (cursor.row - pn()).clamp(_scrollRegionTop, _rows - 1);
        cursor.pendingWrap = false;
      case 0x42: // B CUD
        cursor.row = (cursor.row + pn()).clamp(0, _scrollRegionBottom);
        cursor.pendingWrap = false;
      case 0x43: // C CUF
        cursor.col = (cursor.col + pn()).clamp(0, _cols - 1);
        cursor.pendingWrap = false;
      case 0x44: // D CUB
        cursor.col = (cursor.col - pn()).clamp(0, _cols - 1);
        cursor.pendingWrap = false;
      case 0x45: // E CNL
        cursor.col = 0;
        cursor.row = (cursor.row + pn()).clamp(0, _rows - 1);
        cursor.pendingWrap = false;
      case 0x46: // F CPL
        cursor.col = 0;
        cursor.row = (cursor.row - pn()).clamp(0, _rows - 1);
        cursor.pendingWrap = false;
      case 0x47: // G CHA
        cursor.col = (pn() - 1).clamp(0, _cols - 1);
        cursor.pendingWrap = false;
      case 0x48: // H CUP
      case 0x66: // f HVP
        final r = pn();
        final c = pn(1);
        _moveCursorAbsolute(r - 1, c - 1);
      case 0x49: // I CHT — forward tab N times
        for (var i = 0; i < pn(); i++) {
          _tab();
        }
      case 0x4A: // J ED
        {
          final parameter = p0zero();
          // Parameter 3 drops the history and leaves the display alone,
          // which is why the usual full clear is `ESC[3J ESC[2J ESC[H` —
          // one sequence for each half of what is on screen.
          if (parameter == 3) {
            _activeBuffer.clearScrollback();
            setViewOffset(_viewOffset);
          } else {
            final extent = _EraseExtent.ofParameter(parameter);
            if (extent != null) _eraseInDisplay(extent);
          }
        }
      case 0x4B: // K EL
        {
          final extent = _EraseExtent.ofParameter(p0zero());
          if (extent != null) _eraseInLine(extent);
        }
      case 0x4C: // L IL
        _insertLines(pn());
      case 0x4D: // M DL
        _deleteLines(pn());
      case 0x50: // P DCH
        _deleteChars(pn());
      case 0x53: // S SU
        _scrollUpInRegion(pn());
      case 0x54: // T SD
        _scrollDownInRegion(pn());
      case 0x58: // X ECH
        _eraseChars(pn());
      case 0x5A: // Z CBT — backward tab N times
        for (var i = 0; i < pn(); i++) {
          _backTab();
        }
      case 0x60: // ` HPA
        cursor.col = (pn() - 1).clamp(0, _cols - 1);
        cursor.pendingWrap = false;
      case 0x61: // a HPR
        cursor.col = (cursor.col + pn()).clamp(0, _cols - 1);
      case 0x62: // b REP — unimplemented in v0.1; silently drop
        break;
      case 0x63: // c DA
        if (intermediates.isEmpty) {
          _reply(OutboundEncoder.da1());
        } else if (intermediates.first == 0x3E) {
          _reply(OutboundEncoder.da2());
        } else if (intermediates.first == 0x3D) {
          _reply(OutboundEncoder.da3());
        }
      case 0x64: // d VPA
        cursor.row = (pn() - 1).clamp(0, _rows - 1);
        cursor.pendingWrap = false;
      case 0x65: // e VPR
        cursor.row = (cursor.row + pn()).clamp(0, _rows - 1);
      case 0x67: // g TBC
        _tabClear(p0zero());
      case 0x68: // h SM / DECSET
        _setModes(params, private: private, enable: true);
      case 0x6C: // l RM / DECRST
        _setModes(params, private: private, enable: false);
      case 0x6D: // m SGR
        if (!hasUnknownIntermediate) applySgr(_pen, params);
      case 0x6E: // n DSR
        _handleDsr(p0zero(), private: private);
      case 0x70: // p — DECSTR (soft reset) if bang intermediate
        if (bangIntermediate) _softReset();
      case 0x71: // q — DECSCUSR if space intermediate
        if (spaceIntermediate) _setCursorStyle(p0zero());
      case 0x72: // r DECSTBM
        if (intermediates.isEmpty) _setScrollRegion(pn(), pn(1, _rows));
      case 0x73: // s SCOSC save cursor
        if (intermediates.isEmpty) _saveCursor();
      case 0x75: // u SCORC restore cursor
        if (intermediates.isEmpty) _restoreCursor();
      default:
        // Unknown final byte — silently ignore.
        break;
    }
  }

  void _moveCursorAbsolute(int row, int col) {
    if (_modes.originMode) {
      cursor.row = (row + _scrollRegionTop).clamp(
        _scrollRegionTop,
        _scrollRegionBottom,
      );
    } else {
      cursor.row = row.clamp(0, _rows - 1);
    }
    cursor.col = col.clamp(0, _cols - 1);
    cursor.pendingWrap = false;
  }

  void _eraseRows(int from, int to) {
    final background = packColor(_pen.bg);
    for (var r = from; r < to; r++) {
      _activeBuffer
        ..eraseRow(r, background: background)
        ..markDirty(r);
    }
  }

  void _eraseInDisplay(_EraseExtent extent) {
    switch (extent) {
      case _EraseExtent.toEnd:
        _eraseInLine(_EraseExtent.toEnd);
        _eraseRows(cursor.row + 1, _rows);
      case _EraseExtent.toStart:
        _eraseInLine(_EraseExtent.toStart);
        _eraseRows(0, cursor.row);
      case _EraseExtent.all:
        _eraseRows(0, _rows);
    }
  }

  void _eraseInLine(_EraseExtent extent) {
    final base = _activeBuffer.rowBase(cursor.row);
    final background = packColor(_pen.bg);
    switch (extent) {
      case _EraseExtent.toEnd:
        _activeBuffer.eraseCells(
          base,
          cursor.col,
          _cols - cursor.col,
          background,
        );
      case _EraseExtent.toStart:
        final count = (cursor.col + 1).clamp(0, _cols);
        _activeBuffer.eraseCells(base, 0, count, background);
      case _EraseExtent.all:
        _activeBuffer.eraseCells(base, 0, _cols, background);
    }
    _activeBuffer.markDirty(cursor.row);
  }

  void _eraseChars(int n) {
    final base = _activeBuffer.rowBase(cursor.row);
    final count = n.clamp(0, _cols - cursor.col);
    _activeBuffer
      ..eraseCells(base, cursor.col, count, packColor(_pen.bg))
      ..markDirty(cursor.row);
  }

  void _insertLines(int n) {
    if (cursor.row < _scrollRegionTop || cursor.row > _scrollRegionBottom) {
      return;
    }
    for (var i = 0; i < n; i++) {
      _activeBuffer.scrollRegionDown(
        cursor.row,
        _scrollRegionBottom,
        background: packColor(_pen.bg),
      );
    }
  }

  void _deleteLines(int n) {
    if (cursor.row < _scrollRegionTop || cursor.row > _scrollRegionBottom) {
      return;
    }
    for (var i = 0; i < n; i++) {
      _activeBuffer.scrollRegionUp(
        cursor.row,
        _scrollRegionBottom,
        background: packColor(_pen.bg),
      );
    }
  }

  void _deleteChars(int n) {
    final base = _activeBuffer.rowBase(cursor.row);
    final from = cursor.col;
    final shifted = _cols - from - n;
    if (shifted > 0) {
      _activeBuffer.moveCells(base, from: from + n, to: from, count: shifted);
    }
    final blankFrom = shifted > 0 ? _cols - n : from;
    _activeBuffer
      ..eraseCells(base, blankFrom, _cols - blankFrom, packColor(_pen.bg))
      ..markDirty(cursor.row);
  }

  void _backTab() {
    if (cursor.col <= 0) return;
    var col = cursor.col - 1;
    while (col > 0 && !_tabStops[col]) {
      col -= 1;
    }
    cursor.col = col;
    cursor.pendingWrap = false;
  }

  void _tabClear(int mode) {
    switch (mode) {
      case 0:
        if (cursor.col >= 0 && cursor.col < _cols) {
          _tabStops[cursor.col] = false;
        }
      case 3:
        for (var c = 0; c < _cols; c++) {
          _tabStops[c] = false;
        }
      default:
        break;
    }
  }

  void _setScrollRegion(int top, int bottom) {
    final t = (top - 1).clamp(0, _rows - 1);
    final b = (bottom - 1).clamp(0, _rows - 1);
    if (t < b) {
      _scrollRegionTop = t;
      _scrollRegionBottom = b;
    } else {
      _scrollRegionTop = 0;
      _scrollRegionBottom = _rows - 1;
    }
    _moveCursorAbsolute(0, 0);
  }

  // ── Mode handling ───────────────────────────────────────

  void _setModes(
    List<List<int>> params, {
    required bool private,
    required bool enable,
  }) {
    for (final group in params) {
      if (group.isEmpty) continue;
      final mode = group.first;
      if (private) {
        _setDecMode(mode, enable: enable);
      } else {
        _setAnsiMode(mode, enable: enable);
      }
    }
  }

  void _setAnsiMode(int mode, {required bool enable}) {
    if (mode == 4) {
      _modes.insertMode = enable;
    }
  }

  void _setDecMode(int mode, {required bool enable}) {
    switch (mode) {
      case 1:
        _modes.cursorKeysApp = enable;
      case 5:
        _modes.reverseVideo = enable;
      case 6:
        _modes.originMode = enable;
        _moveCursorAbsolute(0, 0);
      case 7:
        _modes.autoWrap = enable;
      case 12:
        _modes.cursorBlink = enable;
      case 25:
        _modes.cursorVisible = enable;
        cursor.visible = enable;
      case 9:
        _modes.mouseMode = enable ? MouseMode.x10 : MouseMode.off;
      case 1000:
        _modes.mouseMode = enable ? MouseMode.vt200 : MouseMode.off;
      case 1002:
        _modes.mouseMode = enable ? MouseMode.buttonEvent : MouseMode.off;
      case 1003:
        _modes.mouseMode = enable ? MouseMode.anyEvent : MouseMode.off;
      case 1004:
        _modes.focusReport = enable;
      case 1005:
        _modes.mouseEncoding = enable ? MouseEncoding.utf8 : MouseEncoding.x10;
      case 1006:
        _modes.mouseEncoding = enable ? MouseEncoding.sgr : MouseEncoding.x10;
      case 1015:
        _modes.mouseEncoding = enable ? MouseEncoding.urxvt : MouseEncoding.x10;
      case 47:
      case 1047:
        _switchAltScreen(enable: enable, saveCursor: false);
      case 1048:
        if (enable) {
          _saveCursor();
        } else {
          _restoreCursor();
        }
      case 1049:
        _switchAltScreen(enable: enable, saveCursor: true);
      case 2004:
        _modes.bracketedPaste = enable;
      case 2026:
        _modes.syncOutput = enable;
      default:
        break;
    }
  }

  /// Restore the cursor with the pen and origin mode it was saved under.
  ///
  /// A saved position only rides a resize on the buffer that saved it, so a
  /// restore can name a cell the grid no longer has; clamp it back inside.
  void _restoreCursor() {
    final saved = cursor.restore();
    _pen.fg = saved.fg;
    _pen.bg = saved.bg;
    _pen.attrs = saved.attrs;
    _modes.originMode = saved.originMode;
    cursor.row = cursor.row.clamp(0, _rows - 1);
    cursor.col = cursor.col.clamp(0, _cols - 1);
    cursor.pendingWrap = cursor.pendingWrap && cursor.col == _cols - 1;
  }

  /// Save the cursor together with the pen and origin mode it was
  /// written with, recording which buffer the position names.
  void _saveCursor() {
    cursor.save(
      fg: _pen.fg,
      bg: _pen.bg,
      attrs: _pen.attrs,
      originMode: _modes.originMode,
    );
    _savedCursorBuffer = _activeBuffer;
  }

  void _switchAltScreen({required bool enable, required bool saveCursor}) {
    // Either direction snaps the displayed viewport back to live:
    // alt screen has no scrollback, and on return the user wants
    // to see fresh shell output, not whatever they were paging.
    _viewOffset = 0;
    if (enable) {
      if (onAltScreen) return;
      if (saveCursor) _saveCursor();
      _activeBuffer = _altBuffer;
      // Clear the alt buffer on entry so programs start clean.
      for (var r = 0; r < _rows; r++) {
        _altBuffer.eraseRow(r);
      }
      _altBuffer.markAllDirty();
      cursor.row = 0;
      cursor.col = 0;
      cursor.pendingWrap = false;
    } else {
      if (!onAltScreen) return;
      // Any resize deferred while the alt screen was up is settled here,
      // once, at whatever size it finished on.
      if (_mainBuffer.rows != _rows || _mainBuffer.cols != _cols) {
        _resizeMainBuffer(rows: _rows, cols: _cols, live: null);
      }
      _activeBuffer = _mainBuffer;
      _mainBuffer.markAllDirty();
      if (saveCursor) _restoreCursor();
    }
  }

  // ── DSR (status reports) ────────────────────────────────

  void _handleDsr(int kind, {required bool private}) {
    if (kind == 5) {
      _reply(OutboundEncoder.dsrOk());
    } else if (kind == 6) {
      final row = _modes.originMode
          ? cursor.row - _scrollRegionTop + 1
          : cursor.row + 1;
      final col = cursor.col + 1;
      if (private) {
        _reply(OutboundEncoder.dexCpr(row, col));
      } else {
        _reply(OutboundEncoder.cpr(row, col));
      }
    }
  }

  void _setCursorStyle(int param) {
    switch (param) {
      case 0:
      case 1:
        cursor.style = CursorStyle.block;
        cursor.blinking = true;
      case 2:
        cursor.style = CursorStyle.block;
        cursor.blinking = false;
      case 3:
        cursor.style = CursorStyle.underline;
        cursor.blinking = true;
      case 4:
        cursor.style = CursorStyle.underline;
        cursor.blinking = false;
      case 5:
        cursor.style = CursorStyle.bar;
        cursor.blinking = true;
      case 6:
        cursor.style = CursorStyle.bar;
        cursor.blinking = false;
      default:
        break;
    }
  }

  void _softReset() {
    _pen.reset();
    _modes.originMode = false;
    _modes.autoWrap = true;
    _modes.insertMode = false;
    _modes.cursorVisible = true;
    cursor.visible = true;
    cursor.forgetSaved();
    _scrollRegionTop = 0;
    _scrollRegionBottom = _rows - 1;
  }

  // ── ESC handler ─────────────────────────────────────────

  void _handleEsc({required List<int> intermediates, required int finalByte}) {
    // Intermediate-first simple escapes: charset designation
    // (ESC ( B, ESC ) 0, etc.). We store them as no-ops.
    if (intermediates.isNotEmpty) return;
    switch (finalByte) {
      case 0x37: // 7 DECSC
        _saveCursor();
      case 0x38: // 8 DECRC
        _restoreCursor();
      case 0x44: // D IND
        _lineFeed();
      case 0x45: // E NEL
        cursor.col = 0;
        _lineFeed();
      case 0x48: // H HTS
        _setTabStopAtCursor();
      case 0x4D: // M RI
        _reverseIndex();
      case 0x63: // c RIS
        _hardReset();
      default:
        break;
    }
  }

  void _hardReset() {
    _mainBuffer.fullReset();
    _altBuffer.fullReset();
    _activeBuffer = _mainBuffer;
    _pen.reset();
    cursor
      ..row = 0
      ..col = 0
      ..visible = true
      ..pendingWrap = false
      ..forgetSaved();
    _modes
      ..autoWrap = true
      ..originMode = false
      ..insertMode = false
      ..cursorVisible = true
      ..cursorKeysApp = false
      ..cursorBlink = true
      ..reverseVideo = false
      ..bracketedPaste = false
      ..focusReport = false
      ..mouseMode = MouseMode.off
      ..mouseEncoding = MouseEncoding.x10;
    _scrollRegionTop = 0;
    _scrollRegionBottom = _rows - 1;
    _title = null;
    _iconName = null;
    _viewOffset = 0;
    _resetTabStops();
  }

  // ── OSC handler ─────────────────────────────────────────

  void _handleOsc(List<List<int>> params) {
    if (params.isEmpty) return;
    final firstGroup = params.first;
    if (firstGroup.isEmpty) return;
    final code = _bytesToInt(firstGroup);
    switch (code) {
      case 0:
        if (params.length > 1) {
          final text = utf8.decode(params[1], allowMalformed: true);
          _title = text;
          _iconName = text;
        }
      case 1:
        if (params.length > 1) {
          _iconName = utf8.decode(params[1], allowMalformed: true);
        }
      case 2:
        if (params.length > 1) {
          _title = utf8.decode(params[1], allowMalformed: true);
        }
      case 4:
        _handleOscPaletteQuery(params);
      case 10:
        if (params.length > 1 && _isQuery(params[1])) {
          _reply(OutboundEncoder.defaultForeground());
        }
      case 11:
        if (params.length > 1 && _isQuery(params[1])) {
          _reply(OutboundEncoder.defaultBackground());
        }
      default:
        break;
    }
  }

  void _handleOscPaletteQuery(List<List<int>> params) {
    // Accept `OSC 4 ; index ; ?` and reply with the default
    // xterm palette value for indices 0..15.
    if (params.length < 3) return;
    if (!_isQuery(params[2])) return;
    final indexStr = String.fromCharCodes(params[1]);
    final index = int.tryParse(indexStr);
    if (index == null) return;
    final reply = OutboundEncoder.palette(index);
    if (reply != null) _reply(reply);
  }

  static bool _isQuery(List<int> bytes) =>
      bytes.length == 1 && bytes.first == 0x3F;

  static int _bytesToInt(List<int> bytes) {
    var value = 0;
    for (final b in bytes) {
      if (b < 0x30 || b > 0x39) return -1;
      value = value * 10 + (b - 0x30);
    }
    return value;
  }
}
