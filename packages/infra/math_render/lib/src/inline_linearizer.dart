import 'package:characters/characters.dart';
import 'package:katex_dart/katex_dart.dart';

/// Walks a katex box tree and flattens it to a single line of unicode text,
/// suitable for inline math inside a run of prose.
///
/// Superscripts and subscripts collapse to unicode modifier characters (`x²`,
/// `aᵢ`) when every character maps, falling back to `^(…)` / `_(…)` otherwise.
/// Fractions linearize as `a/b`, roots as `√…`, and accents as combining marks
/// (`x̂`, `x̄`, `x⃗`). Anything without a single-row form contributes nothing.
class InlineLinearizer {
  /// Creates a linearizer.
  const InlineLinearizer();

  /// Kern widths (em) at or above this contribute a single space; smaller
  /// kerns collapse to nothing. Sits between the italic corrections katex emits
  /// for scripts and primes (`≤0.11em`) and the real spacing it puts around
  /// binary operators (`0.222em`) and thin spaces (`0.167em`).
  static const _spaceKernEm = 0.15;

  /// Linearizes [node] to a single trimmed line of text.
  String linearize(BoxNode node) => _node(node).trim();

  String _node(BoxNode node) => switch (node) {
    GlyphNode() => String.fromCharCode(node.codepoint),
    KernNode() => node.width >= _spaceKernEm ? ' ' : '',
    HBox() => _join(node.children),
    SpanNode() => _join(node.children),
    VList() => _vlist(node),
    _ => '',
  };

  String _join(List<BoxNode> children) {
    final buffer = StringBuffer();
    for (final child in children) {
      buffer.write(_node(child));
    }
    return buffer.toString();
  }

  String _vlist(VList node) {
    final positions = node.positions;
    if (positions.any((p) => p.box is RuleNode)) return _fraction(positions);
    if (positions.any((p) => _isSqrt(p.box))) return _root(positions);
    return _accent(positions) ?? _scripts(positions);
  }

  String _fraction(List<VListPosition> positions) {
    final rule = positions.firstWhere((p) => p.box is RuleNode);
    final numerator = StringBuffer();
    final denominator = StringBuffer();
    for (final p in positions) {
      if (identical(p, rule)) continue;
      (p.shift < rule.shift ? numerator : denominator).write(_node(p.box));
    }
    final top = numerator.toString().trim();
    final bottom = denominator.toString().trim();
    if (top.isEmpty) return bottom;
    if (bottom.isEmpty) return top;
    return '${_wrap(top)}/${_wrap(bottom)}';
  }

  String _root(List<VListPosition> positions) {
    final radicand = StringBuffer();
    for (final p in positions) {
      if (_isSqrt(p.box)) continue;
      radicand.write(_node(p.box));
    }
    return '√${_wrap(radicand.toString().trim())}';
  }

  String? _accent(List<VListPosition> positions) {
    final base = StringBuffer();
    final marks = StringBuffer();
    var found = false;
    for (final p in positions) {
      final mark = _accentMark(p.box);
      if (mark != null) {
        marks.write(mark);
        found = true;
      } else {
        base.write(_node(p.box));
      }
    }
    if (!found) return null;
    return '${base.toString().trim()}$marks';
  }

  String _scripts(List<VListPosition> positions) {
    final buffer = StringBuffer();
    for (final p in positions) {
      final content = _node(p.box).trim();
      buffer.write(p.shift < 0 ? _superscript(content) : _subscript(content));
    }
    return buffer.toString();
  }

  String _superscript(String content) =>
      _mapScript(content, _superscripts) ?? _fallback('^', content);

  String _subscript(String content) =>
      _mapScript(content, _subscripts) ?? _fallback('_', content);

  String? _mapScript(String content, Map<String, String> table) {
    final buffer = StringBuffer();
    for (final ch in content.characters) {
      final mapped = table[ch];
      if (mapped == null) return null;
      buffer.write(mapped);
    }
    return buffer.toString();
  }

  String _fallback(String marker, String content) =>
      content.characters.length == 1 ? '$marker$content' : '$marker($content)';

  String _wrap(String value) =>
      value.characters.length > 1 ? '($value)' : value;

  bool _isSqrt(BoxNode node) =>
      node is SvgPathNode && node.pathName.startsWith('sqrt');

  String? _accentMark(BoxNode node) {
    final lone = _lone(node);
    if (lone is GlyphNode) return _accentGlyphs[lone.codepoint];
    if (lone is SvgPathNode) return _accentSvgs[lone.pathName];
    return null;
  }

  /// Returns the single glyph/svg [node] reduces to once kerns and wrappers are
  /// peeled away, or null when it holds zero or more than one meaningful child
  /// (so ordinary bases and multi-glyph scripts never look like accent marks).
  BoxNode? _lone(BoxNode node) {
    if (node is GlyphNode || node is SvgPathNode) return node;
    if (node is HBox) return _loneOf(node.children);
    if (node is SpanNode) return _loneOf(node.children);
    if (node is VList) return _loneOf([for (final p in node.positions) p.box]);
    return null;
  }

  BoxNode? _loneOf(List<BoxNode> children) {
    BoxNode? found;
    for (final child in children) {
      if (child is KernNode) continue;
      final lone = _lone(child);
      if (lone == null || found != null) return null;
      found = lone;
    }
    return found;
  }

  static const _superscripts = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    '−': '⁻',
    '=': '⁼',
    '(': '⁽',
    ')': '⁾',
    'a': 'ᵃ',
    'b': 'ᵇ',
    'c': 'ᶜ',
    'd': 'ᵈ',
    'e': 'ᵉ',
    'f': 'ᶠ',
    'g': 'ᵍ',
    'h': 'ʰ',
    'i': 'ⁱ',
    'j': 'ʲ',
    'k': 'ᵏ',
    'l': 'ˡ',
    'm': 'ᵐ',
    'n': 'ⁿ',
    'o': 'ᵒ',
    'p': 'ᵖ',
    'r': 'ʳ',
    's': 'ˢ',
    't': 'ᵗ',
    'u': 'ᵘ',
    'v': 'ᵛ',
    'w': 'ʷ',
    'x': 'ˣ',
    'y': 'ʸ',
    'z': 'ᶻ',
    '′': '′',
    '″': '″',
    '‴': '‴',
  };

  static const _subscripts = <String, String>{
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    '−': '₋',
    '=': '₌',
    '(': '₍',
    ')': '₎',
    'a': 'ₐ',
    'e': 'ₑ',
    'h': 'ₕ',
    'i': 'ᵢ',
    'j': 'ⱼ',
    'k': 'ₖ',
    'l': 'ₗ',
    'm': 'ₘ',
    'n': 'ₙ',
    'o': 'ₒ',
    'p': 'ₚ',
    'r': 'ᵣ',
    's': 'ₛ',
    't': 'ₜ',
    'u': 'ᵤ',
    'v': 'ᵥ',
    'x': 'ₓ',
  };

  static const _accentGlyphs = <int, String>{
    0x5E: '̂', // ^ circumflex → combining hat
    0x2C9: '̅', // ˉ macron → combining overline (bar)
    0x7E: '̃', // ~ tilde
    0x2DC: '̃', // ˜ small tilde
    0x2D9: '̇', // ˙ dot above
    0xA8: '̈', // ¨ diaeresis
  };

  static const _accentSvgs = <String, String>{
    'vec': '⃗', // combining right arrow above
    'rightarrow': '⃗',
    'overrightarrow': '⃗',
  };
}
