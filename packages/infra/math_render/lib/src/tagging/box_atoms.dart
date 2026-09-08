import 'package:katex_dart/katex_dart.dart';

/// Reading the bits of katex's box tree a tagger needs to classify a glyph.
///
/// The boxes [node] contains, in reading order.
///
/// Vertical lists are returned top to bottom. katex stacks them the other way,
/// and a tagger that numbers slots by first appearance would otherwise hand a
/// fraction's denominator the earlier slot.
List<BoxNode> childrenOf(BoxNode node) => switch (node) {
  HBox(:final children) => children,
  SpanNode(:final children) => children,
  EncloseNode(:final child) => [child],
  VList() => [
    for (final position in [
      ...node.positions,
    ]..sort((a, b) => a.shift.compareTo(b.shift)))
      position.box,
  ],
  _ => const [],
};

/// Letter-only faces that carry variables without being italic.
const _variantIdentifierFonts = {
  'Caligraphic-Regular',
  'Fraktur-Regular',
  'Script-Regular',
};

/// Whether [glyph] is an identifier — a variable rather than a numeral,
/// operator, or delimiter.
///
/// ISO 80000-2 sets variables in italic and everything with a fixed meaning
/// upright, and katex follows it: this separates `x` from `2`, `+`, `\sin`,
/// `\mathrm{d}` and `\text{net}` without a codepoint table, and covers Greek
/// (`α`, `β`) for free. The named faces above are the letter-only exceptions —
/// `\mathcal`, `\mathfrak` — which are upright but still name objects.
bool isIdentifier(GlyphNode glyph) =>
    glyph.font.fontName.contains('Italic') ||
    _variantIdentifierFonts.contains(glyph.font.fontName);

/// How a glyph is *set*, as far as identity goes.
///
/// Part of a symbol's identity, not decoration: `\boldsymbol{v}` and `v` are a
/// vector and its magnitude, and `\mathcal{G}`, `\mathfrak{g}` and `G` are
/// three different objects that happen to share a letter. Unicode's UTR #25
/// makes the same point — the math alphanumeric blocks exist precisely because
/// folding these together "loses the semantic distinctions for which these
/// characters were encoded".
String fontVariantOf(GlyphNode glyph) => glyph.font.fontName;

/// Whether [node] is katex's wrapper for an accented group.
///
/// Not one of katex's atom classes — its accent builders tag the span with a
/// bare `accent` marker instead.
bool isAccented(BoxNode node) =>
    node is SpanNode &&
    (node.classes.contains('accent') || node.classes.contains('accentunder'));

/// A stable discriminator for the mark sitting over an accented group, or null
/// when none is found.
///
/// The mark is whatever leaf in the group is not itself an identifier — a
/// `widehat` path, a combining bar, a `vec` arrow.
String? accentMarkOf(BoxNode node) {
  if (node is SvgPathNode) return node.pathName;
  if (node is GlyphNode) {
    return isIdentifier(node) ? null : '${node.codepoint}';
  }
  for (final child in childrenOf(node)) {
    final mark = accentMarkOf(child);
    if (mark != null) return mark;
  }
  return null;
}
