// Emission: where rows break, which ones are marked as continuations,
// what fills the columns a break gave up, and where tracked positions
// land. The planner counts these rows; the writer has to produce
// exactly the ones it counted.

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:test/test.dart';

import 'reflow_fakes.dart';

typedef _Source = FakeReflowSource;

const List<bool> Function(int) _run = continuationRun;

FakeRowSink _reflow(
  _Source source, {
  required int newCols,
  List<ReflowPin> pins = const [],
  int firstRow = 0,
}) {
  final sink = FakeRowSink(source, cols: newCols);
  ReflowWriter(source: source, sink: sink, pins: pins).run(firstRow: firstRow);
  return sink;
}

void main() {
  group('re-wrapping', () {
    test('reproduces the source at the same width', () {
      final sink = _reflow(
        _Source(['abcde', 'fg   '], wrapped: _run(2)),
        newCols: 5,
      );

      expect(sink.rows, ['abcde', 'fg   ']);
      expect(sink.wrapped, [false, true]);
    });

    test('rejoins a wrapped run when widening', () {
      final sink = _reflow(
        _Source(['abcde', 'fg   '], wrapped: _run(2)),
        newCols: 10,
      );

      expect(sink.rows, ['abcdefg   ']);
      expect(sink.wrapped, [false]);
    });

    test('splits a long line when narrowing', () {
      final sink = _reflow(_Source(['abcdefgh']), newCols: 3);

      expect(sink.rows, ['abc', 'def', 'gh ']);
    });

    test('marks every row after the first as a continuation', () {
      final sink = _reflow(_Source(['abcdefgh']), newCols: 3);

      expect(sink.wrapped, [false, true, true]);
    });

    test('starts each logical line unwrapped', () {
      final sink = _reflow(_Source(['abcd', 'efgh']), newCols: 2);

      expect(sink.rows, ['ab', 'cd', 'ef', 'gh']);
      expect(sink.wrapped, [false, true, false, true]);
    });

    test('blanks the columns a short final row does not fill', () {
      final sink = _reflow(_Source(['abcde']), newCols: 4);

      expect(sink.rows, ['abcd', 'e   ']);
    });

    test('begins at the row it is given', () {
      final sink = _reflow(
        _Source(['aaaa', 'bbbb', 'cccc']),
        newCols: 4,
        firstRow: 1,
      );

      expect(sink.rows, ['bbbb', 'cccc']);
    });

    test('carries a styled space through as content', () {
      final sink = _reflow(_Source(['ab__  ']), newCols: 3);

      expect(sink.rows, ['ab_', '_  ']);
    });
  });

  group('blank rows', () {
    test('keeps a blank line between two populated ones', () {
      final sink = _reflow(_Source(['aaa', '   ', 'bbb']), newCols: 3);

      expect(sink.rows, ['aaa', '   ', 'bbb']);
      expect(sink.wrapped, [false, false, false]);
    });

    test('never emits blank lines that trail the content', () {
      final sink = _reflow(
        _Source(['aaa', '   ', '   ', '   ']),
        newCols: 3,
      );

      expect(sink.rows, ['aaa']);
    });

    test('drops the blank tail of a wrapped run', () {
      final sink = _reflow(
        _Source(['abcde', '     '], wrapped: _run(2)),
        newCols: 5,
      );

      expect(sink.rows, ['abcde']);
    });

    test('emits nothing for an entirely blank source', () {
      expect(_reflow(_Source(['   ', '   ']), newCols: 3).rows, isEmpty);
    });

    test('emits nothing for an empty source', () {
      expect(_reflow(_Source([]), newCols: 3).rows, isEmpty);
    });
  });

  group('double-width clusters', () {
    test('breaks a column early rather than splitting one', () {
      final sink = _reflow(_Source(['abc[]f']), newCols: 4);

      expect(sink.rows, ['abc^', '[]f ']);
    });

    test('tags the column the break gave up', () {
      // Blank to a reader, but marked so a later pass does not mistake
      // it for a space the child printed and grow the line.
      final sink = _reflow(_Source(['abc[]f']), newCols: 4);

      expect(sink.source.widthAt(0, 3), isNot(CellWidth.spacerHead));
      expect(sink.rows.first[3], '^');
    });

    test('leaves the tail of a final row untagged', () {
      final sink = _reflow(_Source(['abcde']), newCols: 4);

      expect(sink.rows, ['abcd', 'e   ']);
    });

    test('fills the row when the boundary falls between clusters', () {
      final sink = _reflow(_Source(['ab[]ef']), newCols: 4);

      expect(sink.rows, ['ab[]', 'ef  ']);
    });

    test('gives a cluster its own row at a single column', () {
      final sink = _reflow(_Source(['a[]b']), newCols: 1);

      expect(sink.rows, ['a', '[', ']', 'b']);
    });

    test('repacks a cluster that moves between source rows', () {
      final sink = _reflow(
        _Source(['abcde', 'f[]hi', 'jk   '], wrapped: _run(3)),
        newCols: 4,
      );

      expect(sink.rows, ['abcd', 'ef[]', 'hijk']);
    });

    test('breaks early for a cluster found past the current source row', () {
      // The row being filled is wider than a source row, so deciding
      // where it breaks means looking into the row after the one the
      // copy cursor sits on.
      final sink = _reflow(
        _Source(['abcde', 'fg[]i', 'jk   '], wrapped: _run(3)),
        newCols: 8,
      );

      expect(sink.rows, ['abcdefg^', '[]ijk   ']);
    });
  });

  group('pins', () {
    test('follows its cell when a line is split', () {
      final pin = ReflowPin(row: 0, col: 5);

      _reflow(_Source(['abcdefgh']), newCols: 3, pins: [pin]);

      expect(pin.row, 1);
      expect(pin.col, 2);
    });

    test('follows its cell when a run is rejoined', () {
      final pin = ReflowPin(row: 1, col: 1);

      _reflow(
        _Source(['abcde', 'fg   '], wrapped: _run(2)),
        newCols: 10,
        pins: [pin],
      );

      expect(pin.row, 0);
      expect(pin.col, 6);
    });

    test('lands on the cell it was parked on past trailing blanks', () {
      // Trimming keeps the pinned column, so the pass has somewhere to
      // put it — a fresh prompt line looks exactly like this.
      final pin = ReflowPin(row: 0, col: 5);

      final sink = _reflow(
        _Source(['ab      '], pinned: {0: 6}),
        newCols: 3,
        pins: [pin],
      );

      expect(sink.rows, ['ab ', '   ']);
      expect(pin.row, 1);
      expect(pin.col, 2);
    });

    test('keeps a blank line alive when a pin sits on it', () {
      final pin = ReflowPin(row: 1, col: 0);

      final sink = _reflow(
        _Source(['aaa', '   '], pinned: {1: 1}),
        newCols: 3,
        pins: [pin],
      );

      expect(sink.rows, ['aaa', '   ']);
      expect(pin.row, 1);
      expect(pin.col, 0);
    });

    test('relocates several positions in one pass', () {
      final first = ReflowPin(row: 0, col: 0);
      final second = ReflowPin(row: 0, col: 7);

      _reflow(_Source(['abcdefgh']), newCols: 3, pins: [first, second]);

      expect([first.row, first.col], [0, 0]);
      expect([second.row, second.col], [2, 1]);
    });

    test('moves a position once, even when its new row is one still to '
        'be read', () {
      // Narrowing lands pins ahead of rows the read cursor has not
      // reached yet, and a relocated pin holds a destination row
      // counted in the same numbers as source rows. Moving it twice
      // would put it at row 4 here.
      final pin = ReflowPin(row: 1, col: 0);

      _reflow(
        _Source(['aaaa', 'bbbb', 'cccc', 'dddd']),
        newCols: 2,
        pins: [pin],
      );

      expect(pin.row, 2);
      expect(pin.col, 0);
    });

    test('leaves a position on a row the pass never reaches', () {
      final pin = ReflowPin(row: 0, col: 1);

      _reflow(_Source(['aaaa', 'bbbb']), newCols: 4, pins: [pin], firstRow: 1);

      expect(pin.row, 0);
      expect(pin.col, 1);
    });
  });

  group('round trips', () {
    _Source back(FakeRowSink sink) => _Source(sink.rows, wrapped: sink.wrapped);

    test('restores plain content narrowed and widened again', () {
      final source = _Source(['abcdefghij']);

      final narrowed = _reflow(source, newCols: 3);
      final restored = _reflow(back(narrowed), newCols: 10);

      expect(restored.rows, source.rows);
    });

    test('restores content whose break lands on a cluster', () {
      final source = _Source(['abc[]f']);

      final narrowed = _reflow(source, newCols: 4);
      final restored = _reflow(back(narrowed), newCols: 6);

      expect(restored.rows, source.rows);
    });

    test('keeps a hard newline distinct from a soft wrap', () {
      final source = _Source(
        ['1ABCD2', 'EFGH  ', '3IJKL '],
        wrapped: [false, true, false],
      );

      final narrowed = _reflow(source, newCols: 3);
      final restored = _reflow(back(narrowed), newCols: 6);

      expect(restored.rows, ['1ABCD2', 'EFGH  ', '3IJKL ']);
      expect(restored.wrapped, [false, true, false]);
    });
  });

  group('meaningful blanks inside a wrapped line', () {
    // A tab lands the next glyph past the margin, so the spaces it
    // produced end the row and belong to the line.
    test('carries interior spaces when widening', () {
      final sink = _reflow(
        _Source(['ab  ', 'cd  '], wrapped: _run(2)),
        newCols: 5,
      );

      expect(sink.rows, ['ab  c', 'd    ']);
    });

    test('carries interior spaces when narrowing', () {
      final sink = _reflow(
        _Source(['ab  ', 'cd  '], wrapped: _run(2)),
        newCols: 3,
      );

      expect(sink.rows, ['ab ', ' cd']);
    });

    test('does not carry the column a cluster break gave up', () {
      final sink = _reflow(
        _Source(['ab^', '[]c'], wrapped: _run(2)),
        newCols: 5,
      );

      expect(sink.rows, ['ab[]c']);
    });

    test('carries a printed space ahead of a wrapped cluster', () {
      // Identical shape to the gap above but for the tag, and the space
      // is the child's. Without the tag the two are indistinguishable
      // and this space is the one xterm.js eats.
      final sink = _reflow(
        _Source(['ab ', '[]c'], wrapped: _run(2)),
        newCols: 6,
      );

      expect(sink.rows, ['ab []c']);
    });

    test('keeps a blank final column ahead of a narrow glyph', () {
      final sink = _reflow(
        _Source(['ab ', 'cde'], wrapped: _run(2)),
        newCols: 5,
      );

      expect(sink.rows, ['ab cd', 'e    ']);
    });

    test('keeps a continuation cell in the final column', () {
      final sink = _reflow(
        _Source(['a[]', 'bcd'], wrapped: _run(2)),
        newCols: 6,
      );

      expect(sink.rows, ['a[]bcd']);
    });
  });

  group('agreement with the planner', () {
    final sources = <_Source>[
      _Source(['abcdefgh']),
      _Source(['abc[]f']),
      _Source(['ab[]ef']),
      _Source(['abcde', 'fg   '], wrapped: _run(2)),
      _Source(['abcde', 'f[]hi', 'jk   '], wrapped: _run(3)),
      _Source(['a[]b']),
      _Source(['ab__  ']),
      _Source(['ab  ', 'cd  '], wrapped: _run(2)),
      _Source(['ab^', '[]c'], wrapped: _run(2)),
      // Mixed narrow and wide, the shape xterm.js exercises as 'a汉语b'.
      _Source(['a[][]b']),
      _Source(['aaa', '   ', 'bbb']),
    ];

    test('emits exactly the rows the planner counted', () {
      for (final source in sources) {
        for (var newCols = 1; newCols <= source.cols * 2; newCols++) {
          final planned = plannedTotalRowCount(source, newCols: newCols);
          final emitted = _reflow(source, newCols: newCols).rows.length;
          expect(emitted, planned, reason: '${source.rows} at $newCols');
        }
      }
    });

    test('returns to the source when narrowed and widened back', () {
      for (final source in sources) {
        final width = source.cols;
        for (var newCols = 1; newCols < width; newCols++) {
          final narrowed = _reflow(source, newCols: newCols);
          final restored = _reflow(
            _Source(narrowed.rows, wrapped: narrowed.wrapped),
            newCols: width,
          );
          expect(
            restored.rows,
            _reflow(source, newCols: width).rows,
            reason: '${source.rows} via $newCols',
          );
        }
      }
    });
  });
}
