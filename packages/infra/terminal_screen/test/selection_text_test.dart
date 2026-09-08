import 'package:terminal_screen/src/selection_text.dart';
import 'package:test/test.dart';

import 'reflow_fakes.dart';

void main() {
  // The fake grids one char per column: ' ' blank, '[' a wide cluster's
  // left half, ']' its continuation, '^' a spacer head, else a glyph.
  String charAt(FakeReflowSource s, int r, int c) => s.rows[r][c];
  int charLenAt(FakeReflowSource s, int r, int c) => charAt(s, r, c).length;

  SelectionText render(FakeReflowSource s) =>
      renderSelection(s, (r, c) => charAt(s, r, c));
  SelectionMetrics measure(FakeReflowSource s) =>
      measureSelection(s, (r, c) => charLenAt(s, r, c));

  group('renderSelection', () {
    test('trims trailing blank cells from a line', () {
      final s = FakeReflowSource(['hi   ']);
      expect(render(s).text, 'hi');
    });

    test('keeps a space the child actually styled onto the line', () {
      // '_' in the fake is a styled (non-blank) space — real content.
      final s = FakeReflowSource(['a_ b ']);
      expect(render(s).text, 'a_ b');
    });

    test('joins hard lines with a newline', () {
      final s = FakeReflowSource(['ab   ', 'cd   ']);
      expect(render(s).text, 'ab\ncd');
    });

    test('joins a soft-wrapped line with no newline', () {
      final s = FakeReflowSource(
        ['abcde', 'fg   '],
        wrapped: [false, true],
      );
      expect(render(s).text, 'abcdefg');
    });

    test('drops trailing blank rows entirely', () {
      final s = FakeReflowSource(['ab   ', '     ', '     ']);
      expect(render(s).text, 'ab');
    });

    test('preserves a blank line in the middle of content', () {
      final s = FakeReflowSource(['ab   ', '     ', 'cd   ']);
      expect(render(s).text, 'ab\n\ncd');
    });

    test('drops the column a wide cluster gave up at a wrap', () {
      // Row wraps onward but its last column is a spacer head.
      final s = FakeReflowSource(
        ['abcd^', 'ef   '],
        wrapped: [false, true],
      );
      expect(render(s).text, 'abcdef');
    });

    test('emits a wide cluster once and skips its continuation', () {
      final s = FakeReflowSource(['a[]b ']);
      expect(render(s).text, 'a[b');
    });

    test('is empty when every row is blank', () {
      final s = FakeReflowSource(['     ', '     ']);
      expect(render(s).text, isEmpty);
      expect(render(s).lines, isEmpty);
    });

    test('exposes the logical lines it joined', () {
      final s = FakeReflowSource(['ab   ', 'cd   ']);
      expect(render(s).lines, ['ab', 'cd']);
    });
  });

  group('measureSelection', () {
    test('row length counts characters, content cols counts columns', () {
      // "a[b" is 3 chars across 4 content columns (the wide cluster spans
      // two columns but contributes one glyph).
      final s = FakeReflowSource(['a[]b ']);
      final m = measure(s);
      expect(m.rowLengths[0], 3);
      expect(m.rowContentCols[0], 4);
    });

    test('content length matches the rendered text length', () {
      final s = FakeReflowSource(['ab   ', '     ', 'cd   ']);
      expect(measure(s).contentLength, render(s).text.length);
    });

    test('row starts advance by a newline between hard lines', () {
      final s = FakeReflowSource(['ab   ', 'cd   ']);
      final m = measure(s);
      expect(m.rowStarts[0], 0);
      expect(m.rowStarts[1], 3); // "ab" + "\n"
      expect(m.rowStarts[2], 5); // + "cd"
    });

    test('row starts do not advance by a newline across a soft wrap', () {
      final s = FakeReflowSource(
        ['abcde', 'fg   '],
        wrapped: [false, true],
      );
      final m = measure(s);
      expect(m.rowStarts[0], 0);
      expect(m.rowStarts[1], 5); // continuation joins directly
      expect(m.contentLength, 7);
    });

    test('trailing blank rows contribute nothing and no newline', () {
      final s = FakeReflowSource(['ab   ', '     ', '     ']);
      final m = measure(s);
      expect(m.contentLength, 2);
      expect(m.rowLengths[1], 0);
      expect(m.rowLengths[2], 0);
    });
  });
}
