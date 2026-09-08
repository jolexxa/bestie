// Snapshots are mutable DTOs while terminal state is assembled.
// ignore_for_file: must_be_immutable

import 'package:meta/meta.dart';
import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/cell.dart';
import 'package:terminal_screen/src/cursor.dart';
import 'package:terminal_screen/src/modes.dart';
import 'package:terminal_screen/src/region.dart';

/// An immutable snapshot of a `Screen` at a moment in time.
///
/// Snapshots are allocated on demand (agent APIs call
/// `Screen.snapshot()`) and are completely decoupled from the live
/// grid — mutating the screen after a snapshot is taken will not
/// affect the snapshot's contents. The [text] getter lazily
/// flattens the visible viewport into newline-delimited text and
/// caches the result on a private lazy field; the class is marked
/// immutable for consumers since the cache is a pure function of
/// the other fields.
@immutable
class ScreenSnapshot {
  /// Create a snapshot. Callers pass immutable data lists; the
  /// snapshot does not copy them, so callers must not mutate the
  /// lists after construction.
  ScreenSnapshot({
    required this.rows,
    required this.cols,
    required List<List<CellData>> grid,
    required this.cursor,
    required this.onAltScreen,
    required this.title,
    required this.iconName,
    required this.modes,
    List<List<CellData>>? scrollback,
  }) : _grid = grid,
       _scrollback = scrollback;

  /// Number of viewport rows.
  final int rows;

  /// Number of viewport columns.
  final int cols;

  final List<List<CellData>> _grid;
  final List<List<CellData>>? _scrollback;

  /// Read-only access to the viewport grid.
  List<List<CellData>> get grid => _grid;

  /// Read-only access to the scrollback, if this snapshot was
  /// captured with `includeScrollback: true`. Otherwise `null`.
  List<List<CellData>>? get scrollback => _scrollback;

  /// Cursor state at the time of the snapshot.
  final CursorData cursor;

  /// `true` if the alt screen was active at the time.
  final bool onAltScreen;

  /// Current window title (OSC 2), if any.
  final String? title;

  /// Current icon name (OSC 1), if any.
  final String? iconName;

  /// Mode state at the time of the snapshot.
  final TerminalModesData modes;

  String? _cachedText;

  /// The visible viewport joined into newline-delimited text.
  /// Wide cells contribute one grapheme; their continuation
  /// cells (width 0) contribute nothing. Trailing spaces are
  /// trimmed from each row before joining so that agents can
  /// search for exact text without caring about padding.
  String get text {
    return _cachedText ??= _flattenGrid(_grid);
  }

  /// The visible text inside [region], joined with newlines.
  String textIn(Region region) {
    final clamped = region.clampTo(rows, cols);
    if (clamped == null) return '';
    final lines = <String>[];
    for (var r = clamped.row; r <= clamped.lastRow; r++) {
      final buf = StringBuffer();
      for (var c = clamped.col; c <= clamped.lastCol; c++) {
        final cell = _grid[r][c];
        if (cell.width == CellWidth.continuation) continue;
        buf.write(cell.char);
      }
      lines.add(_rtrim(buf.toString()));
    }
    return lines.join('\n');
  }

  String _flattenGrid(List<List<CellData>> g) {
    final lines = <String>[];
    for (final row in g) {
      final buf = StringBuffer();
      for (final cell in row) {
        if (cell.width == CellWidth.continuation) continue;
        buf.write(cell.char);
      }
      lines.add(_rtrim(buf.toString()));
    }
    // Drop trailing empty lines so that an otherwise-blank
    // viewport joins cleanly without a cascade of `\n`s.
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

  String _rtrim(String s) {
    var end = s.length;
    while (end > 0 && s.codeUnitAt(end - 1) == 0x20) {
      end -= 1;
    }
    return s.substring(0, end);
  }
}
