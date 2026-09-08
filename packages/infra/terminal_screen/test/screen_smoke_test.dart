// Repeated setup statements are easier to scan than cascades in these tests.
// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

/// End-to-end-ish smoke: drive bytes through VtParser → Screen
/// and assert on the resulting grid state. This is the cheapest
/// way to catch "I broke something fundamental" regressions.
Screen _feed(String input, {int rows = 6, int cols = 20}) {
  final screen = Screen(rows: rows, cols: cols, scrollbackBytes: 0 * 4096);
  VtParser(sink: screen).advance(utf8.encode(input));
  // Force flush of the grapheme buffer so cellAt sees everything.
  screen.snapshot();
  return screen;
}

String _row(Screen s, int r) {
  final buf = StringBuffer();
  for (var c = 0; c < s.cols; c++) {
    final cell = s.cellAt(r, c);
    if (cell.width == CellWidth.continuation) continue;
    buf.write(cell.char);
  }
  return buf.toString().trimRight();
}

void main() {
  group('print + LF', () {
    test('plain ASCII lands in row 0', () {
      final s = _feed('hello');
      expect(_row(s, 0), 'hello');
      expect(s.cursor.row, 0);
      expect(s.cursor.col, 5);
    });

    test('CR + LF moves to next line', () {
      final s = _feed('hi\r\nbye');
      expect(_row(s, 0), 'hi');
      expect(_row(s, 1), 'bye');
    });

    test('auto-wrap at right margin carries to next line', () {
      final s = _feed('1234567890abcdefghij!', cols: 10);
      expect(_row(s, 0), '1234567890');
      expect(_row(s, 1), 'abcdefghij');
      expect(_row(s, 2), '!');
    });
  });

  group('CSI cursor + erase', () {
    test('CUP moves the cursor (1-indexed)', () {
      final s = _feed('\x1B[3;5Hx');
      expect(s.cursor.row, 2);
      expect(s.cursor.col, 5);
      expect(s.cellAt(2, 4).char, 'x');
    });

    test('ED 2 clears entire display', () {
      final s = _feed('hi\r\nbye\x1B[2J');
      expect(_row(s, 0), '');
      expect(_row(s, 1), '');
    });

    test('EL 0 clears from cursor to end of line', () {
      final s = _feed('hello\x1B[3G\x1B[0K');
      expect(_row(s, 0), 'he');
    });
  });

  group('SGR', () {
    test('SGR 31 sets red foreground', () {
      final s = _feed('\x1B[31mA');
      expect(s.cellAt(0, 0).fg, const IndexedColor(1));
    });

    test('SGR 38;2;r;g;b sets truecolor', () {
      final s = _feed('\x1B[38;2;10;20;30mA');
      expect(s.cellAt(0, 0).fg, const RgbColor(10, 20, 30));
    });

    test('SGR 38:2:r:g:b subparam form also works', () {
      final s = _feed('\x1B[38:2:10:20:30mA');
      expect(s.cellAt(0, 0).fg, const RgbColor(10, 20, 30));
    });

    test('SGR 0 resets', () {
      final s = _feed('\x1B[31;1mA\x1B[0mB');
      expect(s.cellAt(0, 0).fg, const IndexedColor(1));
      expect(CellAttrs.isBold(s.cellAt(0, 0).attrs), isTrue);
      expect(s.cellAt(0, 1).fg, Color.defaultFg);
      expect(CellAttrs.isBold(s.cellAt(0, 1).attrs), isFalse);
    });
  });

  group('alt screen (DEC 1049)', () {
    test('enters alt, writes, exits, main is restored', () {
      final s = Screen(rows: 4, cols: 10, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);

      parser.advance('hello'.codeUnits);
      parser.advance('\x1B[?1049h'.codeUnits);
      expect(s.onAltScreen, isTrue);

      parser.advance('GARBAGE'.codeUnits);
      s.snapshot(); // flush pending grapheme
      expect(_row(s, 0), 'GARBAGE');

      parser.advance('\x1B[?1049l'.codeUnits);
      expect(s.onAltScreen, isFalse);
      expect(_row(s, 0), 'hello');
    });
  });

  group('OSC title', () {
    test('OSC 2 sets the window title', () {
      final s = _feed('\x1B]2;my title\x07');
      expect(s.title, 'my title');
    });

    test('OSC 0 sets both title and icon', () {
      final s = _feed('\x1B]0;both\x07');
      expect(s.title, 'both');
      expect(s.iconName, 'both');
    });
  });

  group('unicode', () {
    test('CJK wide character occupies two cells', () {
      final s = _feed('\u3042x'); // あ then x
      expect(s.cellAt(0, 0).char, '\u3042');
      expect(s.cellAt(0, 0).width, CellWidth.wide);
      expect(s.cellAt(0, 1).width, CellWidth.continuation);
      expect(s.cellAt(0, 2).char, 'x');
    });

    test('combining mark stacks onto previous base cell', () {
      // 'e' + U+0301 combining acute → 'é' (single grapheme).
      final s = _feed('e\u0301');
      expect(s.cellAt(0, 0).char, 'e\u0301');
      expect(s.cursor.col, 1);
    });

    test('ZWJ emoji sequence is a single cluster', () {
      // 👨‍💻 = U+1F468 ZWJ U+1F4BB — should be ONE cell of width 2.
      final s = _feed('\u{1F468}\u200D\u{1F4BB}x');
      expect(s.cellAt(0, 0).char, '\u{1F468}\u200D\u{1F4BB}');
      expect(s.cellAt(0, 0).width, CellWidth.wide);
      expect(s.cellAt(0, 1).width, CellWidth.continuation); // continuation
      expect(s.cellAt(0, 2).char, 'x');
    });

    test('regional indicator pair forms a single flag', () {
      // 🇺🇸 = U+1F1FA U+1F1F8 — should be ONE cell of width 2.
      final s = _feed('\u{1F1FA}\u{1F1F8}x');
      expect(s.cellAt(0, 0).char, '\u{1F1FA}\u{1F1F8}');
      expect(s.cellAt(0, 0).width, CellWidth.wide);
      expect(s.cellAt(0, 1).width, CellWidth.continuation); // continuation
      expect(s.cellAt(0, 2).char, 'x');
    });
  });

  group('snapshot + text', () {
    test('snapshot.text flattens visible grid', () {
      final s = _feed('abc\r\ndef');
      expect(s.snapshot().text, 'abc\ndef');
    });

    test('snapshot is independent of live grid', () {
      final s = Screen(rows: 2, cols: 5, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);
      parser.advance('hi'.codeUnits);
      final snap = s.snapshot();
      parser.advance('\rBYE'.codeUnits);
      expect(snap.text, 'hi');
      expect(s.snapshot().text, 'BYE');
    });
  });

  group('waitFor', () {
    test('waitForText resolves when text appears', () async {
      final s = Screen(rows: 4, cols: 20, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);
      final fut = s.waitForText(
        'READY',
        timeout: const Duration(seconds: 2),
      );
      parser.advance('not yet...'.codeUnits);
      parser.advance('\rREADY'.codeUnits);
      final snap = await fut;
      expect(snap.text.contains('READY'), isTrue);
    });

    test('waitForText returns immediately if already visible', () async {
      final s = _feed('READY');
      final snap = await s.waitForText(
        'READY',
        timeout: const Duration(seconds: 5),
      );
      expect(snap.text, contains('READY'));
    });
  });

  group('outbound', () {
    test('DSR 6 replies with cursor position', () {
      final replies = <List<int>>[];
      final s = Screen(
        rows: 4,
        cols: 10,
        scrollbackBytes: 0 * 4096,
        outbound: _CollectingSink(replies),
      );
      final parser = VtParser(sink: s);
      parser.advance('\x1B[3;5H'.codeUnits);
      parser.advance('\x1B[6n'.codeUnits);
      expect(replies, hasLength(1));
      expect(
        String.fromCharCodes(replies.single),
        '\x1B[3;5R',
      );
    });

    test('DA1 replies with xterm identity', () {
      final replies = <List<int>>[];
      final s = Screen(
        rows: 4,
        cols: 10,
        scrollbackBytes: 0 * 4096,
        outbound: _CollectingSink(replies),
      );
      VtParser(sink: s).advance('\x1B[c'.codeUnits);
      expect(String.fromCharCodes(replies.single), '\x1B[?62;22c');
    });
  });
}

class _CollectingSink implements Sink<List<int>> {
  _CollectingSink(this._out);
  final List<List<int>> _out;
  @override
  void add(List<int> data) => _out.add(data);
  @override
  void close() {}
}
