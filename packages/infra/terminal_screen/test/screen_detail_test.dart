// Repeated setup statements are easier to scan than cascades in these tests.
// ignore_for_file: cascade_invocations, avoid_redundant_argument_values
// String composition keeps these expected terminal lines visually aligned.
// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _feed(
  String input, {
  int rows = 6,
  int cols = 20,
  Sink<List<int>>? outbound,
}) {
  final screen = Screen(
    rows: rows,
    cols: cols,
    scrollbackBytes: 0 * 4096,
    outbound: outbound,
  );
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

class _CollectingSink implements Sink<List<int>> {
  final List<String> messages = [];
  @override
  void add(List<int> data) => messages.add(String.fromCharCodes(data));
  @override
  void close() {}
}

void main() {
  group('CSI cursor movement', () {
    test('CUU / CUD / CUF / CUB', () {
      final s = _feed('\x1B[5;5H\x1B[2A\x1B[2B\x1B[3C\x1B[2D');
      expect(s.cursor.row, 4);
      expect(s.cursor.col, 5);
    });

    test('CNL / CPL move to column 0', () {
      final s = _feed('\x1B[3;10H\x1B[1E');
      expect(s.cursor.row, 3);
      expect(s.cursor.col, 0);
      final s2 = _feed('\x1B[3;10H\x1B[1F');
      expect(s2.cursor.row, 1);
      expect(s2.cursor.col, 0);
    });

    test('CHA / VPA absolute positioning', () {
      final s = _feed('\x1B[3;3H\x1B[7G');
      expect(s.cursor.col, 6);
      final s2 = _feed('\x1B[3;3H\x1B[5d');
      expect(s2.cursor.row, 4);
    });

    test('HPA / HPR / VPR', () {
      final s = _feed('\x1B[1;1H\x1B[5`');
      expect(s.cursor.col, 4);
      final s2 = _feed('\x1B[1;1H\x1B[3a');
      expect(s2.cursor.col, 3);
      final s3 = _feed('\x1B[1;1H\x1B[2e');
      expect(s3.cursor.row, 2);
    });

    test('cursor clamps at edges', () {
      final s = _feed('\x1B[1;1H\x1B[100A\x1B[100D');
      expect(s.cursor.row, 0);
      expect(s.cursor.col, 0);
    });
  });

  group('Erase operations', () {
    test('ED 0 erases from cursor to end of display', () {
      final s = _feed('abc\r\ndef\r\nghi\x1B[1;2H\x1B[0J');
      expect(_row(s, 0), 'a');
      expect(_row(s, 1), '');
      expect(_row(s, 2), '');
    });

    test('ED 1 erases from start of display to cursor', () {
      final s = _feed('abc\r\ndef\r\nghi\x1B[3;2H\x1B[1J');
      expect(_row(s, 0), '');
      expect(_row(s, 1), '');
      expect(_row(s, 2).trimLeft(), 'i');
    });

    test('ED 3 drops the history and leaves the display alone', () {
      // `ESC[3J` asks for the saved lines and nothing else, which is why a
      // full clear is spelled `ESC[3J ESC[2J`. See erase_scrollback_test for
      // what it does to a screen that actually keeps history.
      final s = _feed('abc\r\ndef\x1B[3J');
      expect(_row(s, 0), 'abc');
      expect(_row(s, 1), 'def');
    });

    test('EL 1 erases from start of line to cursor', () {
      final s = _feed('abcdef\x1B[4G\x1B[1K');
      expect(_row(s, 0).trimLeft(), 'ef');
    });

    test('EL 2 erases the whole line', () {
      final s = _feed('abcdef\x1B[2K');
      expect(_row(s, 0), '');
    });

    test('ECH erases N characters', () {
      final s = _feed('abcdef\x1B[1;2H\x1B[3X');
      // a<space><space><space>ef
      expect(s.cellAt(0, 0).char, 'a');
      expect(s.cellAt(0, 1).char, ' ');
      expect(s.cellAt(0, 2).char, ' ');
      expect(s.cellAt(0, 3).char, ' ');
      expect(s.cellAt(0, 4).char, 'e');
    });

    test('ICH inserts blank characters', () {
      final s = _feed('hello\x1B[1;2H\x1B[3@');
      expect(s.cellAt(0, 0).char, 'h');
      expect(s.cellAt(0, 1).char, ' ');
      expect(s.cellAt(0, 4).char, 'e');
    });

    test('DCH deletes characters', () {
      final s = _feed('hello\x1B[1;2H\x1B[2P');
      expect(_row(s, 0), 'hlo');
    });
  });

  group('Lines + scroll', () {
    test('IL inserts blank lines', () {
      final s = _feed('a\r\nb\r\nc\x1B[2;1H\x1B[1L');
      expect(_row(s, 0), 'a');
      expect(_row(s, 1), '');
      expect(_row(s, 2), 'b');
    });

    test('DL deletes lines', () {
      final s = _feed('a\r\nb\r\nc\x1B[2;1H\x1B[1M');
      expect(_row(s, 0), 'a');
      expect(_row(s, 1), 'c');
    });

    test('SU scrolls up', () {
      final s = _feed('a\r\nb\r\nc\x1B[1S');
      expect(_row(s, 0), 'b');
      expect(_row(s, 1), 'c');
    });

    test('SD scrolls down', () {
      final s = _feed('a\r\nb\r\nc\x1B[1;1H\x1B[1T');
      expect(_row(s, 1), 'a');
    });

    test('DECSTBM + LF scrolls inside region', () {
      final s = _feed(
        '\x1B[2;4r\x1B[2;1Ha\r\nb\r\nc\r\nd',
        rows: 6,
      );
      // The scroll region rows 2..4 should have rotated; row 1
      // (outside region) stays blank.
      expect(_row(s, 0), '');
    });

    test('scroll past bottom evicts to scrollback', () {
      final s = Screen(rows: 3, cols: 5, scrollbackBytes: 10 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('1\r\n2\r\n3\r\n4\r\n5'));
      s.snapshot(); // flush pending grapheme
      expect(s.scrollbackLength, greaterThan(0));
      expect(_row(s, 2), '5');
    });
  });

  group('Tab stops', () {
    test('default 8-column tab stops', () {
      final s = _feed('\x1B[1;1H\tX', cols: 20);
      expect(s.cellAt(0, 8).char, 'X');
    });

    test('HTS sets a custom tab stop', () {
      final s = _feed('\x1B[1;5H\x1BH\x1B[1;1H\tX', cols: 20);
      expect(s.cellAt(0, 4).char, 'X');
    });

    test('CBT moves backward by N tab stops', () {
      final s = _feed('\x1B[1;17H\x1B[2Z', cols: 24);
      expect(s.cursor.col, 0);
    });

    test('TBC 3 clears all tab stops', () {
      final s = _feed('\x1B[3g\x1B[1;1H\tX', cols: 20);
      // With no tab stops, tab moves to last column - 1.
      expect(s.cellAt(0, 19).char, 'X');
    });
  });

  group('Modes', () {
    test('DECAWM off prevents wrap', () {
      final s = _feed('\x1B[?7l' + 'a' * 15, cols: 10);
      // All characters land in row 0 (last one overwrites in the
      // final column because DECAWM is off).
      expect(_row(s, 1), '');
    });

    test('DECTCEM hides the cursor', () {
      final s = _feed('\x1B[?25l');
      expect(s.cursor.visible, isFalse);
      expect(s.modes.cursorVisible, isFalse);
    });

    test('DECOM constrains cursor to scroll region', () {
      final s = _feed('\x1B[2;4r\x1B[?6h\x1B[1;1H', rows: 6);
      expect(s.cursor.row, 1); // row 1 of origin = viewport row 1
    });

    test('insert mode shifts existing cells on print', () {
      final s = _feed('abc\x1B[1;2H\x1B[4hx');
      expect(_row(s, 0), 'axbc');
    });

    test('bracketed paste flag', () {
      final s = _feed('\x1B[?2004h');
      expect(s.modes.bracketedPaste, isTrue);
    });

    test('mouse tracking modes set flags', () {
      expect(_feed('\x1B[?1000h').modes.mouseMode, MouseMode.vt200);
      expect(_feed('\x1B[?1002h').modes.mouseMode, MouseMode.buttonEvent);
      expect(_feed('\x1B[?1003h').modes.mouseMode, MouseMode.anyEvent);
      expect(_feed('\x1B[?9h').modes.mouseMode, MouseMode.x10);
    });

    test('mouse encoding modes set flags', () {
      expect(_feed('\x1B[?1005h').modes.mouseEncoding, MouseEncoding.utf8);
      expect(_feed('\x1B[?1006h').modes.mouseEncoding, MouseEncoding.sgr);
      expect(_feed('\x1B[?1015h').modes.mouseEncoding, MouseEncoding.urxvt);
    });

    test('focus + reverse video + blink', () {
      final s = _feed('\x1B[?1004h\x1B[?5h\x1B[?12h');
      expect(s.modes.focusReport, isTrue);
      expect(s.modes.reverseVideo, isTrue);
      expect(s.modes.cursorBlink, isTrue);
    });

    test('insert mode via ANSI SM 4', () {
      final s = _feed('\x1B[4h');
      expect(s.modes.insertMode, isTrue);
    });

    test('cursor keys app mode', () {
      final s = _feed('\x1B[?1h');
      expect(s.modes.cursorKeysApp, isTrue);
    });
  });

  group('SGR comprehensive', () {
    test('bold / faint / italic / underline / blink / inverse', () {
      final s = _feed('\x1B[1;2;3;4;5;7mA');
      final attrs = s.cellAt(0, 0).attrs;
      expect(CellAttrs.isBold(attrs), isTrue);
      expect(CellAttrs.isFaint(attrs), isTrue);
      expect(CellAttrs.isItalic(attrs), isTrue);
      expect(CellAttrs.hasUnderline(attrs), isTrue);
      expect(CellAttrs.isBlink(attrs), isTrue);
      expect(CellAttrs.isInverse(attrs), isTrue);
    });

    test('SGR 21 maps to double underline style 2', () {
      final s = _feed('\x1B[21mA');
      expect(
        CellAttrs.underlineStyle(s.cellAt(0, 0).attrs),
        UnderlineStyle.double_,
      );
    });

    test('SGR 4:3 sets curly underline', () {
      final s = _feed('\x1B[4:3mA');
      expect(
        CellAttrs.underlineStyle(s.cellAt(0, 0).attrs),
        UnderlineStyle.curly,
      );
    });

    test('individual resets clear their bits', () {
      final s = _feed('\x1B[1;3;4;5;7;8;9mA\x1B[22;23;24;25;27;28;29mB');
      expect(s.cellAt(0, 1).attrs, 0);
    });

    test('8 / 9 invisible / strike set + reset', () {
      final s = _feed('\x1B[8;9mA');
      expect(CellAttrs.isInvisible(s.cellAt(0, 0).attrs), isTrue);
      expect(CellAttrs.isStrikethrough(s.cellAt(0, 0).attrs), isTrue);
    });

    test('bright foreground 90..97 maps to index 8..15', () {
      final s = _feed('\x1B[92mA');
      expect(s.cellAt(0, 0).fg, const IndexedColor(10));
    });

    test('bright background 100..107 maps to index 8..15', () {
      final s = _feed('\x1B[102mA');
      expect(s.cellAt(0, 0).bg, const IndexedColor(10));
    });

    test('SGR 48;5;N sets indexed background', () {
      final s = _feed('\x1B[48;5;42mA');
      expect(s.cellAt(0, 0).bg, const IndexedColor(42));
    });

    test('SGR 48;2;r;g;b sets truecolor background', () {
      final s = _feed('\x1B[48;2;1;2;3mA');
      expect(s.cellAt(0, 0).bg, const RgbColor(1, 2, 3));
    });

    test('SGR 39 / 49 reset fg / bg to defaults', () {
      final s = _feed('\x1B[31;41mA\x1B[39;49mB');
      expect(s.cellAt(0, 1).fg, Color.defaultFg);
      expect(s.cellAt(0, 1).bg, Color.defaultBg);
    });

    test('SGR 6 is rapid blink → blink', () {
      final s = _feed('\x1B[6mA');
      expect(CellAttrs.isBlink(s.cellAt(0, 0).attrs), isTrue);
    });

    test('SGR 58 parses underline color without crashing', () {
      final s = _feed('\x1B[58;5;5mA');
      expect(_row(s, 0), 'A');
    });

    test('SGR 58 truecolor subparam form', () {
      final s = _feed('\x1B[58:2:10:20:30mA');
      expect(_row(s, 0), 'A');
    });

    test('SGR 59 default underline color', () {
      final s = _feed('\x1B[59mA');
      expect(_row(s, 0), 'A');
    });

    test('unknown SGR is silently ignored', () {
      final s = _feed('\x1B[99mA');
      expect(_row(s, 0), 'A');
    });
  });

  group('ESC sequences', () {
    test('DECSC / DECRC save and restore the pen', () {
      // Trace:
      //   SGR 31 (red) → A printed red at (0,0) cursor→(0,1)
      //   ESC 7        → save cursor(0,1) + pen(red)
      //   SGR 32       → pen green
      //   B printed at (0,1) green, cursor→(0,2)
      //   ESC 8        → restore cursor to (0,1) + pen red
      //   C printed at (0,1) overwriting B, in red
      final s = _feed('\x1B[31mA\x1B7\x1B[32mB\x1B8C');
      expect(s.cellAt(0, 0).fg, const IndexedColor(1)); // A red
      expect(s.cellAt(0, 1).char, 'C');
      expect(s.cellAt(0, 1).fg, const IndexedColor(1)); // C red
    });

    test('IND / NEL / RI move cursor vertically', () {
      final s = _feed('\x1B[3;3H\x1BD');
      expect(s.cursor.row, 3);
      final s2 = _feed('\x1B[3;3H\x1BE');
      expect(s2.cursor.row, 3);
      expect(s2.cursor.col, 0);
      final s3 = _feed('\x1B[3;3H\x1BM');
      expect(s3.cursor.row, 1);
    });

    test('RIS full reset', () {
      final s = _feed('\x1B[31mhello\x1B[?25l\x1Bc');
      expect(s.cursor.visible, isTrue);
      expect(s.cellAt(0, 0).char, ' ');
    });

    test('ESC ( B charset designator is a no-op', () {
      final s = _feed('\x1B(BX');
      expect(s.cellAt(0, 0).char, 'X');
    });
  });

  group('CSI u / CSI s save+restore', () {
    test('SCOSC / SCORC round-trips position', () {
      final s = _feed('\x1B[3;4H\x1B[s\x1B[1;1H\x1B[u');
      expect(s.cursor.row, 2);
      expect(s.cursor.col, 3);
    });
  });

  group('DECSTR (soft reset)', () {
    test('soft reset clears scroll region and modes', () {
      final s = _feed('\x1B[2;4r\x1B[?6h\x1B[!p\x1B[1;1Ha');
      expect(_row(s, 0), 'a');
      expect(s.modes.originMode, isFalse);
    });
  });

  group('DECSCUSR', () {
    test('set cursor style variants', () {
      expect(_feed('\x1B[0 q').cursor.style, CursorStyle.block);
      expect(_feed('\x1B[2 q').cursor.style, CursorStyle.block);
      expect(_feed('\x1B[3 q').cursor.style, CursorStyle.underline);
      expect(_feed('\x1B[4 q').cursor.style, CursorStyle.underline);
      expect(_feed('\x1B[5 q').cursor.style, CursorStyle.bar);
      expect(_feed('\x1B[6 q').cursor.style, CursorStyle.bar);
    });
  });

  group('Outbound replies', () {
    test('DA1 reply', () {
      final sink = _CollectingSink();
      _feed('\x1B[c', outbound: sink);
      expect(sink.messages.single, '\x1B[?62;22c');
    });

    test('DA2 reply', () {
      final sink = _CollectingSink();
      _feed('\x1B[>c', outbound: sink);
      expect(sink.messages.single, '\x1B[>0;0;0c');
    });

    test('DA3 reply', () {
      final sink = _CollectingSink();
      _feed('\x1B[=c', outbound: sink);
      expect(sink.messages.single, contains('00000000'));
    });

    test('DSR 5 replies with OK', () {
      final sink = _CollectingSink();
      _feed('\x1B[5n', outbound: sink);
      expect(sink.messages.single, '\x1B[0n');
    });

    test('DSR 6 with origin mode', () {
      final sink = _CollectingSink();
      _feed('\x1B[3;5r\x1B[?6h\x1B[2;3H\x1B[6n', outbound: sink);
      // Origin-mode cursor position is relative to scroll region
      // top, 1-indexed.
      expect(sink.messages.last, contains('R'));
    });

    test('DECXCPR via CSI ?6n', () {
      final sink = _CollectingSink();
      _feed('\x1B[3;4H\x1B[?6n', outbound: sink);
      expect(sink.messages.single, '\x1B[?3;4;0R');
    });

    test('OSC 10/11 fg/bg queries', () {
      final sink = _CollectingSink();
      _feed('\x1B]10;?\x07', outbound: sink);
      expect(sink.messages.single, startsWith('\x1B]10;'));
      final sink2 = _CollectingSink();
      _feed('\x1B]11;?\x07', outbound: sink2);
      expect(sink2.messages.single, startsWith('\x1B]11;'));
    });

    test('OSC 4 palette query', () {
      final sink = _CollectingSink();
      _feed('\x1B]4;1;?\x07', outbound: sink);
      expect(sink.messages.single, startsWith('\x1B]4;1;rgb:'));
    });

    test('OSC 4 palette query with unknown index silently drops', () {
      final sink = _CollectingSink();
      _feed('\x1B]4;200;?\x07', outbound: sink);
      expect(sink.messages, isEmpty);
    });
  });

  group('Alt screen + scrollback', () {
    test('DEC 47 / 1047 (legacy alt screen)', () {
      final s = _feed('hello\x1B[?47h');
      expect(s.onAltScreen, isTrue);
    });

    test('DEC 1048 saves cursor without switching', () {
      final s = _feed('\x1B[3;5H\x1B[?1048h');
      expect(s.onAltScreen, isFalse);
    });

    test('DEC 1049 clears alt buffer on entry', () {
      final s = Screen(rows: 3, cols: 5, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('\x1B[?1049h'));
      parser.advance(utf8.encode('hi'));
      parser.advance(utf8.encode('\x1B[?1049h')); // re-enter
      expect(_row(s, 0), 'hi'); // already in alt, no-op
    });

    test('scrollback cells are readable via scrollbackCellAt', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 4 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('abc\r\ndef\r\nghi'));
      expect(s.scrollbackLength, greaterThan(0));
      expect(s.scrollbackCellAt(0, 0).char, anyOf('a', ' '));
    });
  });

  group('Resize', () {
    test('grow width pads, grow height adds rows', () {
      final s = _feed('hi', cols: 5, rows: 2);
      s.resize(rows: 4, cols: 10);
      expect(s.rows, 4);
      expect(s.cols, 10);
    });

    test('shrink clamps cursor', () {
      final s = _feed('\x1B[4;8H', cols: 10, rows: 5);
      s.resize(rows: 3, cols: 5);
      expect(s.cursor.row, lessThan(3));
      expect(s.cursor.col, lessThan(5));
    });

    test('preserves scrollback across resize', () {
      // Push enough lines to populate scrollback; then resize and
      // confirm the scrollback content survives.
      final s = Screen(rows: 3, cols: 6, scrollbackBytes: 20 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('aaa\r\nbbb\r\nccc\r\nddd\r\neee\r\nfff'));
      expect(s.scrollbackLength, greaterThan(0));
      final preFirstChar = s.scrollbackCellAt(0, 0).char;

      s.resize(rows: 4, cols: 8);
      expect(s.scrollbackLength, greaterThan(0));
      expect(s.scrollbackCellAt(0, 0).char, preFirstChar);
    });

    test('a taller viewport pulls history back down into view', () {
      // Every line is still held; one crosses the seam rather than the
      // viewport gaining a blank row under content it already had.
      final s = Screen(rows: 3, cols: 6, scrollbackBytes: 20 * 4096);
      VtParser(
        sink: s,
      ).advance(utf8.encode('aaa\r\nbbb\r\nccc\r\nddd\r\neee\r\nfff'));
      expect(s.scrollbackLength, 3);

      s.resize(rows: 4, cols: 8);

      expect(s.scrollbackLength, 2);
      expect(s.snapshot().text.split('\n'), ['ccc', 'ddd', 'eee', 'fff']);
    });

    test('top-anchored region scroll-up evicts to scrollback (ratatui)', () {
      // Reproduce ratatui's inline-mode `insert_before` scroll
      // pattern: a top-anchored region [1..N] (DECSTBM 1;N) is
      // scrolled up via SU. The top row should land in scrollback
      // so chat history above the inline viewport is preserved.
      final s = Screen(rows: 6, cols: 4, scrollbackBytes: 20 * 4096);
      final parser = VtParser(sink: s);
      // Fill rows so we can verify which one ends up in scrollback.
      parser.advance(
        utf8.encode('AAAA\r\nBBBB\r\nCCCC\r\nDDDD\r\nEEEE\r\nFFFF'),
      );
      // Sanity: cursor at end, no scrollback yet (last \r\n bumped
      // the cursor but didn't overflow yet).
      final preLen = s.scrollbackLength;

      // Set scroll region 1..4 (rows 0..3 inclusive), then SU 1.
      parser.advance(utf8.encode('\x1B[1;4r\x1B[1S'));

      expect(
        s.scrollbackLength,
        preLen + 1,
        reason: 'top-anchored partial region scroll must grow scrollback',
      );
      // Verify the row that fell off was the top of the region.
      final newest = s.scrollbackCellAt(s.scrollbackLength - 1, 0).char;
      expect(newest, 'A');
      // Rows below the region (rows 4 and 5) must NOT have shifted.
      // Originally row 4 had EEEE and row 5 was where 'FFFF' ended
      // up after the auto-wrap from the final '\r\nFFFF'.
      expect(s.cellAt(4, 0).char, 'E');
    });

    test('preserves scrollback when shrinking width (truncates cells)', () {
      final s = Screen(rows: 2, cols: 8, scrollbackBytes: 20 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('abcdefgh\r\n12345678\r\nXY\r\nZZ'));
      expect(s.scrollbackLength, greaterThan(0));

      s.resize(rows: 2, cols: 4);
      // The first scrollback line had "abcdefgh"; after shrinking
      // we keep the first 4 cols.
      expect(s.scrollbackCellAt(0, 0).char, 'a');
      expect(s.scrollbackCellAt(0, 3).char, 'd');
    });

    test('no-op resize is cheap', () {
      final s = Screen(rows: 3, cols: 5, scrollbackBytes: 0 * 4096);
      s.resize(rows: 3, cols: 5);
      expect(s.rows, 3);
    });
  });

  group('waitFor variants', () {
    test('waitForRegex matches visible text', () async {
      final s = Screen(rows: 2, cols: 20, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);
      final fut = s.waitForRegex(
        RegExp(r'\d\d\d'),
        timeout: const Duration(seconds: 5),
      );
      parser.advance(utf8.encode('abc123'));
      final snap = await fut;
      expect(snap.text, contains('123'));
    });

    test('waitForRegion evaluates a rectangle', () async {
      final s = Screen(rows: 3, cols: 10, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: s);
      final fut = s.waitForRegion(
        const Region(row: 0, col: 0, height: 1, width: 5),
        (t) => t.contains('ok'),
        timeout: const Duration(seconds: 5),
      );
      parser.advance(utf8.encode('ok'));
      final snap = await fut;
      expect(
        snap.textIn(const Region(row: 0, col: 0, height: 1, width: 5)),
        contains('ok'),
      );
    });

    test('waitForText times out if nothing appears', () async {
      final s = Screen(rows: 2, cols: 5, scrollbackBytes: 0 * 4096);
      expect(
        () => s.waitForText('nope', timeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('waitForText with includeScrollback', () async {
      final s = Screen(rows: 2, cols: 5, scrollbackBytes: 10 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('AAAAA\r\nBBBBB\r\nCCCCC\r\nDDDDD'));
      final snap = await s.waitForText(
        'AAAAA',
        includeScrollback: true,
        timeout: const Duration(seconds: 1),
      );
      expect(snap, isNotNull);
    });
  });

  group('dirty tracking', () {
    test('dirty rows are returned and cleared', () {
      final s = _feed('hi');
      expect(s.dirtyRows, isNotEmpty);
      s.clearDirty();
      expect(s.dirtyRows, isEmpty);
    });
  });

  group('snapshot with scrollback', () {
    test('includeScrollback returns scrollback lines', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('a\r\nb\r\nc'));
      final snap = s.snapshot(includeScrollback: true);
      expect(snap.scrollback, isNotNull);
    });

    test('textIn returns a region', () {
      final s = _feed('ab\r\ncd');
      final snap = s.snapshot();
      expect(
        snap.textIn(const Region(row: 0, col: 0, height: 2, width: 2)),
        'ab\ncd',
      );
    });
  });

  group('viewport scroll offset', () {
    test('starts at zero and is bounded by scrollback length', () {
      final s = Screen(rows: 3, cols: 4, scrollbackBytes: 10 * 4096);
      expect(s.viewOffset, 0);
      expect(s.maxViewOffset, 0);

      VtParser(sink: s).advance(utf8.encode('a\r\nb\r\nc\r\nd\r\ne'));
      expect(s.scrollbackLength, greaterThan(0));
      expect(s.maxViewOffset, s.scrollbackLength);
    });

    test('setViewOffset clamps to [0, maxViewOffset]', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      VtParser(sink: s).advance(utf8.encode('a\r\nb\r\nc\r\nd'));
      final maxOffset = s.maxViewOffset;
      expect(s.setViewOffset(-5), 0);
      expect(s.setViewOffset(maxOffset + 100), maxOffset);
    });

    test('viewportCellAt reads scrollback when scrolled', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      VtParser(sink: s).advance(utf8.encode('ab\r\ncd\r\nef\r\ngh'));
      // After feeding 4 lines into a 2-row buffer, the 2 oldest
      // lines (ab, cd) should be in scrollback. With viewOffset = 2
      // the viewport top should map to those scrollback lines.
      s.setViewOffset(2);
      expect(s.viewportCellAt(0, 0).char, 'a');
      expect(s.viewportCellAt(1, 0).char, 'c');
    });

    test('snapshot ignores scroll offset (agent observation is live)', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      VtParser(sink: s).advance(utf8.encode('ab\r\ncd\r\nef\r\ngh'));
      s.setViewOffset(2);
      // Snapshot must return the live viewport regardless of where
      // a human happens to be paging.
      expect(s.snapshot().text, contains('ef'));
      expect(s.snapshot().text, contains('gh'));
    });

    test('output preserves visible content while user is scrolled up', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 10 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('ab\r\ncd\r\nef\r\ngh'));
      // Pin the user's view to "ab" / "cd".
      s.setViewOffset(2);
      final beforeRow0 = s.viewportCellAt(0, 0).char;
      final beforeRow1 = s.viewportCellAt(1, 0).char;
      // New output causes another eviction.
      parser.advance(utf8.encode('\r\nij'));
      expect(s.viewportCellAt(0, 0).char, beforeRow0);
      expect(s.viewportCellAt(1, 0).char, beforeRow1);
    });

    test('switching to alt screen forces offset back to zero', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('ab\r\ncd\r\nef'));
      s.setViewOffset(1);
      parser.advance(utf8.encode('\x1B[?1049h'));
      expect(s.viewOffset, 0);
      expect(s.maxViewOffset, 0); // alt buffer has no scrollback
    });

    test('hard reset clears the offset', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('ab\r\ncd\r\nef'));
      s.setViewOffset(1);
      parser.advance(utf8.encode('\x1Bc'));
      expect(s.viewOffset, 0);
    });
  });

  group('DECRC after a resize', () {
    // A saved position is only relocated with the buffer that saved it, and
    // the alt screen's is not relocated at all — so restoring one can name a
    // cell the grid no longer has, and the next print writes out of bounds.
    Screen shrunkAfterSaving(String save) {
      final screen = Screen(rows: 10, cols: 40, scrollbackBytes: 1 << 16);
      VtParser(sink: screen).advance(utf8.encode(save));
      screen
        ..snapshot()
        ..resize(rows: 4, cols: 10);
      return screen;
    }

    void expectRestoreStaysInside(Screen screen) {
      final parser = VtParser(sink: screen)..advance(utf8.encode('\x1b8'));
      expect(screen.cursor.row, lessThan(screen.rows));
      expect(screen.cursor.col, lessThan(screen.cols));
      parser.advance(utf8.encode('x'));
      screen.snapshot();
    }

    test('from a position saved on the main screen', () {
      expectRestoreStaysInside(shrunkAfterSaving('\x1b[9;35H\x1b7'));
    });

    test('from a position saved on the alt screen', () {
      expectRestoreStaysInside(shrunkAfterSaving('\x1b[?1049h\x1b[9;35H\x1b7'));
    });

    test('from a position the alt screen saved on the way in', () {
      expectRestoreStaysInside(shrunkAfterSaving('\x1b[9;35H\x1b[?1049h'));
    });
  });

  group('mutationCount', () {
    test('starts at zero', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 0 * 4096);
      expect(s.mutationCount, 0);
    });

    test('bumps on print', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 0 * 4096);
      final before = s.mutationCount;
      VtParser(sink: s).advance(utf8.encode('hi'));
      // snapshot() flushes pending graphemes — also a mutation source.
      s.snapshot();
      expect(s.mutationCount, greaterThan(before));
    });

    test('bumps on resize', () {
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 0 * 4096);
      final before = s.mutationCount;
      s.resize(rows: 3, cols: 4);
      expect(s.mutationCount, greaterThan(before));
    });

    test('does not bump on scroll-only viewport offset change', () {
      // Viewport scroll affects rendering but not observable grid
      // state, so consumers caching grid-derived projections shouldn't
      // be invalidated by a scroll.
      final s = Screen(rows: 2, cols: 3, scrollbackBytes: 5 * 4096);
      final parser = VtParser(sink: s);
      parser.advance(utf8.encode('ab\r\ncd\r\nef\r\ngh'));
      final beforeScroll = s.mutationCount;
      s.setViewOffset(1);
      expect(s.mutationCount, beforeScroll);
    });
  });
}
