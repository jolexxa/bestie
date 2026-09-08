import 'package:meta/meta.dart';

/// Tunable mapping from katex's em-based box dimensions onto discrete terminal
/// cells. Injected into the rasterizer so layout density can be adjusted (and
/// exercised) without touching the walk itself.
@immutable
class RasterMetrics {
  /// Creates a metrics mapping; defaults suit a typical monospace terminal.
  const RasterMetrics({
    this.rowsPerEm = 2.0,
    this.kernColsPerEm = 4.5,
    this.ruleColsPerEm = 2.0,
  });

  /// Vertical resolution: how many terminal rows one em of baseline shift maps
  /// to. Governs how far superscripts lift and fraction parts separate.
  final double rowsPerEm;

  /// Horizontal resolution for kerns/spacing. Tuned so a standard `0.222em`
  /// math space rounds to a single column while hair kerns collapse to zero.
  final double kernColsPerEm;

  /// Horizontal resolution for standalone rules (fraction bars are stretched to
  /// their column instead, so this only sizes free-standing rules).
  final double ruleColsPerEm;

  /// Rounds a downward baseline shift (em, positive = down) to a row offset.
  int rowForShift(double shiftEm) => (shiftEm * rowsPerEm).round();

  /// Rounds a kern width (em) to a non-negative column count.
  int colsForKern(double widthEm) {
    final cols = (widthEm * kernColsPerEm).round();
    return cols < 0 ? 0 : cols;
  }

  /// Rounds a rule width (em) to a non-negative column count. Zero-width struts
  /// (used for spacing inside arrays) collapse to nothing rather than a stray
  /// line.
  int colsForRule(double widthEm) {
    final cols = (widthEm * ruleColsPerEm).round();
    return cols < 0 ? 0 : cols;
  }

  /// Rounds a vertical extent (a box's em height or depth) to a non-negative
  /// number of rows — used to size stretchy delimiters to their content.
  int rowsForExtent(double extentEm) {
    final rows = (extentEm * rowsPerEm).round();
    return rows < 0 ? 0 : rows;
  }
}
