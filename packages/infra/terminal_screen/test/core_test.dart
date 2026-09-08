// Repeated setup statements are easier to scan than cascades in these tests.
import 'dart:convert' show utf8;

import 'package:terminal_screen/src/outbound.dart' show OutboundEncoder;
import 'package:terminal_screen/src/unicode.dart'
    show graphemeWidth, isCombiningOrZeroWidth, stringForCodePoint;
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void main() {
  group('CellAttrs', () {
    test('all bit helpers round-trip', () {
      var a = CellAttrs.none;
      a = CellAttrs.setBold(a);
      expect(CellAttrs.isBold(a), isTrue);
      a = CellAttrs.setBold(a, value: false);
      expect(CellAttrs.isBold(a), isFalse);

      a = CellAttrs.setFaint(a);
      expect(CellAttrs.isFaint(a), isTrue);
      a = CellAttrs.setFaint(a, value: false);

      a = CellAttrs.setItalic(a);
      expect(CellAttrs.isItalic(a), isTrue);
      a = CellAttrs.setItalic(a, value: false);

      a = CellAttrs.setBlink(a);
      expect(CellAttrs.isBlink(a), isTrue);
      a = CellAttrs.setBlink(a, value: false);

      a = CellAttrs.setInverse(a);
      expect(CellAttrs.isInverse(a), isTrue);
      a = CellAttrs.setInverse(a, value: false);

      a = CellAttrs.setInvisible(a);
      expect(CellAttrs.isInvisible(a), isTrue);
      a = CellAttrs.setInvisible(a, value: false);

      a = CellAttrs.setStrikethrough(a);
      expect(CellAttrs.isStrikethrough(a), isTrue);
      a = CellAttrs.setStrikethrough(a, value: false);
      expect(a, CellAttrs.none);
    });

    test('underline style field', () {
      var a = CellAttrs.none;
      expect(CellAttrs.hasUnderline(a), isFalse);
      a = CellAttrs.setUnderlineStyle(a, 3);
      expect(CellAttrs.underlineStyle(a), UnderlineStyle.curly);
      expect(CellAttrs.hasUnderline(a), isTrue);
      a = CellAttrs.setUnderlineStyle(a, 0);
      expect(CellAttrs.underlineStyle(a), UnderlineStyle.off);
      expect(CellAttrs.hasUnderline(a), isFalse);
    });

    test('UnderlineStyle enum values', () {
      expect(UnderlineStyle.values.length, 6);
      expect(UnderlineStyle.off.index, 0);
    });
  });

  group('Color', () {
    test('default foreground equality', () {
      expect(Color.defaultFg, Color.defaultFg);
      expect(Color.defaultFg.hashCode, Color.defaultFg.hashCode);
      expect(Color.defaultFg.toString(), 'DefaultForeground');
      // Equality on a non-matching type returns false.
      expect(Color.defaultFg == const IndexedColor(0), isFalse);
    });

    test('default background equality', () {
      expect(Color.defaultBg, Color.defaultBg);
      expect(Color.defaultBg.hashCode, Color.defaultBg.hashCode);
      expect(Color.defaultBg.toString(), 'DefaultBackground');
      expect(Color.defaultBg == const IndexedColor(0), isFalse);
    });

    test('IndexedColor equality + toString', () {
      const a = IndexedColor(5);
      const b = IndexedColor(5);
      const c = IndexedColor(6);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), 'IndexedColor(5)');
    });

    test('RgbColor equality + toString', () {
      const a = RgbColor(10, 20, 30);
      const b = RgbColor(10, 20, 30);
      const c = RgbColor(10, 20, 31);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), 'RgbColor(10, 20, 30)');
    });
  });

  group('blank cells', () {
    test('a fresh screen reads back as blanks', () {
      final cell = Screen(
        rows: 2,
        cols: 2,
        scrollbackBytes: 0 * 4096,
      ).cellAt(0, 0);

      expect(cell.char, ' ');
      expect(cell.fg, Color.defaultFg);
      expect(cell.bg, Color.defaultBg);
      expect(cell.attrs, CellAttrs.none);
      expect(cell.width, CellWidth.single);
    });

    test('erasing a written cell restores a blank', () {
      final screen = Screen(rows: 2, cols: 2, scrollbackBytes: 0 * 4096);
      VtParser(sink: screen).advance(utf8.encode('\x1B[1;31mx\x1B[2J'));

      final cell = screen.cellAt(0, 0);
      expect(cell.char, ' ');
      expect(cell.fg, Color.defaultFg);
      expect(cell.attrs, CellAttrs.none);
      expect(cell.width, CellWidth.single);
    });

    test('a wide character marks the next cell as continuation', () {
      final screen = Screen(rows: 2, cols: 4, scrollbackBytes: 0 * 4096);
      VtParser(sink: screen).advance(utf8.encode('中'));
      screen.snapshot();

      expect(screen.cellAt(0, 0).width, CellWidth.wide);
      expect(screen.cellAt(0, 1).width, CellWidth.continuation);
      expect(screen.cellAt(0, 1).char, ' ');
    });
  });

  group('Cursor', () {
    test('save then restore', () {
      final c = Cursor()
        ..row = 4
        ..col = 7
        ..save(
          fg: const IndexedColor(2),
          bg: Color.defaultBg,
          attrs: CellAttrs.setBold(0),
          originMode: true,
        )
        ..row = 0
        ..col = 0
        ..pendingWrap = true;
      final restored = c.restore();
      expect(c.row, 4);
      expect(c.col, 7);
      expect(restored.fg, const IndexedColor(2));
      expect(restored.originMode, isTrue);
      expect(c.hasSaved, isTrue);
    });

    test('restore with nothing saved jumps home', () {
      final c = Cursor()
        ..row = 3
        ..col = 3;
      final restored = c.restore();
      expect(c.row, 0);
      expect(c.col, 0);
      expect(restored.originMode, isFalse);
    });

    test('forgetSaved', () {
      final c = Cursor()
        ..save(
          fg: Color.defaultFg,
          bg: Color.defaultBg,
          attrs: 0,
          originMode: false,
        );
      expect(c.hasSaved, isTrue);
      c.forgetSaved();
      expect(c.hasSaved, isFalse);
    });

    test('CursorStyle has three variants', () {
      expect(CursorStyle.values.length, 3);
    });

    test('freeze captures live state', () {
      final c = Cursor()
        ..row = 2
        ..col = 3;
      final data = c.freeze();
      expect(data.row, 2);
      expect(data.col, 3);
    });
  });

  group('TerminalModes', () {
    test('defaults match xterm-256color', () {
      final m = TerminalModes();
      expect(m.autoWrap, isTrue);
      expect(m.originMode, isFalse);
      expect(m.cursorVisible, isTrue);
      expect(m.mouseMode, MouseMode.off);
    });

    test('freeze captures all fields', () {
      final m = TerminalModes()
        ..insertMode = true
        ..mouseMode = MouseMode.vt200
        ..mouseEncoding = MouseEncoding.sgr;
      final data = m.freeze();
      expect(data.insertMode, isTrue);
      expect(data.mouseMode, MouseMode.vt200);
      expect(data.mouseEncoding, MouseEncoding.sgr);
    });

    test('enums have all expected values', () {
      expect(MouseMode.values.length, 5);
      expect(MouseEncoding.values.length, 4);
    });
  });

  group('Region', () {
    test('equality + hashCode + toString', () {
      const a = Region(row: 1, col: 2, height: 3, width: 4);
      const b = Region(row: 1, col: 2, height: 3, width: 4);
      const c = Region(row: 1, col: 2, height: 3, width: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('Region'));
    });

    test('lastRow / lastCol', () {
      const r = Region(row: 2, col: 3, height: 4, width: 5);
      expect(r.lastRow, 5);
      expect(r.lastCol, 7);
    });

    test('clampTo inside bounds is unchanged', () {
      const r = Region(row: 1, col: 2, height: 2, width: 2);
      expect(r.clampTo(10, 10), r);
    });

    test('clampTo shrinks overlapping region', () {
      const r = Region(row: 3, col: 3, height: 10, width: 10);
      final clamped = r.clampTo(5, 5);
      expect(clamped, const Region(row: 3, col: 3, height: 2, width: 2));
    });

    test('clampTo outside bounds returns null', () {
      const r = Region(row: 10, col: 10, height: 2, width: 2);
      expect(r.clampTo(5, 5), isNull);
    });
  });

  group('OutboundEncoder', () {
    test('DA1 / DA2 / DA3 / DSR / CPR / DECXCPR', () {
      expect(String.fromCharCodes(OutboundEncoder.da1()), '\x1B[?62;22c');
      expect(String.fromCharCodes(OutboundEncoder.da2()), '\x1B[>0;0;0c');
      expect(
        String.fromCharCodes(OutboundEncoder.da3()),
        '\x1BP!|00000000\x1B\\',
      );
      expect(String.fromCharCodes(OutboundEncoder.dsrOk()), '\x1B[0n');
      expect(String.fromCharCodes(OutboundEncoder.cpr(3, 5)), '\x1B[3;5R');
      expect(
        String.fromCharCodes(OutboundEncoder.dexCpr(3, 5)),
        '\x1B[?3;5;0R',
      );
    });

    test('palette query replies for valid indices', () {
      final reply = OutboundEncoder.palette(1);
      expect(reply, isNotNull);
      expect(String.fromCharCodes(reply!), startsWith('\x1B]4;1;rgb:'));
    });

    test('palette query returns null outside 0..15', () {
      expect(OutboundEncoder.palette(-1), isNull);
      expect(OutboundEncoder.palette(42), isNull);
    });

    test('default fg / bg replies', () {
      expect(
        String.fromCharCodes(OutboundEncoder.defaultForeground()),
        startsWith('\x1B]10;'),
      );
      expect(
        String.fromCharCodes(OutboundEncoder.defaultBackground()),
        startsWith('\x1B]11;'),
      );
    });
  });

  group('unicode helpers', () {
    test('stringForCodePoint uses ASCII cache', () {
      expect(stringForCodePoint(0x41), 'A');
      expect(
        identical(stringForCodePoint(0x41), stringForCodePoint(0x41)),
        isTrue,
      );
      expect(stringForCodePoint(0x3042), '\u3042');
    });

    test('graphemeWidth classifies clusters', () {
      expect(graphemeWidth(''), 0);
      expect(graphemeWidth('a'), 1);
      expect(graphemeWidth('\u3042'), 2); // hiragana あ
      expect(graphemeWidth('\u0301'), 0); // combining acute
    });

    test('isCombiningOrZeroWidth covers known ranges', () {
      expect(isCombiningOrZeroWidth(0x0301), isTrue);
      expect(isCombiningOrZeroWidth(0x1AB0), isTrue);
      expect(isCombiningOrZeroWidth(0x1DC0), isTrue);
      expect(isCombiningOrZeroWidth(0x20D0), isTrue);
      expect(isCombiningOrZeroWidth(0xFE00), isTrue);
      expect(isCombiningOrZeroWidth(0xFE20), isTrue);
      expect(isCombiningOrZeroWidth(0xE0100), isTrue);
      expect(isCombiningOrZeroWidth(0x200C), isTrue);
      expect(isCombiningOrZeroWidth(0x200D), isTrue);
      expect(isCombiningOrZeroWidth(0xFEFF), isTrue);
      expect(isCombiningOrZeroWidth(0x41), isFalse);
    });
  });

  group('diff', () {
    test('two identical snapshots diff to empty', () {
      final s = Screen(rows: 3, cols: 5, scrollbackBytes: 0 * 4096);
      final a = s.snapshot();
      final b = s.snapshot();
      final d = computeDiff(a, b);
      expect(d.isEmpty, isTrue);
      expect(d.changedRowCount, 0);
    });

    test('cell change is reported with row/col/before/after', () {
      final s = Screen(rows: 3, cols: 5, scrollbackBytes: 0 * 4096);
      final before = s.snapshot();
      s.onPrint(0x41);
      final after = s.snapshot();
      final d = computeDiff(before, after);
      expect(d.cells, isNotEmpty);
      expect(d.cells.first.row, 0);
      expect(d.cells.first.col, 0);
      expect(d.cells.first.before.char, ' ');
      expect(d.cells.first.after.char, 'A');
      expect(d.cursorChanged, isTrue);
      expect(d.changedRowCount, 1);
    });

    test('title / altScreen / modes change flags', () {
      final s = Screen(rows: 2, cols: 5, scrollbackBytes: 0 * 4096);
      final a = s.snapshot();
      s.onOscDispatch(
        params: [
          [0x32],
          'hi'.codeUnits,
        ],
        bellTerminated: true,
      );
      final b = s.snapshot();
      final d = computeDiff(a, b);
      expect(d.titleChanged, isTrue);
    });

    test('CellChange equality / hashCode / toString', () {
      const a = CellChange(
        row: 0,
        col: 0,
        before: (
          char: ' ',
          fg: Color.defaultFg,
          bg: Color.defaultBg,
          attrs: 0,
          width: CellWidth.single,
        ),
        after: (
          char: 'A',
          fg: Color.defaultFg,
          bg: Color.defaultBg,
          attrs: 0,
          width: CellWidth.single,
        ),
      );
      expect(a, a);
      expect(a.toString(), contains('CellChange'));
      expect(a.hashCode, a.hashCode);
    });
  });
}
