// Selection text driven the way a child drives it: real bytes through
// the parser, then read back as the grid would copy them. The
// selection_text unit tests cover the walk over fakes; this is where the
// grapheme decode, the print path's own wrap decisions, and the
// scrollback seam meet the walk at once.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _term({required int rows, required int cols, int scrollback = 20}) =>
    Screen(rows: rows, cols: cols, scrollbackBytes: scrollback * 4096);

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

void main() {
  group('Screen.selectionText', () {
    test('trims trailing blanks and drops trailing blank rows', () {
      final screen = _term(rows: 4, cols: 6);
      _feed(screen, 'hi');

      expect(screen.selectionText().text, 'hi');
    });

    test('joins hard lines with a newline', () {
      final screen = _term(rows: 4, cols: 6);
      _feed(screen, 'ab\r\ncd');

      expect(screen.selectionText().text, 'ab\ncd');
    });

    test('joins a line that soft-wrapped the margin with no newline', () {
      final screen = _term(rows: 4, cols: 5);
      _feed(screen, 'abcdefg');

      expect(screen.selectionText().text, 'abcdefg');
    });

    test('reads scrollback and the viewport as one selection', () {
      final screen = _term(rows: 2, cols: 5, scrollback: 10);
      _feed(screen, 'L1\r\nL2\r\nL3\r\nL4');

      expect(screen.selectionText().text, 'L1\nL2\nL3\nL4');
    });

    test('is empty for a blank screen', () {
      expect(_term(rows: 4, cols: 6).selectionText().text, isEmpty);
    });
  });

  group('Screen.selectionLines', () {
    test('holds what selectionText would have joined', () {
      final screen = _term(rows: 2, cols: 5, scrollback: 10);
      _feed(screen, 'L1\r\nL2\r\nL3\r\nL4');

      final selection = screen.selectionText();
      expect(screen.selectionLines(), selection.lines);
      expect(screen.selectionLines().join('\n'), selection.text);
    });

    test('keeps a soft-wrapped line whole, as the joined text does', () {
      final screen = _term(rows: 4, cols: 5);
      _feed(screen, 'abcdefg');

      expect(screen.selectionLines(), ['abcdefg']);
    });

    test('is empty for a blank screen', () {
      expect(_term(rows: 4, cols: 6).selectionLines(), isEmpty);
    });
  });

  group('Screen.selectionMetrics', () {
    test('content length agrees with the rendered text', () {
      final screen = _term(rows: 4, cols: 6);
      _feed(screen, 'ab\r\ncd');

      expect(screen.selectionMetrics().contentLength, 'ab\ncd'.length);
    });

    test('row starts skip the newline across a soft wrap', () {
      final screen = _term(rows: 4, cols: 5);
      _feed(screen, 'abcdefg');
      final metrics = screen.selectionMetrics();

      // Viewport row 1 continues row 0's wrapped line, so it begins right
      // after the five chars of row 0 — no newline between them.
      expect(metrics.rowStarts[0], 0);
      expect(metrics.rowStarts[1], 5);
    });
  });

  // The history half answers from a running count and only the viewport is
  // walked, so the two halves have to agree about every rule the walk
  // applies at the seam between them.
  group('Screen.selectionContentLength', () {
    void expectMatchesText(Screen screen) => expect(
      screen.selectionContentLength(),
      screen.selectionText().text.length,
    );

    test('with nothing in history', () {
      final screen = _term(rows: 4, cols: 6);
      _feed(screen, 'ab\r\ncd');

      expect(screen.scrollbackLength, 0);
      expectMatchesText(screen);
    });

    test('with history under a live viewport', () {
      final screen = _term(rows: 3, cols: 8);
      _feed(screen, List.generate(12, (i) => 'line $i').join('\r\n'));

      expect(screen.scrollbackLength, greaterThan(0));
      expectMatchesText(screen);
    });

    test('with the viewport carrying the tail line onward', () {
      final screen = _term(rows: 2, cols: 6);
      // One logical line long enough to scroll its head into history while
      // the viewport still continues it.
      _feed(screen, 'abcdefghijklmnopqr');

      expect(screen.scrollbackLength, greaterThan(0));
      expectMatchesText(screen);
    });

    test('with a wide cluster giving up a column at the seam', () {
      final screen = _term(rows: 2, cols: 7);
      // The wide clusters force breaks that hand a column back rather than
      // split them, so the stored rows fall short of the margin.
      _feed(screen, '日本語テキストあいう');

      expectMatchesText(screen);
    });

    test('with history and a cleared viewport', () {
      final screen = _term(rows: 3, cols: 8);
      _feed(screen, List.generate(12, (i) => 'line $i').join('\r\n'));
      _feed(screen, '\x1b[2J');

      expect(screen.scrollbackLength, greaterThan(0));
      expectMatchesText(screen);
    });

    test('with a cleared viewport under history ending in blank rows', () {
      final screen = _term(rows: 3, cols: 9);
      _feed(screen, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxa');
      // Blanks that wrap: the rows above the last one are inside the line,
      // so their padding is content even though every cell is blank.
      _feed(screen, ' ' * 27);
      _feed(screen, '\x1b[2J');

      expectMatchesText(screen);
    });

    test('on the alt screen, which keeps no history', () {
      final screen = _term(rows: 3, cols: 8);
      _feed(screen, List.generate(12, (i) => 'line $i').join('\r\n'));
      _feed(screen, '\x1b[?1049h');
      _feed(screen, 'alt text');

      expect(screen.onAltScreen, isTrue);
      expectMatchesText(screen);
    });

    test('after a width resize has re-wrapped history', () {
      final screen = _term(rows: 3, cols: 8);
      _feed(
        screen,
        List.generate(12, (i) => 'line $i is a bit long').join(
          '\r\n',
        ),
      );
      screen.resize(rows: 3, cols: 5);
      expectMatchesText(screen);

      screen.resize(rows: 3, cols: 17);
      expectMatchesText(screen);
    });

    test('once history has started evicting', () {
      final screen = Screen(rows: 3, cols: 8, scrollbackBytes: 600);
      for (var i = 0; i < 30; i++) {
        _feed(screen, 'line $i\r\n');
        expectMatchesText(screen);
      }

      expect(screen.evictedSelectionChars, greaterThan(0));
    });
  });
}
