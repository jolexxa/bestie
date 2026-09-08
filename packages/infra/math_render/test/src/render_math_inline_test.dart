import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  String lin(String tex) {
    final result = renderMathInline(tex);
    return (result as MathInlineRendered).line;
  }

  group('renderMathInline scripts', () {
    test('maps a digit superscript to unicode', () {
      expect(lin('x^2'), 'x²');
    });

    test('maps a subscript index to unicode', () {
      expect(lin('a_i'), 'aᵢ');
    });

    test('stacks a subscript and superscript on one row', () {
      expect(lin('x_i^2'), 'xᵢ²');
    });

    test('maps a multi-character superscript when every char maps', () {
      expect(lin('x^{n+1}'), 'xⁿ⁺¹');
    });

    test('maps a run of superscript letters', () {
      expect(lin('x^{ab}'), 'xᵃᵇ');
    });

    test('falls back to _c for a single unmapped subscript', () {
      expect(lin('x_q'), 'x_q');
    });

    test('falls back to ^c for a single unmapped superscript', () {
      expect(lin(r'x^\pi'), 'x^π');
    });

    test('falls back to ^(…) for a multi-char unmapped superscript', () {
      expect(lin(r'e^{i\pi}'), 'e^(iπ)');
    });

    test('falls back to ^(…) for a nested superscript', () {
      expect(lin('x^{y^2}'), 'x^(y²)');
    });

    test('attaches primes directly instead of as a caret script', () {
      expect(lin("f'"), 'f′');
      expect(lin("f''"), 'f′′');
    });

    test('keeps a subscripted molecule on one row', () {
      expect(lin('CO_2'), 'CO₂');
    });
  });

  group('renderMathInline fractions and roots', () {
    test('slashes a simple fraction', () {
      expect(lin(r'\frac{a}{b}'), 'a/b');
    });

    test('parenthesizes a compound numerator', () {
      expect(lin(r'\frac{a+b}{c}'), '(a+b)/c');
    });

    test('nests fractions with parentheses', () {
      expect(lin(r'\frac{\frac{a}{b}}{c}'), '(a/b)/c');
    });

    test('prefixes a root with the radical sign', () {
      expect(lin(r'\sqrt{x}'), '√x');
    });

    test('parenthesizes a compound radicand', () {
      expect(lin(r'\sqrt{b^2 - 4ac}'), '√(b² − 4ac)');
    });

    test('renders an nth root index as a leading superscript', () {
      expect(lin(r'\sqrt[3]{x}'), '³√x');
    });

    test('drops the bar of an overline to its content', () {
      expect(lin(r'\overline{x}'), 'x');
    });

    test('drops the bar of an underline to its content', () {
      expect(lin(r'\underline{x}'), 'x');
    });
  });

  group('renderMathInline accents', () {
    test('renders a hat as a combining mark', () {
      expect(lin(r'\hat{x}'), 'x̂');
    });

    test('renders a bar as a combining overline', () {
      expect(lin(r'\bar{x}'), 'x̅');
    });

    test('renders a tilde as a combining mark', () {
      expect(lin(r'\tilde{x}'), 'x̃');
    });

    test('renders a vector as a combining arrow', () {
      expect(lin(r'\vec{v}'), 'v⃗');
    });
  });

  group('renderMathInline spacing and glyphs', () {
    test('spaces binary operators', () {
      expect(lin(r'4 \times 8 + 3'), '4 × 8 + 3');
    });

    test('passes greek letters through as unicode', () {
      expect(lin(r'\alpha \times \beta'), 'α × β');
    });

    test('trims to nothing for a lone rule node', () {
      expect(const InlineLinearizer().linearize(_rule), '');
    });

    test('collapses a not-equal negation to a precomposed glyph', () {
      expect(lin(r'a \neq 0'), 'a ≠ 0');
    });

    test('leaves a plain equals untouched', () {
      expect(lin('a = b'), 'a = b');
    });
  });

  group('renderMathInline failure', () {
    test('reports a parse failure with katex diagnostic', () {
      final result = renderMathInline(r'\frac{');
      expect(result, isA<MathInlineParseFailed>());
      expect((result as MathInlineParseFailed).message, isNotEmpty);
    });
  });
}

const _rule = RuleNode(width: 0.5, height: 0.02);
