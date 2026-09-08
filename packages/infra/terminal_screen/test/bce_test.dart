import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _feed(String input, {int rows = 4, int cols = 10}) {
  final screen = Screen(rows: rows, cols: cols, scrollbackBytes: 0 * 4096);
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
  return screen;
}

void main() {
  group('background color erase', () {
    test('erase-to-end-of-line fills trailing cells with the current bg', () {
      // bg red (SGR 41), write abc, then erase from the cursor to EOL.
      final s = _feed('\x1B[41mabc\x1B[K');

      expect(s.cellAt(0, 2).bg, const IndexedColor(1)); // the 'c'
      expect(s.cellAt(0, 5).bg, const IndexedColor(1)); // erased trailing
      expect(s.cellAt(0, 9).bg, const IndexedColor(1)); // erased trailing
    });

    test('full-line erase fills the whole row with the current bg', () {
      final s = _feed('\x1B[42m\x1B[2K');

      expect(s.cellAt(0, 0).bg, const IndexedColor(2));
      expect(s.cellAt(0, 9).bg, const IndexedColor(2));
    });

    test('erase-chars fills only the erased span, leaving the rest', () {
      // Write with the default bg, then set bg, home, and erase 3 chars.
      final s = _feed('abcdef\x1B[45m\x1B[1;1H\x1B[3X');

      expect(s.cellAt(0, 0).bg, const IndexedColor(5));
      expect(s.cellAt(0, 2).bg, const IndexedColor(5));
      expect(s.cellAt(0, 3).bg, isA<DefaultBackground>()); // 'd' untouched
    });

    test('erase without a background set stays default', () {
      final s = _feed('abc\x1B[K');

      expect(s.cellAt(0, 5).bg, isA<DefaultBackground>());
    });

    test('scrolling fills the newly exposed line with the current bg', () {
      // bg blue (SGR 44), move to the bottom row, LF scrolls: the new bottom
      // line is background-color-erased, not reset to default.
      final s = _feed('\x1B[44m\x1B[3;1H\n', rows: 3);

      expect(s.cellAt(2, 0).bg, const IndexedColor(4));
      expect(s.cellAt(2, 5).bg, const IndexedColor(4));
    });
  });
}
