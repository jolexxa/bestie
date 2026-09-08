import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

/// Fed as raw bytes so the 8-bit C1 controls arrive as the single bytes a
/// child really emits, rather than as their two-byte escape spellings.
Screen _feedBytes(
  List<int> bytes, {
  int rows = 6,
  int cols = 40,
  ResizeBehavior resizeBehavior = const ReflowingResize(),
}) {
  final screen = Screen(
    rows: rows,
    cols: cols,
    scrollbackBytes: 0 * 4096,
    resizeBehavior: resizeBehavior,
  );
  VtParser(sink: screen).advance(bytes);
  screen.snapshot();
  return screen;
}

Screen _feed(String input, {int rows = 6, int cols = 40}) =>
    _feedBytes(utf8.encode(input), rows: rows, cols: cols);

String _row(Screen screen, int row) {
  final out = StringBuffer();
  for (var col = 0; col < screen.cols; col++) {
    final cell = screen.cellAt(row, col);
    if (cell.width == CellWidth.continuation) continue;
    out.write(cell.char);
  }
  return out.toString().trimRight();
}

void main() {
  group('backspace', () {
    test('moves the cursor one column left', () {
      final screen = _feed('ab\x08');

      expect(screen.cursor.col, 1);
    });

    // Backspace is a cursor move, not an erase: the column it left keeps
    // whatever was printed there.
    test('leaves the character it moved off', () {
      final screen = _feed('ab\x08');

      expect(_row(screen, 0), 'ab');
    });

    test('stops at the left margin rather than wrapping backwards', () {
      final screen = _feed('\x08');

      expect(screen.cursor.col, 0);
    });
  });

  group('8-bit C1 controls', () {
    test('NEL starts the next line at the left margin', () {
      final screen = _feedBytes([...utf8.encode('ab'), 0x85]);

      expect(screen.cursor.row, 1);
      expect(screen.cursor.col, 0);
    });

    test('HTS sets a tab stop where the cursor is', () {
      // Column 4 (1-based) is not one of the default every-eighth stops, so
      // a tab landing there can only be the stop HTS just set.
      final screen = _feedBytes([
        ...utf8.encode('\x1B[4G'),
        0x88,
        ...utf8.encode('\r\t'),
      ]);

      expect(screen.cursor.col, 3);
    });

    test('RI moves up a line when there is one above', () {
      final screen = _feedBytes([...utf8.encode('\x1B[3;1H'), 0x8D]);

      expect(screen.cursor.row, 1);
    });

    // At the top of the scroll region there is nothing to move up into, so
    // the region scrolls down and opens a blank line instead.
    test('RI at the top of the region scrolls the content down', () {
      final screen = _feedBytes([
        ...utf8.encode('top\x1B[1;1H'),
        0x8D,
      ]);

      expect(_row(screen, 0), isEmpty);
      expect(_row(screen, 1), 'top');
    });
  });

  group('tabulation', () {
    test('CHT advances by whole tab stops', () {
      final screen = _feed('\x1B[2I');

      expect(screen.cursor.col, 16);
    });

    test('clearing the stop under the cursor makes tabs skip past it', () {
      // Column 8 is a default stop; drop it and the next tab from home has
      // to run on to 16.
      final screen = _feed('\x1B[9G\x1B[0g\r\t');

      expect(screen.cursor.col, 16);
    });
  });

  group('the scroll region', () {
    // A region has to have room to scroll. Rather than honour a degenerate
    // one, the terminal falls back to the whole screen.
    test('resets to the whole screen when the top is not above the bottom', () {
      final screen = _feed('\x1B[5;2ra\r\nb\r\nc\r\nd\r\ne', rows: 4);

      expect(_row(screen, 0), 'b');
      expect(_row(screen, 3), 'e');
    });

    test('homes the cursor when it is set', () {
      final screen = _feed('\x1B[3;3H\x1B[5;2r', rows: 4);

      expect(screen.cursor.row, 0);
      expect(screen.cursor.col, 0);
    });
  });

  group('saving and restoring the cursor by mode', () {
    test('restores the position it was saved at', () {
      final screen = _feed('\x1B[3;5H\x1B[?1048h\x1B[1;1H\x1B[?1048l');

      expect(screen.cursor.row, 2);
      expect(screen.cursor.col, 4);
    });

    // The save carries the pen with it, so what is printed after a restore
    // looks like what was being printed before the save.
    test('restores the pen that was in force', () {
      final screen = _feed(
        '\x1B[31m\x1B[3;5H\x1B[?1048h\x1B[32m\x1B[1;1H\x1B[?1048lx',
      );

      expect(screen.cellAt(2, 4).fg, const IndexedColor(1));
    });
  });

  group('modes the child announces', () {
    test('bracketed paste turns on and off', () {
      expect(_feed('\x1B[?2004h').modes.bracketedPaste, isTrue);
      expect(_feed('\x1B[?2004h\x1B[?2004l').modes.bracketedPaste, isFalse);
    });

    test('synchronised output turns on and off', () {
      expect(_feed('\x1B[?2026h').modes.syncOutput, isTrue);
      expect(_feed('\x1B[?2026h\x1B[?2026l').modes.syncOutput, isFalse);
    });
  });

  // A repainting child redraws the alt screen itself, so resizing the main
  // buffer underneath it would be wasted work — and worse, would reflow
  // history the child is about to repaint over. It is deferred to the exit.
  test('a resize taken on the alt screen settles on the way out', () {
    final screen = _feedBytes(
      utf8.encode('hello\r\n\x1B[?1049h'),
      resizeBehavior: const RepaintingResize(),
    )..resize(rows: 6, cols: 20);

    VtParser(sink: screen).advance(utf8.encode('\x1B[?1049l'));
    screen.snapshot();

    expect(screen.cols, 20);
    expect(_row(screen, 0), 'hello');
  });

  group('OSC', () {
    test('sets the icon name on its own', () {
      final screen = _feed('\x1B]1;cow\x07');

      expect(screen.iconName, 'cow');
      expect(screen.title, isNull);
    });
  });

  // DCS is parsed and dropped, which is only correct if the payload never
  // reaches the screen and printing picks up cleanly afterwards.
  test('a DCS string leaves nothing behind', () {
    final screen = _feed('ab\x1BP1;2qDROPPED\x1B\\cd');

    expect(_row(screen, 0), 'abcd');
  });
}
