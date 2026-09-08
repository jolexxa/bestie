import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/src/glyph_fixups.dart';
import 'package:math_render/src/inline_linearizer.dart';
import 'package:math_render/src/math_inline_result.dart';

/// Parses [tex] as LaTeX math and linearizes it to a single line of unicode
/// text for inline use inside prose.
///
/// Superscripts/subscripts collapse to unicode modifiers where possible and
/// fall back to `^(…)` / `_(…)`; fractions become `a/b`, roots `√…`, and accents
/// combining marks. Returns [MathInlineRendered] on success or
/// [MathInlineParseFailed] when katex rejects the source, so callers can fall
/// back to the raw text without a try/catch.
MathInlineResult renderMathInline(String tex) {
  final BoxNode box;
  try {
    box = renderToBox(tex, options: const KatexOptions());
  } on ParseError catch (error) {
    return MathInlineParseFailed(error.message);
  }
  return MathInlineRendered(
    fixInlineGlyphs(const InlineLinearizer().linearize(box)),
  );
}
