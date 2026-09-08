import 'package:meta/meta.dart';

/// A rectangular sub-region of the screen grid.
@immutable
class Region {
  /// Construct a region anchored at (row, col) with the given
  /// [height] and [width]. Coordinates are 0-indexed.
  const Region({
    required this.row,
    required this.col,
    required this.height,
    required this.width,
  }) : assert(row >= 0, 'row must be >= 0'),
       assert(col >= 0, 'col must be >= 0'),
       assert(height > 0, 'height must be > 0'),
       assert(width > 0, 'width must be > 0');

  /// Top-left row (0-indexed).
  final int row;

  /// Top-left column (0-indexed).
  final int col;

  /// Height in rows.
  final int height;

  /// Width in columns.
  final int width;

  /// The inclusive last row of the region.
  int get lastRow => row + height - 1;

  /// The inclusive last column of the region.
  int get lastCol => col + width - 1;

  /// Clamp this region to fit inside a `(rows, cols)` grid.
  /// Returns `null` if the region is entirely outside the grid.
  Region? clampTo(int rows, int cols) {
    final r0 = row.clamp(0, rows);
    final c0 = col.clamp(0, cols);
    final r1 = (row + height).clamp(0, rows);
    final c1 = (col + width).clamp(0, cols);
    if (r1 <= r0 || c1 <= c0) return null;
    return Region(row: r0, col: c0, height: r1 - r0, width: c1 - c0);
  }

  @override
  bool operator ==(Object other) =>
      other is Region &&
      other.row == row &&
      other.col == col &&
      other.height == height &&
      other.width == width;

  @override
  int get hashCode => Object.hash(Region, row, col, height, width);

  @override
  String toString() =>
      'Region(row: $row, col: $col, height: $height, width: $width)';
}
