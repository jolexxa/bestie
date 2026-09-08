// The row-hoisted accessors the paint loop uses, and the cell-placement
// edge cases that only appear at a wide character's boundaries.

import 'dart:convert';

import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _feed(String input, {int rows = 3, int cols = 8, int scrollback = 0}) {
  final screen = Screen(
    rows: rows,
    cols: cols,
    scrollbackBytes: scrollback * 4096,
  );
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
  return screen;
}

String _row(Screen screen, int row) {
  final out = StringBuffer();
  for (var col = 0; col < screen.cols; col++) {
    final cell = screen.cellAt(row, col);
    if (cell.width == CellWidth.continuation) continue;
    out.write(cell.char.isEmpty ? ' ' : cell.char);
  }
  return out.toString().trimRight();
}

void main() {
  group('row-hoisted accessors', () {
    test('agree with cellAt across a styled row', () {
      final screen = _feed('\x1B[1;4;38;5;208;48;2;10;20;30mhi');

      final base = screen.viewportRowBase(0);
      for (var col = 0; col < screen.cols; col++) {
        final cell = screen.cellAt(0, col);
        expect(screen.charAt(base, col), cell.char, reason: 'char @$col');
        expect(screen.attrsAt(base, col), cell.attrs, reason: 'attrs @$col');
        expect(screen.widthAt(base, col), cell.width, reason: 'width @$col');
        expect(
          unpackColor(screen.fgAt(base, col)),
          cell.fg,
          reason: 'fg @$col',
        );
        expect(
          unpackColor(screen.bgAt(base, col)),
          cell.bg,
          reason: 'bg @$col',
        );
      }
    });

    test('report the packed color variants without unpacking', () {
      final screen = _feed('\x1B[38;5;9;48;2;1;2;3mx');
      final base = screen.viewportRowBase(0);

      expect(colorKind(screen.fgAt(base, 0)), ColorKind.indexed);
      expect(colorIndex(screen.fgAt(base, 0)), 9);
      expect(colorKind(screen.bgAt(base, 0)), ColorKind.rgb);
      expect(colorRed(screen.bgAt(base, 0)), 1);
      expect(colorGreen(screen.bgAt(base, 0)), 2);
      expect(colorBlue(screen.bgAt(base, 0)), 3);
    });

    test('report defaults on an untouched cell', () {
      final screen = _feed('');
      final base = screen.viewportRowBase(0);

      expect(colorKind(screen.fgAt(base, 0)), ColorKind.defaultForeground);
      expect(colorKind(screen.bgAt(base, 0)), ColorKind.defaultBackground);
      expect(screen.charAt(base, 0), ' ');
      expect(screen.attrsAt(base, 0), CellAttrs.none);
      expect(screen.widthAt(base, 0), CellWidth.single);
    });

    test('mark the right half of a wide character as continuation', () {
      final screen = _feed('中');
      final base = screen.viewportRowBase(0);

      expect(screen.charAt(base, 0), '中');
      expect(screen.widthAt(base, 0), CellWidth.wide);
      // The continuation cell carries no glyph of its own; readers
      // skip it on width rather than on its contents.
      expect(screen.widthAt(base, 1), CellWidth.continuation);
      expect(screen.charAt(base, 1), ' ');
    });
  });

  group('viewportRowBase while scrolled back', () {
    test('reads history at the top and the live viewport below', () {
      final screen = _feed(
        '1\r\n2\r\n3\r\n4',
        rows: 2,
        scrollback: 10,
      )..setViewOffset(1);

      expect(screen.charAt(screen.viewportRowBase(0), 0), '2');
      expect(screen.charAt(screen.viewportRowBase(1), 0), '3');
    });

    test('reads the live viewport when not scrolled', () {
      final screen = _feed('1\r\n2\r\n3\r\n4', rows: 2, scrollback: 10);

      expect(screen.charAt(screen.viewportRowBase(0), 0), '3');
      expect(screen.charAt(screen.viewportRowBase(1), 0), '4');
    });
  });

  group('wide characters at the right margin', () {
    test('wrap a column early rather than split', () {
      final screen = _feed('ab中', cols: 3);

      expect(_row(screen, 0), 'ab');
      expect(_row(screen, 1), '中');
    });

    test('blank the column they refused to occupy', () {
      final screen = _feed('ab中', cols: 3);

      expect(screen.cellAt(0, 2).char, ' ');
      expect(screen.cellAt(0, 2).bg, Color.defaultBg);
      expect(screen.cellAt(0, 2).attrs, CellAttrs.none);
    });

    test('tag that column as padding, not as printed content', () {
      final screen = _feed('ab中', cols: 3);

      expect(screen.cellAt(0, 2).width, CellWidth.spacerHead);
    });

    test('leave a printed space untagged, so the two stay distinct', () {
      // Same resulting glyphs, but here the space is the child's.
      final screen = _feed('ab \x1B[2;1H中', cols: 3);

      expect(screen.cellAt(0, 2).char, ' ');
      expect(screen.cellAt(0, 2).width, CellWidth.single);
    });

    test('mark the wrapped row as continuing the previous one', () {
      final screen = _feed('ab中', cols: 3);

      expect(screen.cellAt(1, 0).char, '中');
      expect(screen.cellAt(1, 1).width, CellWidth.continuation);
    });

    test('lose the right half instead of wrapping when DECAWM is off', () {
      final screen = _feed('\x1B[?7lab中', cols: 3);

      expect(screen.cellAt(0, 2).char, '中');
      expect(screen.cellAt(0, 2).width, CellWidth.single);
      expect(_row(screen, 1), '');
    });
  });

  group('overwriting a wide character', () {
    test('clears the orphaned right half', () {
      final screen = _feed('中\x1B[1;1Hx');

      expect(screen.cellAt(0, 0).char, 'x');
      expect(screen.cellAt(0, 1).char, ' ');
      expect(screen.cellAt(0, 1).width, CellWidth.single);
    });

    test('clears the orphaned left half', () {
      final screen = _feed('中\x1B[1;2Hx');

      expect(screen.cellAt(0, 0).char, ' ');
      expect(screen.cellAt(0, 0).width, CellWidth.single);
      expect(screen.cellAt(0, 1).char, 'x');
    });
  });

  group('combining marks arriving after their base', () {
    test('stack onto the previous cell', () {
      final screen = Screen(rows: 2, cols: 4, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: screen)..advance(utf8.encode('e'));
      screen.snapshot();
      parser.advance(utf8.encode('́'));
      screen.snapshot();

      expect(screen.cellAt(0, 0).char, 'é');
      expect(screen.cellAt(0, 0).width, CellWidth.single);
    });

    test('are dropped when no base cell precedes them', () {
      final screen = Screen(rows: 2, cols: 4, scrollbackBytes: 0 * 4096);
      VtParser(sink: screen).advance(utf8.encode('́'));
      screen.snapshot();

      expect(screen.cellAt(0, 0).char, ' ');
    });

    test('widen the base cell when VS16 requests emoji presentation', () {
      final screen = Screen(rows: 2, cols: 4, scrollbackBytes: 0 * 4096);
      final parser = VtParser(sink: screen)..advance(utf8.encode('❤'));
      screen.snapshot();
      parser.advance(utf8.encode('️'));
      screen.snapshot();

      expect(screen.cellAt(0, 0).width, CellWidth.wide);
      expect(screen.cellAt(0, 1).width, CellWidth.continuation);
    });
  });

  group('scrollback wrap markers', () {
    test('travel with the row as it is evicted', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 4 * 4096)
        ..setWrappedAt(1, wrapped: true)
        ..scrollUpOne()
        ..scrollUpOne();

      expect(buffer.scrollbackWrappedAt(0), isFalse);
      expect(buffer.scrollbackWrappedAt(1), isTrue);
    });

    test('stay clear for rows that never wrapped', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 4 * 4096)
        ..scrollUpOne();

      expect(buffer.scrollbackWrappedAt(0), isFalse);
    });
  });
}
