import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  MathGrid render(String tex, {bool display = true}) {
    final result = renderMath(tex, displayMode: display);
    return (result as MathRendered).grid;
  }

  group('delimiters', () {
    test('shrink to single glyphs around one-row content', () {
      expect(render(r'\left(x\right)').toText(), '(x)');
    });

    test('use a two-piece bracket for two-row content', () {
      expect(render(r'\left(x^2\right)').toText(), '⎛ 2⎞\n⎝x ⎠');
    });

    test('grow with top/extender/bottom pieces for taller content', () {
      expect(render(r'\left(\frac{a}{b}\right)').toText(), '⎛a⎞\n⎜─⎟\n⎝b⎠');
    });

    test('draw the middle piece for braces', () {
      expect(render(r'\left\{\frac{a}{b}\right\}').toText(), '⎧a⎫\n⎨─⎬\n⎩b⎭');
    });

    test('render a vertical bar from its stacked-geometry path', () {
      expect(render(r'\left|\frac{a}{b}\right|').toText(), '│a│\n│─│\n│b│');
    });

    test('render a double bar from its stacked-geometry path', () {
      expect(render(r'\left\|\frac{x}{y}\right\|').toText(), '║x║\n║─║\n║y║');
    });

    test('match a paren too tall for a font glyph to its content', () {
      expect(
        render(r'\left(\begin{matrix}a\\b\end{matrix}\right)').toText(),
        '⎛a⎞\n⎜ ⎟\n⎝b⎠',
      );
    });
  });

  group('big operators', () {
    test('a bare display sum is the two-row glyph', () {
      expect(render(r'\sum x').toText(), '⎲\n⎳ x');
    });

    test('an integral grows to wrap a tall integrand', () {
      expect(render(r'\int \frac{a}{b} dx').toText(), '⌠ a\n⎮ ─dx\n⌡ b');
    });

    test('a product grows and keeps its limits tight', () {
      expect(
        render(r'\prod_{k=1}^{n} \frac{a^2}{b}').toText(),
        '  n\n ┬─┬   2\n │ │  a\n │ │  ───\n ┘ └   b\n k=1',
      );
    });

    test('grows over a substack limit and keeps its rows tight', () {
      expect(
        render(r'\prod_{\substack{p \\ q}} \frac{a}{b}').toText(),
        '┬─┬\n│ │ a\n│ │ ─\n┘ └ b\n p\n q',
      );
    });

    test('stacks over and under limits around the operator', () {
      expect(render(r'\sum_{i=0}^{n} i').toText(), '  n\n  ⎲\n  ⎳   i\n i=0');
    });

    test('places an upper-only limit above the operator', () {
      expect(render(r'\sum^{n} x').toText(), '  n\n  ⎲\n  ⎳   x');
    });

    test('places a lower-only limit below the operator', () {
      expect(render(r'\sum_{n} x').toText(), '  ⎲\n  ⎳   x\n  n');
    });
  });

  group('accents', () {
    test('draws a vector arrow above its base', () {
      expect(render(r'\vec{F}').toText(), '→\nF');
    });

    test('centres a mark on its letter whatever the letter slopes like', () {
      // katex offsets an accent by a sub-cell skew to sit over the optical
      // centre of a sloped glyph — 0.221em over an `H`, 0.085em over a `p`.
      // Rounded to columns that is a whole cell for one and none for the
      // other, which used to leave `\hat{H}` wearing its caret over the blank
      // beside it.
      expect(render(r'\hat{H}').toText(), '^\nH');
      expect(render(r'\hat{p}').toText(), '^\np');
      expect(render(r'\bar{x}').toText(), 'ˉ\nx');
      expect(render(r'\dot{x}').toText(), '˙\nx');
    });

    test('keeps every mark over its own letter in a row of them', () {
      expect(render(r'\hat{q} + \hat{p}').toText(), '^   ^\nq + p');
    });

    test('lifts a zero-shift hat off its base instead of overwriting it', () {
      expect(render(r'\hat{x}').toText(), '^\nx');
    });

    test('stretches a wide tilde across its base', () {
      expect(render(r'\widetilde{abc}').toText(), '~~~\nabc');
    });

    test('draws an overline as a rule above its base', () {
      expect(render(r'\overline{AB}').toText(), '───\n\nAB');
    });

    test('draws an underline below its base', () {
      expect(render(r'\underline{y}').toText(), 'y\n─');
    });

    group('svg accent marks (direct)', () {
      const rasterizer = BoxRasterizer();
      SvgPathNode path(String name, double width) => SvgPathNode(
        pathName: name,
        pathData: 'M0 0',
        viewBoxWidth: 1,
        viewBoxHeight: 1,
        width: width,
        height: 0.5,
      );

      test('vec resolves to a single arrow', () {
        expect(rasterizer.rasterize(path('vec', 0.5)).toText(), '→');
      });

      test('a wide tilde stretches to its width', () {
        expect(rasterizer.rasterize(path('tilde2', 1.5)).toText(), '~~~');
      });

      test('a wide hat stretches to its width', () {
        expect(rasterizer.rasterize(path('widehat3', 1)).toText(), '^^');
      });

      test('an over-rightarrow resolves to an arrow', () {
        expect(rasterizer.rasterize(path('overrightarrow', 0.5)).toText(), '→');
      });

      test('an over-leftarrow resolves to an arrow', () {
        expect(rasterizer.rasterize(path('overleftarrow', 0.5)).toText(), '←');
      });

      test('an unknown (non-accent) path leaves an empty slot', () {
        expect(rasterizer.rasterize(path('sqrtMain', 1)).width, 0);
      });
    });
  });

  group('roots and matrices', () {
    test('wraps a fraction radicand with a vertical-stem radical', () {
      expect(render(r'\sqrt{\frac{a}{b}}').toText(), ' ┌─\n │a\n │─\n╲│b');
    });

    test('renders a matrix without stray strut lines', () {
      expect(
        render(r'\begin{matrix} a & b \\ c & d \end{matrix}').toText(),
        'a    b\n\nc    d',
      );
    });

    test('an over/under set is not mistaken for an operator', () {
      expect(render(r'\overset{a}{b}').toText(), 'a\n\nb');
    });
  });
}
