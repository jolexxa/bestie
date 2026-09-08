import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

/// One terminal cell: a single grapheme cluster and the colour [slot] it
/// inherited from the box-tree node that produced it.
@immutable
class MathCell {
  /// Creates a cell showing [cluster] in [slot].
  const MathCell(this.cluster, [this.slot]);

  /// Exactly one grapheme cluster.
  final String cluster;

  /// The colour slot this cell belongs to, or null when it carries none.
  final int? slot;

  /// The padding cell composition fills gaps with.
  static const space = MathCell(' ');

  /// Whether this cell shows nothing — used to find the blank rows katex pads
  /// enclosures with.
  bool get isSpace => cluster.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is MathCell && other.cluster == cluster && other.slot == slot;

  @override
  int get hashCode => Object.hash(cluster, slot);

  @override
  String toString() => 'MathCell($cluster, $slot)';
}

/// A maximal run of adjacent cells sharing one [slot], ready to become a
/// single styled span.
@immutable
class MathRun {
  /// Creates a run showing [text] in [slot].
  const MathRun(this.text, this.slot);

  /// The run's characters.
  final String text;

  /// The slot every cell in the run carries, or null when they carry none.
  final int? slot;

  @override
  bool operator ==(Object other) =>
      other is MathRun && other.text == text && other.slot == slot;

  @override
  int get hashCode => Object.hash(text, slot);

  @override
  String toString() => 'MathRun($text, $slot)';
}

/// A rectangular block of terminal cells with a known baseline row.
///
/// This is the terminal analogue of a TeX box: a piece of laid-out math that
/// carries its own [baseline] so neighbours can be aligned on it. Every row in
/// [cells] has the same length; composition preserves that invariant.
///
/// Rows above the baseline are [ascent]; rows below are [descent]. A plain
/// single glyph has `ascent == descent == 0` and sits entirely on the baseline.
@immutable
class MathGrid {
  MathGrid._(this.cells, this.baseline);

  /// A single-row grid whose baseline is that row, every cell in [slot].
  factory MathGrid.line(String text, [int? slot]) =>
      MathGrid._([_cellsOf(text, slot)], 0);

  /// The zero-width, single-row empty grid (a layout no-op).
  factory MathGrid.empty() => MathGrid._(const [<MathCell>[]], 0);

  /// A grid from explicit, already equal-width [rows] of text, every cell in
  /// [slot], with [baseline] as the baseline row index.
  factory MathGrid.fromRows(List<String> rows, int baseline, [int? slot]) =>
      MathGrid._([for (final row in rows) _cellsOf(row, slot)], baseline);

  /// A grid from explicit, already equal-width [rows] of cells.
  factory MathGrid.fromCells(List<List<MathCell>> rows, int baseline) =>
      MathGrid._([for (final row in rows) List.unmodifiable(row)], baseline);

  /// Places [parts] side by side, left to right, aligned on their baselines.
  ///
  /// The result's ascent/descent are the maxima across [parts], so a tall
  /// neighbour (a fraction, a superscript stack) lifts and drops the row band
  /// without disturbing where each part sits relative to the baseline.
  factory MathGrid.beside(List<MathGrid> parts) {
    if (parts.isEmpty) return MathGrid.empty();

    final ascent = parts.map((p) => p.ascent).reduce(_max);
    final descent = parts.map((p) => p.descent).reduce(_max);
    final width = parts.map((p) => p.width).fold(0, _sum);
    final buffer = _blankBuffer(ascent + descent + 1, width);

    var column = 0;
    for (final part in parts) {
      final top = ascent - part.ascent;
      for (var i = 0; i < part.height; i++) {
        _blit(buffer[top + i], part.cells[i], column);
      }
      column += part.width;
    }
    return MathGrid._freeze(buffer, ascent);
  }

  /// Freezes a mutable cell [buffer] into an immutable grid with the given
  /// [baseline] row.
  factory MathGrid._freeze(List<List<MathCell>> buffer, int baseline) =>
      MathGrid._([for (final row in buffer) List.unmodifiable(row)], baseline);

  /// The rows of cells, top to bottom. Never empty; each entry has [width]
  /// entries.
  final List<List<MathCell>> cells;

  /// The index into [cells] that sits on the shared baseline.
  final int baseline;

  /// The rows as text, top to bottom — the rendered picture without its slots.
  late final List<String> lines = [
    for (final row in cells) row.map((cell) => cell.cluster).join(),
  ];

  /// Cell width of every row.
  int get width => cells.first.length;

  /// Number of rows.
  int get height => cells.length;

  /// Rows above the baseline.
  int get ascent => baseline;

  /// Rows below the baseline.
  int get descent => height - baseline - 1;

  /// A single row of [newWidth] [fill] cells, keeping the slot of the rule it
  /// came from.
  MathGrid stretchedRuleTo(int newWidth, String fill) {
    final slot = cells.first.isEmpty ? null : cells.first.first.slot;
    return MathGrid._([List.filled(newWidth, MathCell(fill, slot))], 0);
  }

  /// The grid as newline-joined text, with trailing spaces trimmed per row so
  /// goldens read cleanly.
  String toText() =>
      lines.map((l) => l.replaceAll(_trailingSpaces, '')).join('\n');

  /// The grid's slots drawn as a picture the same shape as [lines], so a test
  /// or a debugging session can read an assignment at a glance instead of
  /// indexing into cells.
  String slotSketch() => [
    for (final row in cells) row.map(_sketchOf).join(),
  ].join('\n');

  /// The cells coalesced into maximal same-slot runs, per row.
  List<List<MathRun>> rowRuns() => [for (final row in cells) _coalesce(row)];

  @override
  String toString() => 'MathGrid(${width}x$height, baseline: $baseline)';

  // ---------------------------------------------------------------------------
  // Internal buffer helpers shared with the rasterizer via [MathGridBuilder].
  // ---------------------------------------------------------------------------

  static final RegExp _trailingSpaces = RegExp(r' +$');

  static String _sketchOf(MathCell cell) =>
      cell.slot == null ? ' ' : '${cell.slot! % 10}';

  static List<MathRun> _coalesce(List<MathCell> row) {
    final runs = <MathRun>[];
    final buffer = StringBuffer();
    int? current;
    var started = false;
    for (final cell in row) {
      if (started && cell.slot != current) {
        runs.add(MathRun(buffer.toString(), current));
        buffer.clear();
      }
      current = cell.slot;
      started = true;
      buffer.write(cell.cluster);
    }
    if (started) runs.add(MathRun(buffer.toString(), current));
    return runs;
  }

  static List<MathCell> _cellsOf(String text, int? slot) => List.unmodifiable([
    for (final cluster in text.characters) MathCell(cluster, slot),
  ]);

  static int _max(int a, int b) => a > b ? a : b;
  static int _sum(int a, int b) => a + b;

  static List<List<MathCell>> _blankBuffer(int rows, int columns) =>
      List.generate(
        rows,
        (_) => List.filled(columns, MathCell.space),
        growable: false,
      );

  static void _blit(List<MathCell> row, List<MathCell> source, int column) {
    for (var i = 0; i < source.length; i++) {
      row[column + i] = source[i];
    }
  }
}

/// A mutable canvas for stacking positioned grids at explicit row offsets,
/// used by the rasterizer to lay out vertical lists (fractions, sup/sub, roots).
///
/// Rows are addressed relative to the builder's own baseline (row `0`);
/// negative rows are above it. The builder tracks the occupied extent and
/// materialises a [MathGrid] on [build].
class MathGridBuilder {
  final List<_Placement> _placements = [];
  int _minRow = 0;
  int _maxRow = 0;
  int _width = 0;

  /// Draws [grid] so that its own baseline lands on [row] (relative to this
  /// builder's baseline), horizontally centred within the final width.
  ///
  /// When [stretchAs] is non-null the grid is treated as a rule and widened to
  /// fill the whole layout with that fill character. The builder's baseline
  /// row (`0`) is always kept in the occupied band so neighbours align to it.
  void placeCentered(MathGrid grid, int row, {String? stretchAs}) {
    _placements.add(_Placement(grid, row, stretchAs));
    final top = row - grid.ascent;
    final bottom = row + grid.descent;
    if (top < _minRow) _minRow = top;
    if (bottom > _maxRow) _maxRow = bottom;
    if (grid.width > _width) _width = grid.width;
  }

  /// Freezes the accumulated placements into a single grid.
  MathGrid build() {
    if (_placements.isEmpty) return MathGrid.empty();

    final height = _maxRow - _minRow + 1;
    final buffer = MathGrid._blankBuffer(height, _width);
    for (final placement in _placements) {
      final grid = placement.stretchAs != null
          ? placement.grid.stretchedRuleTo(_width, placement.stretchAs!)
          : placement.grid;
      final left = (_width - grid.width) ~/ 2;
      for (var i = 0; i < grid.height; i++) {
        final target = (placement.row - grid.baseline + i) - _minRow;
        MathGrid._blit(buffer[target], grid.cells[i], left);
      }
    }
    return MathGrid._freeze(buffer, -_minRow);
  }
}

class _Placement {
  const _Placement(this.grid, this.row, this.stretchAs);

  final MathGrid grid;
  final int row;
  final String? stretchAs;
}
