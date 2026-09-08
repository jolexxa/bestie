import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  group('RasterMetrics', () {
    const metrics = RasterMetrics();

    test('exposes the default densities', () {
      expect(metrics.rowsPerEm, 2.0);
      expect(metrics.kernColsPerEm, 4.5);
      expect(metrics.ruleColsPerEm, 2.0);
    });

    group('rowForShift', () {
      test('rounds a downward shift to positive rows', () {
        expect(metrics.rowForShift(0.345), 1);
      });

      test('rounds an upward shift to negative rows', () {
        expect(metrics.rowForShift(-0.363), -1);
      });

      test('keeps the baseline at row zero', () {
        expect(metrics.rowForShift(0), 0);
      });
    });

    group('colsForKern', () {
      test('rounds a standard math space to one column', () {
        expect(metrics.colsForKern(0.2222), 1);
      });

      test('collapses a hair kern to zero', () {
        expect(metrics.colsForKern(0.0348), 0);
      });

      test('clamps a negative kern to zero', () {
        expect(metrics.colsForKern(-0.5), 0);
      });
    });

    group('colsForRule', () {
      test('rounds a rule width to columns', () {
        expect(metrics.colsForRule(1.5), 3);
      });

      test('collapses a zero-width strut to nothing', () {
        expect(metrics.colsForRule(0), 0);
      });

      test('clamps a negative rule to zero', () {
        expect(metrics.colsForRule(-1), 0);
      });
    });

    group('rowsForExtent', () {
      test('rounds a vertical extent to rows', () {
        expect(metrics.rowsForExtent(1.36), 3);
      });

      test('clamps a negative extent to zero', () {
        expect(metrics.rowsForExtent(-1), 0);
      });
    });

    test('honours a custom density', () {
      const dense = RasterMetrics(rowsPerEm: 4);
      expect(dense.rowForShift(0.363), 1);
    });
  });
}
