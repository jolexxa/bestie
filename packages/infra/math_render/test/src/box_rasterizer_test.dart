import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  const rasterizer = BoxRasterizer();

  group('BoxRasterizer node handling', () {
    test('renders a rule as a horizontal line', () {
      final grid = rasterizer.rasterize(
        const RuleNode(width: 0.5, height: 0.02),
      );
      expect(grid.toText(), '─');
    });

    test('renders a sized kern as spaces', () {
      final grid = rasterizer.rasterize(const KernNode(0.5));
      expect(grid.width, 2);
      expect(grid.toText(), '');
    });

    test('collapses a hair kern to the empty grid', () {
      final grid = rasterizer.rasterize(const KernNode(0.02));
      expect(grid.width, 0);
    });

    test('frames a boxed enclose node', () {
      final grid = rasterizer.rasterize(
        const EncloseNode(
          child: RuleNode(width: 0.5, height: 0.02),
          notations: [EncloseNotation.box],
        ),
      );
      expect(grid.lines, ['┌─┐', '│─│', '└─┘']);
      expect(grid.baseline, 1);
    });

    test('passes a non-box enclose through unchanged', () {
      const child = RuleNode(width: 0.5, height: 0.02);
      final grid = rasterizer.rasterize(
        const EncloseNode(
          child: child,
          notations: [EncloseNotation.horizontalstrike],
        ),
      );
      expect(grid.toText(), rasterizer.rasterize(child).toText());
    });

    test('renders an image as its alt text', () {
      final grid = rasterizer.rasterize(
        const ImageNode(src: 'cow.png', alt: 'cow', width: 1, height: 1),
      );
      expect(grid.toText(), '[cow]');
    });

    test('renders an image without alt text as a placeholder', () {
      final grid = rasterizer.rasterize(
        const ImageNode(src: 'cow.png', alt: '', width: 1, height: 1),
      );
      expect(grid.toText(), '[img]');
    });

    test('renders an svg path node as an empty slot', () {
      final grid = rasterizer.rasterize(
        const SvgPathNode(
          pathName: 'sqrtMain',
          pathData: 'M0 0',
          viewBoxWidth: 10,
          viewBoxHeight: 10,
          width: 1,
          height: 1,
        ),
      );
      expect(grid.width, 0);
    });

    test('renders an empty vertical list as the empty grid', () {
      final grid = rasterizer.rasterize(
        VList(positionType: VListPositionType.top, children: const []),
      );
      expect(grid.width, 0);
    });
  });

  group('BoxRasterizer end-to-end goldens', () {
    MathGrid render(String tex, {RasterMetrics? metrics}) {
      final result = renderMath(tex, metrics: metrics ?? const RasterMetrics());
      return (result as MathRendered).grid;
    }

    test('lifts a superscript above the baseline', () {
      expect(render('x^2').toText(), ' 2\nx');
    });

    test('stacks a fraction over a bar', () {
      expect(render(r'\frac{a}{b}').toText(), 'a\n─\nb');
    });

    test('centres a wide numerator over its bar', () {
      expect(render(r'\frac{a+b}{c}').toText(), ' a+b\n─────\n  c');
    });

    test('places a binary operator on the fraction axis', () {
      expect(
        render(r'\frac{a}{b} + 3^{\log(315)}').toText(),
        'a    log(315)\n─ + 3\nb',
      );
    });

    test('keeps a unary minus off a fraction bar so it stays legible', () {
      // Without the gap the minus (−) and the bar (─) fuse into one long
      // dash. TeX sets mathspace there too, so a single cell is faithful.
      expect(render(r'-\frac{1}{2}').toText(), '  1\n− ─\n  2');
    });

    test('leaves a binary minus before a fraction as katex spaced it', () {
      // katex already sets a space around a binary `-`; we must not add a
      // second one.
      expect(render(r'a - \frac{b}{c}').toText(), '    b\na − ─\n    c');
    });

    test('stacks a subscript and superscript around the baseline', () {
      expect(render('x_i^2').toText(), ' 2\nx\n i');
    });

    test('drops a bare subscript below the baseline, not onto it', () {
      expect(render('x_i').toText(), 'x\n i');
    });

    test('resolves a named operator to its unicode glyph', () {
      expect(render(r'4 \times 8').toText(), '4 × 8');
    });

    test('honours injected metrics', () {
      final dense = render('x^2', metrics: const RasterMetrics(rowsPerEm: 6));
      expect(dense.height, greaterThan(render('x^2').height));
    });
  });
}
