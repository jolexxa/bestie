import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/src/tagging/box_atoms.dart';
import 'package:math_render/src/tagging/math_tagger.dart';

/// Gives each identifier a slot of its own, so every occurrence of the same
/// variable shares a colour.
///
/// Every `x` reads the same wherever it appears, including inside a limit, an
/// exponent, or on the far side of a relation. That automates what physics
/// texts do by hand when they colour a term to follow it across a derivation,
/// and it is the one place matching colour genuinely asserts something — these
/// glyphs really are the same symbol.
///
/// Everything that is not an identifier — numerals, operators, delimiters,
/// fraction bars — is left unslotted and renders in the surrounding style.
/// Colouring every `2` alike would be noise: two occurrences of a literal are
/// not the same *thing* the way two occurrences of a variable are.
///
/// Slots are assigned in order of first appearance rather than hashed, so a
/// short expression uses the front of the palette and reads consistently; a
/// hash would scatter across the cycle and pick a different colour for `x`
/// depending on what else happens to be in the equation.
///
/// ## What counts as the same symbol
///
/// The rule: a decoration splits identity when it changes the *kind* of thing
/// denoted, and shares it when it selects among instances of one kind.
///
/// So the letter alone is not enough. `\hat{x}` is an estimator where `x` is
/// the parameter it estimates; `\bar{x}` is one number where `x` is a datum;
/// `\vec{v}` is a vector and `v` is its magnitude; `\mathcal{G}`, `\mathfrak{g}`
/// and `G` are three different objects sharing a letter. Merging any of those
/// would have colour assert an equality that is false — and unlike a missing
/// link, a false link is one the reader cannot detect, because the whole
/// contract of this scheme is "same colour means same symbol". The accent is
/// on screen regardless, so splitting costs nothing a reader was relying on.
///
/// Subscripts and superscripts go the other way and stay *out* of the key:
/// `x_1`, `x_i` and `x_a` are components of one indexed family, which is the
/// entire point of index notation. They are still walked, so an index that is
/// itself a variable gets a colour of its own — which incidentally shows free
/// against bound indices under a summation.
MathTagging tagSymbols(BoxNode root) => (_SymbolWalk()..visit(root)).tagging;

/// Everything that makes two glyphs the same symbol.
typedef _Identity = ({int codepoint, String font, String? accent});

class _SymbolWalk {
  final MathTagging tagging = newTagging();

  /// Identity → slot, in order of first appearance. This is the table that
  /// makes repeated occurrences match.
  final Map<_Identity, int> _slots = {};

  /// The mark covering the group being walked, if any.
  String? _accent;

  void visit(BoxNode node) {
    if (node is GlyphNode) {
      _tagGlyph(node);
      return;
    }
    if (isAccented(node)) {
      _visitAccented(node);
      return;
    }
    childrenOf(node).forEach(visit);
  }

  void _tagGlyph(GlyphNode glyph) {
    if (!isIdentifier(glyph)) return;
    final identity = (
      codepoint: glyph.codepoint,
      font: fontVariantOf(glyph),
      accent: _accent,
    );
    tagging[glyph] = _slots.putIfAbsent(identity, () => _slots.length);
  }

  /// Walks an accented group with its mark folded into the identity of every
  /// symbol inside it, so `\hat{x}` never lands on `x`.
  void _visitAccented(BoxNode node) {
    final outer = _accent;
    _accent = accentMarkOf(node) ?? outer;
    childrenOf(node).forEach(visit);
    _accent = outer;
  }
}
