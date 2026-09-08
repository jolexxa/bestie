import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

/// Golden shapes for the hand-drawn operators at a spread of heights, so every
/// even/odd vertex and radical slope stays pinned as the code evolves.
void main() {
  void expectShape(String tex, List<String> rows) {
    final result = renderMath(tex, displayMode: true);
    expect(
      (result as MathRendered).grid.toText(),
      rows.join('\n'),
      reason: tex,
    );
  }

  group('summation growth (corners, spine, detached beak)', () {
    test('three rows — the end-caps joined by a spine', () {
      expectShape(r'\sum \frac{a}{b}', ['⎲ a', '│ ─', '⎳ b']);
    });

    test('four rows (even) — corners over a blunt ╲╱ beak, no spine yet', () {
      expectShape(r'\sum \frac{a}{b^2}', [
        '┌─  a',
        ' ╲ ───',
        ' ╱  2',
        '└─ b',
      ]);
    });

    test('five rows (odd) — the beak tips with > , still no spine', () {
      expectShape(r'\sum \frac{\frac{a}{b}}{c}', [
        '┌── a',
        ' ╲  ─',
        '  > b',
        ' ╱  ─',
        '└── c',
      ]);
    });

    test('six rows (even) — spine appears with serif-capped bars', () {
      // The blunt even tip is a row taller, so the arm holds off and the extra
      // height becomes spine — the beak does not extend the way odd five does.
      // With the spine the bars overhang the tip and cap off with `┐`/`┘`.
      expectShape(r'\sum \frac{\frac{a}{b}}{c^2}', [
        '┌─┐  a',
        '│    ─',
        ' ╲   b',
        ' ╱  ───',
        '│    2',
        '└─┘ c',
      ]);
    });

    test('seven rows (odd) — spine both sides of a > -tipped beak', () {
      expectShape(r'\sum \frac{\frac{a}{b}}{\frac{c}{d}}', [
        '┌──┐ a',
        '│    ─',
        ' ╲   b',
        '  >  ─',
        ' ╱   c',
        '│    ─',
        '└──┘ d',
      ]);
    });

    test('eight rows (even) — the even beak finally extends to the cap', () {
      expectShape(r'\sum \frac{\frac{a}{b}}{\frac{c}{d^2}}', [
        '┌──┐  a',
        '│     ─',
        ' ╲    b',
        '  ╲  ───',
        '  ╱   c',
        ' ╱   ───',
        '│     2',
        '└──┘ d',
      ]);
    });

    test('nine rows — extra height is all spine; width stays capped', () {
      // Past the arm cap the beak is fixed and every added row is a straight
      // `│` spine, so the sum tapers to the point instead of puffing sideways.
      expectShape(r'\sum \frac{\frac{a}{b^2}}{\frac{c}{d^2}}', [
        '┌──┐  a',
        '│    ───',
        '│     2',
        ' ╲   b',
        '  >  ───',
        ' ╱    c',
        '│    ───',
        '│     2',
        '└──┘ d',
      ]);
    });
  });

  group('radical (vertical stem, hook, corner to the vinculum)', () {
    test('one row — hook and stem under the bar', () {
      expectShape(r'\sqrt{x}', [' ┌─', '╲│x']);
    });

    test('a wider radicand keeps the vinculum over it', () {
      expectShape(r'\sqrt{x+y}', [' ┌─────', '╲│x + y']);
    });

    test('a three-row radicand keeps the stem straight', () {
      expectShape(r'\sqrt{\frac{a}{b}}', [' ┌─', ' │a', ' │─', '╲│b']);
    });

    test('a five-row radicand keeps the stem straight', () {
      expectShape(r'\sqrt{\frac{\frac{a}{b}}{c}}', [
        ' ┌─',
        ' │a',
        ' │─',
        ' │b',
        ' │─',
        '╲│c',
      ]);
    });
  });

  group('boxed frames hug their content symmetrically', () {
    test('single-row content gets one blank row on each side', () {
      expectShape(r'\boxed{x}', ['┌───┐', '│   │', '│ x │', '│   │', '└───┘']);
    });

    test('taller content is centred, not top-heavy', () {
      expectShape(r'\boxed{\frac{a}{b}}', [
        '┌───┐',
        '│   │',
        '│ a │',
        '│ ─ │',
        '│ b │',
        '│   │',
        '└───┘',
      ]);
    });
  });

  group('not-negations collapse to precomposed glyphs', () {
    test('renders a not-equal as ≠ rather than tofu', () {
      expectShape(r'a \neq 0', ['a ≠ 0']);
    });
  });
}
