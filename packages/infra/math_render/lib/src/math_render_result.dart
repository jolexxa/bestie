import 'package:math_render/src/math_grid.dart';
import 'package:meta/meta.dart';

/// The outcome of rendering a LaTeX math string to a terminal grid.
///
/// Parsing can fail on malformed input, so rendering yields a sealed result
/// rather than throwing — callers (e.g. a markdown visitor) can fall back to
/// showing the raw source without a try/catch.
sealed class MathRenderResult {
  const MathRenderResult();
}

/// The math parsed and laid out successfully.
@immutable
class MathRendered extends MathRenderResult {
  /// Wraps the successfully laid-out [grid].
  const MathRendered(this.grid);

  /// The laid-out terminal grid.
  final MathGrid grid;
}

/// The math could not be parsed; [message] is katex's parse diagnostic.
@immutable
class MathParseFailed extends MathRenderResult {
  /// Records the parse failure [message].
  const MathParseFailed(this.message);

  /// The katex parse error message.
  final String message;
}
