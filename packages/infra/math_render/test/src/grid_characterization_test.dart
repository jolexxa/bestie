import 'package:characters/characters.dart';
import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

/// Characterization goldens for the *untrimmed* grid.
///
/// The rest of the suite asserts through [MathGrid.toText], which right-trims
/// every row. The markdown layer renders `grid.lines` verbatim and centres the
/// result on its width, so trailing padding is visible behaviour that trimmed
/// goldens cannot see. These lock it, along with the baseline and the
/// equal-width invariant the composition model rests on.
///
/// These record what the renderer does today, quirks included. A change here is
/// a change to what users see: update the golden deliberately, never to make a
/// refactor pass.
typedef _Golden = ({String tex, List<String> lines, int baseline});

const Map<String, _Golden> _goldens = {
  'fraction': (tex: r'\frac{a}{b}', lines: ['a', '─', 'b'], baseline: 1),
  'wide numerator pads symmetrically': (
    tex: r'\frac{a+b}{c}',
    lines: ['  a + b  ', '─────────', '    c    '],
    baseline: 1,
  ),
  'nested fraction': (
    tex: r'\frac{\frac{a}{b}}{c}',
    lines: ['a', '─', 'b', '─', 'c'],
    baseline: 3,
  ),
  'radical': (tex: r'\sqrt{x}', lines: [' ┌─', '╲│x'], baseline: 1),
  'radical over a fraction': (
    tex: r'\sqrt{\frac{a}{b}}',
    lines: [' ┌─', ' │a', ' │─', '╲│b'],
    baseline: 2,
  ),
  'radical over a nested fraction': (
    tex: r'\sqrt{\frac{\frac{a}{b}}{c}}',
    lines: [' ┌─', ' │a', ' │─', ' │b', ' │─', '╲│c'],
    baseline: 4,
  ),
  'boxed glyph': (
    tex: r'\boxed{x}',
    lines: ['┌───┐', '│   │', '│ x │', '│   │', '└───┘'],
    baseline: 2,
  ),
  'boxed fraction': (
    tex: r'\boxed{\frac{a}{b}}',
    lines: [
      '┌───┐',
      '│   │',
      '│ a │',
      '│ ─ │',
      '│ b │',
      '│   │',
      '└───┘',
    ],
    baseline: 3,
  ),
  'summation with limits': (
    tex: r'\sum_{i=0}^{n} \frac{i^2}{2}',
    lines: [
      '  n      ',
      ' ┌─    2 ',
      '  ╲   i  ',
      '  ╱   ───',
      ' └─    2 ',
      ' i=0     ',
    ],
    baseline: 3,
  ),
  'product with limits': (
    tex: r'\prod_{k=1}^{n} \frac{1}{k}',
    lines: [
      '  n    ',
      ' ┬─┬   ',
      ' │ │  1',
      ' │ │  ─',
      ' ┘ └  k',
      ' k=1   ',
    ],
    baseline: 3,
  ),
  'integral with limits': (
    tex: r'\int_0^\infty \frac{x^2}{e^x - 1}\, dx',
    lines: [
      '⌠  ∞      2       ',
      '⎮        x        ',
      '⎮    ────────── dx',
      '⎮       x         ',
      '⌡  0   e  − 1     ',
    ],
    baseline: 2,
  ),
  'stretchy parens with a superscript': (
    tex: r'\left(\frac{a}{b}\right)^2',
    lines: ['   2', '⎛a⎞ ', '⎜─⎟ ', '⎝b⎠ '],
    baseline: 2,
  ),
  'stretchy brackets': (
    tex: r'\left[\frac{\partial f}{\partial x}\right]',
    lines: ['⎡∂f⎤', '⎢──⎥', '⎣∂x⎦'],
    baseline: 1,
  ),
  'stretchy braces': (
    tex: r'\left\{ x : x^2 < \frac{1}{2} \right\}',
    lines: ['⎧     2   1⎫', '⎨x : x  < ─⎬', '⎩         2⎭'],
    baseline: 1,
  ),
  'matrix keeps a blank gutter row': (
    tex: r'\begin{matrix} a & b \\ c & d \end{matrix}',
    lines: ['a    b', '      ', 'c    d'],
    baseline: 1,
  ),
  'quadratic formula': (
    tex: r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
    lines: [
      '            ┌────────       ',
      '            │ 2             ',
      '      −b ± ╲│b  − 4ac       ',
      '────────────────────────────',
      '             2a             ',
    ],
    baseline: 3,
  ),
  'superscript and subscript': (
    tex: 'x_i^2',
    lines: [' 2', 'x ', ' i'],
    baseline: 1,
  ),
  'vector accents': (
    tex: r'\vec{F} \cdot d\vec{r}',
    lines: ['→    →', 'F ⋅ dr'],
    baseline: 1,
  ),
  'limit with an under-limit': (
    tex: r'\lim_{x \to 0} \frac{\sin x}{x}',
    lines: ['     sin x ', 'lim ───────', 'x→0    x   '],
    baseline: 1,
  ),
  'euler identity': (
    tex: r'e^{i\pi} + 1 = 0',
    lines: [' iπ        ', 'e   + 1 = 0'],
    baseline: 1,
  ),
  'polynomial terms': (
    tex: '3x^2y + 5xy^2 - xy',
    lines: ['  2       2     ', '3x y + 5xy  − xy'],
    baseline: 1,
  ),
  'unary minus before a fraction': (
    tex: r'-\frac{1}{2}',
    lines: ['  1', '− ─', '  2'],
    baseline: 1,
  ),
};

/// Expressions checked only for the structural invariants, widening coverage
/// past the goldens without pinning a shape for each one.
const _invariantCorpus = <String>[
  'x',
  'x^2',
  'x_i',
  r'4 \times 8 + 3^{\log(315)}',
  r'a - \frac{b}{c}',
  r'\oint_C \vec{F} \cdot d\vec{r}',
  r'\bigcup_{i=1}^{n} A_i',
  r'\bigcap_{i=1}^{n} A_i',
  r'\coprod_{i=1}^{n} X_i',
  r'\widetilde{abc}',
  r'\widehat{abc}',
  r'\overline{x + y}',
  r'\underline{x + y}',
  r'\begin{matrix} a & b \\ c & d \end{matrix}',
  r'\left| \frac{a}{b} \right|',
  r'\left\| \frac{a}{b} \right\|',
  r'\left\langle \frac{a}{b} \right\rangle',
  r'\frac{\frac{\frac{a}{b}}{c}}{d}',
  r'\sqrt{\sqrt{\sqrt{x}}}',
  r'\boxed{\sqrt{\frac{a}{b}}}',
  r'\sum_{i=0}^{n} \prod_{k=1}^{m} \frac{i}{k}',
  r'\lim_{x \to \infty} \frac{1}{x} = 0',
];

MathGrid _render(String tex) {
  final result = renderMath(tex, displayMode: true);
  expect(result, isA<MathRendered>(), reason: tex);
  return (result as MathRendered).grid;
}

void main() {
  group('untrimmed grid goldens', () {
    _goldens.forEach((name, golden) {
      test(name, () {
        final grid = _render(golden.tex);
        expect(grid.lines, golden.lines, reason: golden.tex);
        expect(grid.baseline, golden.baseline, reason: golden.tex);
      });
    });
  });

  group('grid invariants', () {
    final corpus = <String>{
      ..._goldens.values.map((g) => g.tex),
      ..._invariantCorpus,
    };

    for (final tex in corpus) {
      test('every row is the same grapheme width — $tex', () {
        final grid = _render(tex);
        final widths = grid.lines.map((line) => line.characters.length).toSet();
        expect(
          widths,
          hasLength(1),
          reason: 'rows of differing width in $tex:\n${grid.lines.join('\n')}',
        );
        expect(widths.single, grid.width, reason: tex);
      });

      test('baseline indexes a real row — $tex', () {
        final grid = _render(tex);
        expect(grid.height, grid.lines.length, reason: tex);
        expect(grid.baseline, greaterThanOrEqualTo(0), reason: tex);
        expect(grid.baseline, lessThan(grid.height), reason: tex);
        expect(grid.ascent + grid.descent + 1, grid.height, reason: tex);
      });
    }
  });
}
