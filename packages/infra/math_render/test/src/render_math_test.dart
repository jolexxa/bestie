import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  group('renderMath', () {
    test('returns a rendered grid for valid math', () {
      final result = renderMath('x^2');
      expect(result, isA<MathRendered>());
      expect((result as MathRendered).grid.toText(), ' 2\nx');
    });

    test('reports a parse failure for an undefined command', () {
      final result = renderMath(r'\nonexistentcmd x');
      expect(result, isA<MathParseFailed>());
      expect((result as MathParseFailed).message, contains('Undefined'));
    });

    test('threads injected metrics through to layout', () {
      final result = renderMath(
        'x^2',
        metrics: const RasterMetrics(rowsPerEm: 6),
      );
      expect((result as MathRendered).grid.height, 3);
    });
  });

  group('MathRenderResult', () {
    test('MathRendered carries its grid', () {
      final grid = MathGrid.line('a');
      expect(MathRendered(grid).grid, same(grid));
    });

    test('MathParseFailed carries its message', () {
      expect(const MathParseFailed('boom').message, 'boom');
    });
  });
}
