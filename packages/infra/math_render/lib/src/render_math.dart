import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/src/box_rasterizer.dart';
import 'package:math_render/src/glyph_fixups.dart';
import 'package:math_render/src/math_grid.dart';
import 'package:math_render/src/math_render_result.dart';
import 'package:math_render/src/raster_metrics.dart';
import 'package:math_render/src/tagging/math_tagger.dart';

/// Parses [tex] as LaTeX math and lays it out on a terminal grid.
///
/// [displayMode] selects katex's display style — bigger big operators, limits
/// stacked above/below — which suits standalone (`$$…$$`) equations; leave it
/// false for inline math. Returns [MathRendered] on success, or
/// [MathParseFailed] when katex rejects the source, so callers can fall back to
/// the raw text without a try/catch.
///
/// [tagger] classifies the parsed expression before layout runs, and the
/// resulting tags ride along on the grid's cells for a theme to paint. The
/// default tags nothing, so the grid is exactly the picture and no more.
MathRenderResult renderMath(
  String tex, {
  RasterMetrics metrics = const RasterMetrics(),
  bool displayMode = false,
  MathTagger tagger = tagNothing,
}) {
  final BoxNode box;
  try {
    box = renderToBox(tex, options: KatexOptions(displayMode: displayMode));
  } on ParseError catch (error) {
    return MathParseFailed(error.message);
  }
  final grid = BoxRasterizer(metrics, tagger(box)).rasterize(box);
  return MathRendered(
    MathGrid.fromCells(fixGridCells(grid.cells), grid.baseline),
  );
}
