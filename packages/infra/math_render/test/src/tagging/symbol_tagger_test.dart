import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

/// Renders [tex] with identifiers slotted and returns the slot sketch split
/// into rows: one character per cell, a symbol's slot modulo ten, a space for
/// anything unslotted.
List<String> sketch(String tex) {
  final result = renderMath(tex, displayMode: true, tagger: tagSymbols);
  expect(result, isA<MathRendered>(), reason: tex);
  return (result as MathRendered).grid.slotSketch().split('\n');
}

void main() {
  group('symbol identity', () {
    test('gives every occurrence of a variable one slot', () {
      expect(sketch('x + x + x'), ['0   0   0']);
    });

    test('gives distinct variables distinct slots', () {
      expect(sketch('a + b + c'), ['0   1   2']);
    });

    test('numbers the slots by first appearance, not by codepoint', () {
      // Ordering by appearance keeps a short expression at the front of the
      // palette; hashing would scatter and make `x` a different colour
      // depending on what else the equation happens to contain.
      expect(sketch('z + a'), ['0   1']);
    });

    test('tracks a symbol across a fraction', () {
      expect(sketch(r'\frac{a}{a}'), ['0', ' ', '0']);
    });

    test('numbers a fraction top to bottom, as it is read', () {
      // katex stacks vertical lists bottom-up; left alone, the denominator
      // would claim the earlier slot.
      expect(sketch(r'\frac{a}{b}'), ['0', ' ', '1']);
    });

    test('tracks a symbol across a relation', () {
      expect(sketch('y = m x + y'), ['0   12   0']);
    });

    test('matches an index in a limit with the same index in a script', () {
      // The `i` bound by the sum is the `i` selecting the term — both slot 1.
      expect(sketch(r'\sum_{i=0}^{n} x_i'), [
        '  0     ',
        '        ',
        '      2 ',
        ' 1     1',
      ]);
    });
  });

  group('what is not an identifier', () {
    test('leaves numerals unpainted', () {
      // Two occurrences of a literal are not "the same thing" the way two
      // occurrences of a variable are, so matching them would be noise.
      expect(sketch('2 + 2'), ['     ']);
    });

    test('leaves a coefficient plain and paints only its variable', () {
      expect(sketch('3x + 3y'), [' 0    1']);
    });

    test('leaves an upright label alone', () {
      // `\text{net}` is a name, not three variables multiplied together.
      expect(sketch(r'F_{\text{net}}'), ['0    ', '     ']);
    });

    test('leaves delimiters unslotted', () {
      expect(sketch(r'\left(x\right)'), [' 0 ']);
    });

    test('leaves a fraction bar unslotted', () {
      // Structure the renderer drew reads as body text; only symbols take a
      // colour, which is the whole of what this scheme claims.
      expect(sketch(r'\frac{a}{b}'), ['0', ' ', '1']);
    });
  });

  group('modifiers that select an instance share identity', () {
    test('matches a subscripted base with its bare form', () {
      // `x_a` and `x_b` are components of one indexed family — that is what
      // index notation is for. The differing index is already visible.
      expect(sketch('x_a + x_b')[0], '0    0 ');
    });

    test('gives distinct subscripts their own slots', () {
      // A letter index is a variable in its own right, so it gets a colour of
      // its own — which incidentally shows free against bound indices.
      expect(sketch('x_a + x_b')[1], ' 1    2');
    });

    test('matches a superscripted base with its bare form', () {
      // An exponent is an operator applied to `x`, not a different `x`.
      expect(sketch('x^2 + x').last, '0    0');
    });
  });

  group('modifiers that change the object split identity', () {
    // The rule: colour must never assert an equality that is false. A missing
    // link costs the reader a glance at a mark that is on screen anyway; a
    // false link is undetectable, because the scheme's whole contract is
    // "same colour means same symbol".

    test('splits a hat from its base', () {
      // An estimator is not the parameter it estimates: `ŷ ≠ y` is exactly the
      // confusion statistics teaching exists to prevent.
      expect(sketch(r'\hat{x} + x').last, '0   1');
    });

    test('splits a bar from its base', () {
      // A sample mean is one number; the datum is not.
      expect(sketch(r'\bar{x} - x').last, '0   1');
    });

    test('splits a vector arrow from its base', () {
      // The convention's whole purpose: `v = |v⃗|`, a scalar magnitude.
      expect(sketch(r'\vec{v} \cdot v').last, '0   1');
    });

    test('splits a dot from its base', () {
      // A rate is a different quantity with different units.
      expect(sketch(r'\dot{x} + x').last, '0   1');
    });

    test('gives each accent over one letter its own slot', () {
      expect(sketch(r'\hat{x} + \bar{x} + x').last, '0   1   2');
    });

    test('splits a bold vector from its plain magnitude', () {
      // `\boldsymbol` is set in a bold *italic* face, so a font-blind identity
      // would merge a vector with its own magnitude.
      expect(sketch(r'\boldsymbol{v} + v'), ['0   1']);
    });

    test('splits a calligraphic letter from its plain form', () {
      // `G` a group and `𝒢` a generating set are two objects sharing a letter.
      expect(sketch(r'\mathcal{G} + G'), ['0   1']);
    });
  });

  group('against an untagged render', () {
    test('renders exactly the same picture either way', () {
      const tex = r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}';
      final plain = renderMath(tex, displayMode: true) as MathRendered;
      final tagged =
          renderMath(tex, displayMode: true, tagger: tagSymbols)
              as MathRendered;
      expect(tagged.grid.lines, plain.grid.lines);
      expect(tagged.grid.baseline, plain.grid.baseline);
    });
  });
}
