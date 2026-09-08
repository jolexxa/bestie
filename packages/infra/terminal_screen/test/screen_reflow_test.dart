// Reflow driven the way a child drives it: real bytes through the
// parser, then a resize. The Buffer-level tests write packed cells
// directly, so this is the only place the grapheme spill table, the
// print path's own wrap decisions, and the positions `Screen` carries
// all meet a re-wrap at once.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _term({
  required int rows,
  required int cols,
  int scrollback = 20,
  ResizeBehavior behavior = const ReflowingResize(),
}) => Screen(
  rows: rows,
  cols: cols,
  scrollbackBytes: scrollback * 4096,
  resizeBehavior: behavior,
);

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  // Settle any cluster still being accumulated so the grid is whole.
  screen.snapshot();
}

String _read(int cols, CellData Function(int col) cell) {
  final buffer = StringBuffer();
  for (var col = 0; col < cols; col++) {
    final data = cell(col);
    if (data.width == CellWidth.continuation) continue;
    buffer.write(data.char);
  }
  return buffer.toString().trimRight();
}

String _row(Screen screen, int row) =>
    _read(screen.cols, (col) => screen.cellAt(row, col));

String _history(Screen screen, int line) =>
    _read(screen.cols, (col) => screen.scrollbackCellAt(line, col));

String _viewRow(Screen screen, int row) =>
    _read(screen.cols, (col) => screen.viewportCellAt(row, col));

/// Scrollback then viewport, as one sequence oldest first.
List<String> _all(Screen screen) => [
  for (var line = 0; line < screen.scrollbackLength; line++)
    _history(screen, line),
  for (var row = 0; row < screen.rows; row++) _row(screen, row),
];

void main() {
  group("re-wrapping a child's output", () {
    test('rejoins a line the child soft-wrapped', () {
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\n');
      expect(_all(screen), ['abcdefghij', 'klmnop', '', '']);

      screen.resize(rows: 4, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', '', '', '']);
    });

    test('splits a line the child never wrapped', () {
      final screen = _term(rows: 4, cols: 20);
      _feed(screen, 'abcdefghijklmnop\r\n');

      screen.resize(rows: 4, cols: 10);

      expect(_all(screen), ['abcdefghij', 'klmnop', '', '']);
    });

    test('keeps a hard newline distinct from a soft wrap', () {
      final screen = _term(rows: 5, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\nQRS\r\n');

      screen.resize(rows: 5, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', 'QRS', '', '', '']);
    });

    test('re-wraps history that has already scrolled off', () {
      final screen = _term(rows: 2, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\nQRS\r\nTUV\r\n');
      expect(screen.scrollbackLength, greaterThan(0));

      screen.resize(rows: 2, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', 'QRS', 'TUV', '']);
    });

    test('re-wraps the line the cursor is on', () {
      // A repainting shell recomputes its prompt line for the new width
      // and clears from where it thinks that line starts, so the cursor
      // line has to re-wrap with the rest — freezing it would leave the
      // shell's clear one row short and strand the old breaks.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop');
      expect([screen.cursor.row, screen.cursor.col], [1, 6]);

      screen.resize(rows: 4, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', '', '', '']);
      expect([screen.cursor.row, screen.cursor.col], [0, 16]);
    });

    test('re-wraps the cursor line when the cursor sits above its tail', () {
      // The cursor sits on the *first* row of a wrapped run, which
      // reaches below it; the whole run still re-wraps as one line.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop\x1B[A');
      expect(screen.cursor.row, 0);

      screen.resize(rows: 4, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', '', '', '']);
      expect(screen.cursor.row, 0);
    });

    test('re-wraps a line the cursor has since left', () {
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\nxyz');

      screen.resize(rows: 4, cols: 20);

      expect(_all(screen), ['abcdefghijklmnop', 'xyz', '', '']);
    });
  });

  group('wrap markers', () {
    test('a reprinted row no longer continues the line above it', () {
      // A program that homes the cursor and redraws lands on rows that
      // were soft-wrap continuations. The line feed has to retire that
      // marker: leaving it splices two reprinted lines into one on the
      // next re-wrap, with the overwritten tail stranded between them.
      // ConPTY redraws exactly this way after every resize.
      final screen = _term(rows: 4, cols: 8);
      _feed(screen, 'AAAAAAAABBBB');
      expect([_row(screen, 0), _row(screen, 1)], ['AAAAAAAA', 'BBBB']);

      _feed(screen, '\x1B[Hone\r\ntwo\r\nthree');
      expect([_row(screen, 0), _row(screen, 1)], ['oneAAAAA', 'twoB']);

      screen.resize(rows: 4, cols: 20);

      expect(_row(screen, 0), 'oneAAAAA');
      expect(_row(screen, 1), 'twoB');
    });

    test('a row reprinted in place no longer continues the line above', () {
      // No line feed lands on this row to retire its marker: history holds
      // the head of a soft-wrapped line and the viewport holds its tail, so
      // the line is still open when the child seeks straight to that row and
      // prints something else there. Leaving the marker on splices the new
      // text onto the open line. ConPTY redraws exactly this way.
      final screen = _term(rows: 2, cols: 4);
      _feed(screen, 'abcdefgh\r\n');
      expect(screen.selectionLines(), ['abcdefgh']);

      _feed(screen, '\x1B[1;1H\x1B[JWXYZ\r\n\n');

      expect(screen.selectionLines(), ['abcd', 'WXYZ']);
    });

    test('a genuine soft wrap still rejoins after a redraw', () {
      // The same reset must not disarm real wrapping: the row the
      // print path wraps onto is marked immediately after the feed.
      final screen = _term(rows: 4, cols: 8);
      _feed(screen, 'xxxx\r\nyyyy');
      // The trailing feed moves the cursor off the run, which would
      // otherwise be left alone as the line the child is editing.
      _feed(screen, '\x1B[HAAAAAAAABBBB\r\n');

      screen.resize(rows: 4, cols: 20);

      expect(_row(screen, 0), 'AAAAAAAABBBB');
    });
  });

  group('grapheme clusters', () {
    const family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';

    test('carries a ZWJ sequence across a rejoin', () {
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefgh${family}ij\r\n');
      expect(_row(screen, 0), 'abcdefgh$family');

      screen.resize(rows: 4, cols: 20);

      expect(_row(screen, 0), 'abcdefgh${family}ij');
      expect(screen.cellAt(0, 8).char, family);
      expect(screen.cellAt(0, 8).width, CellWidth.wide);
      expect(screen.cellAt(0, 9).width, CellWidth.continuation);
    });

    test('does not turn the column a break gave up into a space', () {
      // Printing at 10 columns cannot fit the cluster in column 9, so
      // it starts the next row and tags the column it abandoned. A
      // rejoin that mistook that tag for a printed space would grow
      // the line by one column on every resize.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghi$family\r\n');
      expect(_row(screen, 1), family);

      screen.resize(rows: 4, cols: 20);

      expect(_row(screen, 0), 'abcdefghi$family');
    });

    test('gives a cluster a row of its own at a single column', () {
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'ab${family}cd\r\n');

      screen.resize(rows: 4, cols: 1);

      expect(_all(screen).where((row) => row.isNotEmpty), [
        'a',
        'b',
        family,
        'c',
        'd',
      ]);
    });
  });

  group('carried positions', () {
    test('the cursor moves up as the rows above it rejoin', () {
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\n');
      expect(screen.cursor.row, 2);

      screen.resize(rows: 4, cols: 20);

      expect([screen.cursor.row, screen.cursor.col], [1, 0]);
    });

    test('the cursor moves down as the rows above it split', () {
      final screen = _term(rows: 4, cols: 20);
      _feed(screen, 'abcdefghijklmnop\r\n');
      expect(screen.cursor.row, 1);

      screen.resize(rows: 4, cols: 10);

      expect([screen.cursor.row, screen.cursor.col], [2, 0]);
    });

    test('a cursor pushed above the viewport lands on the top row', () {
      final screen = _term(rows: 3, cols: 12);
      _feed(screen, 'aaaaaaaaaaaa\r\nbbbbbbbbbbbb\r\ncccccccccccc');
      // Park the cursor on the first row, so narrowing multiplies the
      // rows below it and shoves it off the top.
      _feed(screen, '\x1B[H');

      screen.resize(rows: 3, cols: 3);

      expect(screen.cursor.row, 0);
    });

    test('the saved cursor is remapped, so DECRC still lands on its cell', () {
      final screen = _term(rows: 4, cols: 10);
      // Save inside the wrapped run, then leave it so the run is no
      // longer the cursor's own line and does get re-wrapped.
      _feed(screen, 'abcdefghijklmnop\x1B7\r\nxyz');
      expect(screen.cursor.row, 2);

      screen.resize(rows: 4, cols: 20);
      _feed(screen, '\x1B8');

      expect([screen.cursor.row, screen.cursor.col], [0, 16]);
    });

    test('a saved cursor pushed above the viewport lands on the top row', () {
      final screen = _term(rows: 3, cols: 12);
      _feed(screen, '\x1B7');
      _feed(screen, 'aaaaaaaaaaaa\r\nbbbbbbbbbbbb\r\ncccccccccccc');

      screen.resize(rows: 3, cols: 3);
      _feed(screen, '\x1B8');

      expect(screen.cursor.row, 0);
    });

    test('a scrolled-back view keeps the same history row on top', () {
      final screen = _term(rows: 3, cols: 10);
      for (var line = 0; line < 10; line++) {
        _feed(screen, 'row$line\r\n');
      }
      screen.setViewOffset(3);
      final top = _viewRow(screen, 0);

      screen.resize(rows: 3, cols: 20);

      expect(screen.viewOffset, 3);
      expect(_viewRow(screen, 0), top);
    });

    test('a scrolled-back view holds its line when narrowing multiplies '
        'the rows above it', () {
      // Every line grows from two rows to three, so the pinned history
      // row moves a long way. Reading the line back by name is the only
      // assertion that cannot be satisfied by landing somewhere
      // plausible-looking.
      final screen = _term(rows: 4, cols: 12, scrollback: 200);
      for (var line = 0; line < 20; line++) {
        _feed(screen, 'L$line${'.' * (18 - '$line'.length)}\r\n');
      }
      // Park the top of the view on the first row of one line rather
      // than mid-way through one, so the assertion reads a label.
      screen.setViewOffset(21);
      final before = screen.viewOffset;
      expect(_viewRow(screen, 0), startsWith('L8'));

      screen.resize(rows: 4, cols: 8);

      expect(_viewRow(screen, 0), startsWith('L8'));
      expect(screen.viewOffset, greaterThan(before));
    });

    test('a scrolled-back view snaps live when its row rejoins the '
        'viewport', () {
      final screen = _term(rows: 3, cols: 10);
      _feed(screen, 'abcdefghijklmnopqrstuvwxyz\r\nQRS\r\n');
      screen
        ..setViewOffset(1)
        ..resize(rows: 3, cols: 40);

      expect(screen.viewOffset, 0);
    });

    test('pending wrap survives while the cursor is still at the margin', () {
      final screen = _term(rows: 3, cols: 10);
      _feed(screen, 'abcdefghij');
      expect(screen.cursor.pendingWrap, isTrue);

      screen.resize(rows: 3, cols: 5);

      expect([screen.cursor.row, screen.cursor.col], [1, 4]);
      expect(screen.cursor.pendingWrap, isTrue);
    });

    test('pending wrap clears once the cursor is off the margin', () {
      final screen = _term(rows: 3, cols: 10);
      _feed(screen, 'abcdefghij');

      screen.resize(rows: 3, cols: 20);

      expect(screen.cursor.col, 9);
      expect(screen.cursor.pendingWrap, isFalse);
    });
  });

  group('viewport anchoring', () {
    /// Six lines through a four-row screen, then `clear`: history is
    /// kept, the viewport is blank, and the prompt is back at the top.
    Screen cleared({required int rows}) {
      final screen = _term(rows: rows, cols: 10);
      _feed(screen, 'aaa\r\nbbb\r\nccc\r\nddd\r\neee\r\nfff\r\n');
      _feed(screen, '\x1B[2J\x1B[H\$ ');
      expect(screen.scrollbackLength, greaterThan(0));
      return screen;
    }

    test('a cleared screen stays clear when the width changes', () {
      final screen = cleared(rows: 4);
      final history = screen.scrollbackLength;

      screen.resize(rows: 4, cols: 14);

      expect(_all(screen).sublist(history), [r'$', '', '', '']);
      expect(screen.cursor.row, 0);
      expect(screen.scrollbackLength, history);
    });

    test('a cleared screen stays clear when it gets taller', () {
      final screen = cleared(rows: 4);
      final history = screen.scrollbackLength;

      screen.resize(rows: 6, cols: 10);

      expect(_row(screen, 0), r'$');
      expect(screen.cursor.row, 0);
      expect(screen.scrollbackLength, history);
    });

    test('a wider window rejoins lines and fills from history', () {
      // Rejoining frees rows above the prompt. The prompt cannot drift
      // upward — it is where the child writes next — so the rows it
      // frees are taken back from history instead.
      final screen = _term(rows: 6, cols: 10, scrollback: 50);
      for (var line = 0; line < 8; line++) {
        _feed(screen, 'L$line-abcdefghijkl\r\n');
      }
      _feed(screen, r'$ ');
      expect(screen.cursor.row, 5);
      expect(screen.scrollbackLength, 11);

      screen.resize(rows: 6, cols: 20);

      expect(screen.cursor.row, 5);
      expect(screen.scrollbackLength, 3);
      expect(_row(screen, 0), 'L3-abcdefghijkl');
    });

    test('a taller window keeps the prompt at the bottom', () {
      final screen = _term(rows: 6, cols: 20, scrollback: 50);
      for (var line = 0; line < 8; line++) {
        _feed(screen, 'L$line-abcdefghijkl\r\n');
      }
      _feed(screen, r'$ ');
      expect(screen.cursor.row, 5);

      screen.resize(rows: 9, cols: 20);

      expect(screen.cursor.row, 8);
      expect(screen.scrollbackLength, 0);
      expect(_row(screen, 0), 'L0-abcdefghijkl');
    });

    test('a taller window leaves history alone when the child repaints', () {
      // ConPTY reprints its viewport from a buffer that no longer holds
      // the rows it scrolled away, so history taken back here is
      // overwritten a moment later — and left duplicated in ours.
      final screen = _term(
        rows: 4,
        cols: 10,
        behavior: const RepaintingResize(),
      );
      _feed(screen, 'one\r\ntwo\r\nthree\r\nfour\r\nfive\r\nsix');
      expect([screen.cursor.row, screen.scrollbackLength], [3, 2]);

      screen.resize(rows: 6, cols: 10);

      expect(screen.scrollbackLength, 2);
      expect(_row(screen, 0), 'three');
      expect(_row(screen, 4), '');
      expect(screen.cursor.row, 3);
    });

    test('a taller and wider window leaves history alone when the child '
        'repaints', () {
      final screen = _term(
        rows: 4,
        cols: 10,
        behavior: const RepaintingResize(),
      );
      _feed(screen, 'one\r\ntwo\r\nthree\r\nfour\r\nfive\r\nsix');

      screen.resize(rows: 6, cols: 20);

      expect(screen.scrollbackLength, 2);
      expect(_row(screen, 0), 'three');
      expect(screen.cursor.row, 3);
    });

    test('a shorter window pushes the top into history', () {
      // The cursor is on the last row, so there is no blank space to
      // give up and the oldest rows have to go somewhere.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'one\r\ntwo\r\nthree\r\nfour');

      screen.resize(rows: 2, cols: 10);

      expect(_all(screen), ['one', 'two', 'three', 'four']);
      expect(screen.scrollbackLength, 2);
      expect(screen.cursor.row, 1);
    });

    test('a shorter window eats blank rows before it touches history', () {
      final screen = _term(rows: 5, cols: 10);
      _feed(screen, 'one\r\ntwo');

      screen.resize(rows: 3, cols: 10);

      expect(_all(screen), ['one', 'two', '']);
      expect(screen.scrollbackLength, 0);
      expect(screen.cursor.row, 1);
    });

    test('growth above the cursor eats the space below it, not history', () {
      // Narrowing turns the wrapped run from two rows into four. The
      // blank rows under the cursor absorb that, so nothing is pushed
      // out of view to make room.
      final screen = _term(rows: 6, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\nQRS');
      expect(screen.cursor.row, 2);

      screen.resize(rows: 6, cols: 5);

      expect(screen.cursor.row, 4);
      expect(screen.scrollbackLength, 0);
    });

    test('the alt screen cursor follows its row when the window shrinks', () {
      // The alt buffer has no history to push into, so its top rows go
      // for good — and the cursor has to come along.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, '\x1B[?1049hone\r\ntwo\r\nthree\r\nfour');
      expect(screen.cursor.row, 3);

      screen.resize(rows: 2, cols: 10);

      expect(_row(screen, 0), 'three');
      expect(_row(screen, 1), 'four');
      expect(screen.cursor.row, 1);
    });

    test('a shorter window keeps the row the cursor is on', () {
      // Blank rows below the cursor go first; the cursor's own row is
      // never one of them, however empty it looks.
      final screen = _term(rows: 5, cols: 10);
      _feed(screen, 'one\r\ntwo\r\n');

      screen.resize(rows: 2, cols: 10);

      expect(_all(screen), ['one', 'two', '']);
      expect(screen.scrollbackLength, 1);
      expect(screen.cursor.row, 1);
    });

    test('a narrower window keeps the empty row the cursor is on', () {
      // The cursor sits on the empty row past the last line, which is where
      // the next line prints. Narrowing re-wraps the content into more rows
      // than the viewport holds, and anchoring at the seam puts that empty
      // row below the bottom — leaving the cursor clamped onto the last
      // line, so the next line prints into the middle of it.
      final screen = _term(
        rows: 4,
        cols: 13,
        behavior: const RepaintingResize(),
      );
      _feed(screen, 'line-1-xxxxx\r\nline-2-xxxxx\r\n');

      screen
        ..resize(rows: 4, cols: 7)
        ..resize(rows: 4, cols: 6);
      _feed(screen, 'after\r\n');

      expect(screen.selectionLines().where((line) => line.isNotEmpty), [
        'line-1-xxxxx',
        'line-2-xxxxx',
        'after',
      ]);
    });
  });

  group('gating', () {
    test('the alt screen is not re-wrapped', () {
      // Its programs redraw from scratch, and it has no scrollback to
      // put the extra rows in.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, '\x1B[?1049habcdefghijklmnop');

      screen.resize(rows: 4, cols: 20);

      expect(_row(screen, 0), 'abcdefghij');
      expect(_row(screen, 1), 'klmnop');
    });

    test('a height-only change does not re-wrap', () {
      final screen = _term(rows: 3, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\n');

      screen.resize(rows: 6, cols: 10);

      expect(_row(screen, 0), 'abcdefghij');
      expect(_row(screen, 1), 'klmnop');
    });

    test('a resize to the same size does nothing at all', () {
      final screen = _term(rows: 3, cols: 10);
      _feed(screen, 'abcdefghijklmnop');
      final before = screen.mutationCount;

      screen.resize(rows: 3, cols: 10);

      expect(screen.mutationCount, before);
    });

    test('the main buffer still re-wraps while the alt screen is up', () {
      // Its rows are the ones the user comes back to, and its cursor
      // is the one DECSET 1049 stashed.
      final screen = _term(rows: 4, cols: 10);
      _feed(screen, 'abcdefghijklmnop\r\n');
      _feed(screen, '\x1B[?1049h');

      screen.resize(rows: 4, cols: 20);
      _feed(screen, '\x1B[?1049l');

      expect(_row(screen, 0), 'abcdefghijklmnop');
      expect(screen.cursor.row, 1);
    });
  });
}
