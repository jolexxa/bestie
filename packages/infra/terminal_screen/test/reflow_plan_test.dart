// The arithmetic pre-pass: how many rows a logical line will occupy at
// a new width, and how much of each source row is content. Every wrap
// decision the writer later makes has to agree with what is counted
// here, so this is where the off-by-one risk concentrates.

import 'dart:math';

import 'package:terminal_screen/src/reflow.dart';
import 'package:test/test.dart';

import 'reflow_fakes.dart';

typedef _Source = FakeReflowSource;

const List<bool> Function(int) _run = continuationRun;

void main() {
  group('wrapsToNext', () {
    test('reads the wrap bit of the row below', () {
      final source = _Source(['ab', 'cd'], wrapped: [false, true]);

      expect(wrapsToNext(source, 0), isTrue);
    });

    test('is false when the row below starts its own line', () {
      final source = _Source(['ab', 'cd']);

      expect(wrapsToNext(source, 0), isFalse);
    });

    test('is false for the last row, which has no successor', () {
      final source = _Source(['ab', 'cd'], wrapped: [false, true]);

      expect(wrapsToNext(source, 1), isFalse);
    });
  });

  group('trimmedLengthAt', () {
    test('drops trailing blanks from a row that ends its line', () {
      expect(trimmedLengthAt(_Source(['ab    ']), 0), 2);
    });

    test('keeps every cell of a row that continues onto the next', () {
      final source = _Source(['ab    ', 'cd    '], wrapped: _run(2));

      expect(trimmedLengthAt(source, 0), 6);
    });

    test('counts a styled space as content', () {
      expect(trimmedLengthAt(_Source(['ab__  ']), 0), 4);
    });

    test('trims an all-blank row to nothing', () {
      expect(trimmedLengthAt(_Source(['      ']), 0), 0);
    });

    test('keeps a pinned column parked past the last glyph', () {
      final source = _Source(['ab    '], pinned: {0: 4});

      expect(trimmedLengthAt(source, 0), 4);
    });

    test('leaves a pin inside the content alone', () {
      final source = _Source(['abcd  '], pinned: {0: 2});

      expect(trimmedLengthAt(source, 0), 4);
    });
  });

  group('logical lines', () {
    test('an unwrapped row is a line by itself', () {
      final source = _Source(['ab', 'cd']);

      expect(logicalLineEnd(source, 0), 1);
    });

    test('consecutive wrapped rows form one line', () {
      final source = _Source(['ab', 'cd', 'ef'], wrapped: _run(3));

      expect(logicalLineEnd(source, 0), 3);
    });

    test('row 0 starts a line even with its wrap bit set', () {
      // The row it continued from was evicted from scrollback.
      final source = _Source(['ab', 'cd'], wrapped: [true, false]);

      expect(logicalLineEnd(source, 0), 1);
      expect(plannedTotalRowCount(source, newCols: 2), 2);
    });

    test('length sums the run, untrimmed except at the end', () {
      final source = _Source(['ab   ', 'cd   '], wrapped: _run(2));

      expect(logicalLineLength(source, 0), 7);
    });
  });

  group('plannedRowCount', () {
    test('is unchanged at the same width', () {
      final source = _Source(['abcde', 'fg   '], wrapped: _run(2));

      expect(plannedRowCount(source, firstRow: 0, newCols: 5), 2);
    });

    test('rejoins a run into fewer rows when widening', () {
      final source = _Source(['abcde', 'fg   '], wrapped: _run(2));

      expect(plannedRowCount(source, firstRow: 0, newCols: 10), 1);
    });

    test('splits into more rows when narrowing', () {
      final source = _Source(['abcdefgh']);

      expect(plannedRowCount(source, firstRow: 0, newCols: 3), 3);
    });

    test('adds no trailing row when the content divides evenly', () {
      final source = _Source(['abcdef']);

      expect(plannedRowCount(source, firstRow: 0, newCols: 3), 2);
    });

    test('gives a blank logical line a row of its own', () {
      expect(plannedRowCount(_Source(['     ']), firstRow: 0, newCols: 3), 1);
    });

    test('collapses trailing blank rows of a run', () {
      final source = _Source(['abcde', '     '], wrapped: _run(2));

      expect(plannedRowCount(source, firstRow: 0, newCols: 5), 1);
    });

    test('starts from the row it is given, not row 0', () {
      final source = _Source(['ab    ', 'cd    ', 'ghijkl']);

      expect(plannedRowCount(source, firstRow: 2, newCols: 3), 2);
    });
  });

  group('double-width clusters', () {
    test('breaks a column early rather than splitting one', () {
      // Six columns of content whose last cluster is wide: at width 4
      // the cluster cannot start in the final column, so the first row
      // takes three.
      final source = _Source(['abc[]f']);

      expect(plannedRowCount(source, firstRow: 0, newCols: 4), 2);
    });

    test('fills the row when the boundary lands between clusters', () {
      final source = _Source(['ab[]ef']);

      expect(plannedRowCount(source, firstRow: 0, newCols: 4), 2);
    });

    test('terminates at a single column instead of retrying the break', () {
      // xterm.js locks up here: it shortens the row for the cluster and
      // re-tests forever. The cluster takes the row it cannot fit.
      final source = _Source(['[]']);

      expect(plannedRowCount(source, firstRow: 0, newCols: 1), 2);
    });

    test('narrows plain content to a single column', () {
      expect(plannedRowCount(_Source(['abcd']), firstRow: 0, newCols: 1), 4);
    });

    test('crosses a source row boundary while probing', () {
      final source = _Source(['abcde', 'f[]hi', 'jk   '], wrapped: _run(3));

      expect(plannedRowCount(source, firstRow: 0, newCols: 4), 3);
    });
  });

  group('plannedTotalRowCount', () {
    test('sums independent logical lines', () {
      final source = _Source(['abcdef', 'ghijkl']);

      expect(plannedTotalRowCount(source, newCols: 3), 4);
    });

    test('counts nothing for an empty source', () {
      expect(plannedTotalRowCount(_Source([]), newCols: 10), 0);
    });

    test('is the row count when nothing is trimmed at the same width', () {
      final source = _Source(
        ['abc', 'def', 'ghi'],
        wrapped: [false, true, false],
      );

      expect(plannedTotalRowCount(source, newCols: 3), 3);
    });

    test('drops trailing blank rows at the same width', () {
      final source = _Source(['abc', '   ', 'ghi'], wrapped: _run(3));

      expect(plannedTotalRowCount(source, newCols: 3), 3);
    });
  });

  group('properties', () {
    /// Grids of random content, wrap bits, and blank runs — the shapes
    /// a real buffer produces, without hand-picking them. A cluster is
    /// only placed where its continuation also fits, because printing
    /// wraps a column early rather than leaving a half off the edge.
    List<_Source> samples() {
      final random = Random(20260726);

      String row(int cols) {
        final cells = <String>[];
        while (cells.length < cols) {
          final pick = random.nextInt(5);
          if (pick == 4 && cells.length + 2 <= cols) {
            cells.addAll(const ['[', ']']);
          } else {
            cells.add(const [' ', '_', 'a', 'b', 'c'][pick]);
          }
        }
        return cells.join();
      }

      return [
        for (var i = 0; i < 200; i++)
          () {
            final cols = 1 + random.nextInt(8);
            final rowCount = 1 + random.nextInt(6);
            return _Source(
              [for (var r = 0; r < rowCount; r++) row(cols)],
              wrapped: [
                false,
                for (var r = 1; r < rowCount; r++) random.nextBool(),
              ],
            );
          }(),
      ];
    }

    test('never counts more rows than the source holds at equal width', () {
      for (final source in samples()) {
        expect(
          plannedTotalRowCount(source, newCols: source.cols),
          lessThanOrEqualTo(source.rowCount),
          reason: source.rows.toString(),
        );
      }
    });

    test('narrowing never needs fewer rows', () {
      for (final source in samples()) {
        var previous = 0;
        for (var newCols = source.cols; newCols >= 1; newCols--) {
          final rows = plannedTotalRowCount(source, newCols: newCols);
          expect(
            rows,
            greaterThanOrEqualTo(previous),
            reason: '${source.rows} at $newCols',
          );
          previous = rows;
        }
      }
    });

    test('widening never needs more rows', () {
      for (final source in samples()) {
        var previous = plannedTotalRowCount(source, newCols: source.cols);
        for (var newCols = source.cols; newCols <= source.cols * 3; newCols++) {
          final rows = plannedTotalRowCount(source, newCols: newCols);
          expect(
            rows,
            lessThanOrEqualTo(previous),
            reason: '${source.rows} at $newCols',
          );
          previous = rows;
        }
      }
    });

    test('every logical line gets at least one row', () {
      for (final source in samples()) {
        for (var newCols = 1; newCols <= source.cols * 2; newCols++) {
          var row = 0;
          while (row < source.rowCount) {
            expect(
              plannedRowCount(source, firstRow: row, newCols: newCols),
              greaterThanOrEqualTo(1),
              reason: '${source.rows} row $row at $newCols',
            );
            row = logicalLineEnd(source, row);
          }
        }
      }
    });
  });
}
