import 'package:meta/meta.dart';

/// The outcome of linearizing a LaTeX math string to a single line of text.
///
/// Mirrors `MathRenderResult` for the inline path: parsing can fail on
/// malformed input, so linearizing yields a sealed result rather than throwing
/// — callers (e.g. a markdown visitor) can fall back to the raw source without
/// a try/catch.
sealed class MathInlineResult {
  const MathInlineResult();
}

/// The math linearized successfully to a single [line] of unicode text.
@immutable
class MathInlineRendered extends MathInlineResult {
  /// Wraps the linearized [line].
  const MathInlineRendered(this.line);

  /// The single-row unicode rendering.
  final String line;
}

/// The math could not be parsed; [message] is katex's parse diagnostic.
@immutable
class MathInlineParseFailed extends MathInlineResult {
  /// Records the parse failure [message].
  const MathInlineParseFailed(this.message);

  /// The katex parse error message.
  final String message;
}
