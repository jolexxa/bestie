import 'package:meta/meta.dart';
import 'package:terminal_screen/src/cell.dart';
import 'package:terminal_screen/src/snapshot.dart';

/// A single changed cell.
@immutable
class CellChange {
  /// Create a [CellChange].
  const CellChange({
    required this.row,
    required this.col,
    required this.before,
    required this.after,
  });

  /// Row index (0-based) of the change.
  final int row;

  /// Column index (0-based) of the change.
  final int col;

  /// The previous cell state.
  final CellData before;

  /// The current cell state.
  final CellData after;

  @override
  bool operator ==(Object other) =>
      other is CellChange &&
      other.row == row &&
      other.col == col &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(CellChange, row, col, before, after);

  @override
  String toString() =>
      'CellChange(row: $row, col: $col, before: $before, after: $after)';
}

/// Structured difference between two [ScreenSnapshot]s.
@immutable
class ScreenDiff {
  /// Create a [ScreenDiff].
  const ScreenDiff({
    required this.cells,
    required this.cursorChanged,
    required this.titleChanged,
    required this.iconNameChanged,
    required this.altScreenToggled,
    required this.modesChanged,
  });

  /// Every cell that changed, ordered first by row then by col.
  final List<CellChange> cells;

  /// `true` if any cursor attribute changed.
  final bool cursorChanged;

  /// `true` if the window title changed.
  final bool titleChanged;

  /// `true` if the icon name changed.
  final bool iconNameChanged;

  /// `true` if the alt-screen toggle flipped.
  final bool altScreenToggled;

  /// `true` if any terminal mode flag changed.
  final bool modesChanged;

  /// `true` when nothing changed at all.
  bool get isEmpty =>
      cells.isEmpty &&
      !cursorChanged &&
      !titleChanged &&
      !iconNameChanged &&
      !altScreenToggled &&
      !modesChanged;

  /// Number of distinct rows that contain at least one changed
  /// cell.
  int get changedRowCount {
    if (cells.isEmpty) return 0;
    var count = 1;
    var last = cells.first.row;
    for (var i = 1; i < cells.length; i++) {
      if (cells[i].row != last) {
        count += 1;
        last = cells[i].row;
      }
    }
    return count;
  }
}

/// Compute the diff between [previous] and [current]. Both
/// snapshots must have the same dimensions.
ScreenDiff computeDiff(ScreenSnapshot previous, ScreenSnapshot current) {
  final changes = <CellChange>[];
  if (previous.rows == current.rows && previous.cols == current.cols) {
    for (var r = 0; r < current.rows; r++) {
      for (var c = 0; c < current.cols; c++) {
        final before = previous.grid[r][c];
        final after = current.grid[r][c];
        if (before != after) {
          changes.add(
            CellChange(row: r, col: c, before: before, after: after),
          );
        }
      }
    }
  }

  return ScreenDiff(
    cells: changes,
    cursorChanged: previous.cursor != current.cursor,
    titleChanged: previous.title != current.title,
    iconNameChanged: previous.iconName != current.iconName,
    altScreenToggled: previous.onAltScreen != current.onAltScreen,
    modesChanged: previous.modes != current.modes,
  );
}
