/// Renders LaTeX math to a terminal character grid.
///
/// Parses with `katex_dart` into its backend-agnostic box tree, then walks that
/// tree (a `BoxRasterizer`) onto a baseline-aware `MathGrid` of cells. The
/// entry point is `renderMath`.
library;

export 'src/box_rasterizer.dart';
export 'src/inline_linearizer.dart';
export 'src/math_grid.dart';
export 'src/math_inline_result.dart';
export 'src/math_render_result.dart';
export 'src/raster_metrics.dart';
export 'src/render_math.dart';
export 'src/render_math_inline.dart';

export 'src/tagging/math_tagger.dart';
export 'src/tagging/symbol_tagger.dart';
