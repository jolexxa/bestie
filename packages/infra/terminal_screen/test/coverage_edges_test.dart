import 'dart:convert';

import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

/// A line holding [text], the way one arrives in history: a viewport row
/// scrolled off the top.
LogicalLine _scrolledOff(String text, {int cols = 8}) {
  final buffer = Buffer(rows: 2, cols: cols, scrollbackBytes: 4096);
  final base = buffer.rowBase(0);
  for (var col = 0; col < text.length; col++) {
    buffer.setCharCodeAt(base, col, text.codeUnitAt(col));
  }
  buffer.scrollUpOne();
  return buffer.store!.lineAt(0);
}

void main() {
  group('Screen.flushPending', () {
    test('commits a pending cluster without taking a snapshot', () {
      final screen = Screen(rows: 2, cols: 8, scrollbackBytes: 0);
      // No snapshot: the last cluster is still held back in case a
      // combining mark extends it.
      VtParser(sink: screen).advance(utf8.encode('hi'));

      screen.flushPending();

      expect(screen.cellAt(0, 1).char, 'i');
    });
  });

  group('LineStore.first', () {
    test('names the oldest line it holds, and nothing when empty', () {
      final buffer = Buffer(rows: 2, cols: 8, scrollbackBytes: 4096);
      final store = buffer.store!;
      expect(store.first, isNull);

      final base = buffer.rowBase(0);
      for (var col = 0; col < 3; col++) {
        buffer.setCharCodeAt(base, col, 'abc'.codeUnitAt(col));
      }
      buffer.scrollUpOne();

      expect(store.first, same(store.lineAt(0)));
    });
  });

  group('LogicalLine as a reflow source', () {
    test('never continues a line above it, being a whole line already', () {
      expect(_scrolledOff('abc').wrappedAt(0), isFalse);
    });

    test('counts a styled space as content, not as a trailing blank', () {
      // Trailing blanks are trimmed on the way into history, but only
      // cells that are blank in every respect: a space carrying a
      // background is something a reader can see.
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 4096);
      final base = buffer.rowBase(0);
      buffer
        ..setCharCodeAt(base, 0, 'a'.codeUnitAt(0))
        ..setCell(
          base,
          1,
          charCode: ' '.codeUnitAt(0),
          fg: packColor(Color.defaultFg),
          bg: packColor(const IndexedColor(4)),
          style: packStyle(attrs: CellAttrs.none, width: CellWidth.single),
        )
        ..scrollUpOne();

      final line = buffer.store!.lineAt(0);

      expect(line.isBlankAt(0, 0), isFalse, reason: 'holds a glyph');
      expect(line.isBlankAt(0, 1), isFalse, reason: 'holds a background');
      expect(line.length, 2);
    });

    test('counts a bolded space as content too', () {
      // The other way a space is visible: no background, but an attribute
      // that draws something in the cell.
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 4096);
      final base = buffer.rowBase(0);
      buffer
        ..setCharCodeAt(base, 0, 'a'.codeUnitAt(0))
        ..setCell(
          base,
          1,
          charCode: ' '.codeUnitAt(0),
          fg: packColor(Color.defaultFg),
          bg: packColor(Color.defaultBg),
          style: packStyle(
            attrs: CellAttrs.setBold(CellAttrs.none),
            width: CellWidth.single,
          ),
        )
        ..scrollUpOne();

      final line = buffer.store!.lineAt(0);

      expect(line.isBlankAt(0, 1), isFalse);
      expect(line.length, 2);
    });

    test('an unstyled space at the end is not content', () {
      final line = _scrolledOff('a');

      expect(line.isBlankAt(0, 0), isFalse);
      expect(line.length, 1, reason: 'the rest of the row was trimmed');
    });
  });

  group('a resize that changes only the row count', () {
    // Same width means no re-wrap, which is its own path through the
    // buffer — and a scrolled-back view has to survive it.
    test('carries a scrolled-back view across', () {
      final screen = Screen(rows: 3, cols: 10, scrollbackBytes: 40000);
      _feed(screen, [for (var i = 1; i <= 20; i++) 'line $i'].join('\r\n'));
      screen.setViewOffset(5);
      expect(screen.viewOffset, 5);

      screen.resize(rows: 6, cols: 10);

      expect(screen.viewOffset, greaterThan(0));
      expect(screen.selectionLines(), [
        for (var i = 1; i <= 20; i++) 'line $i',
      ]);
    });

    test('leaves the view at the live edge alone', () {
      final screen = Screen(rows: 3, cols: 10, scrollbackBytes: 40000);
      _feed(screen, [for (var i = 1; i <= 20; i++) 'line $i'].join('\r\n'));

      screen.resize(rows: 5, cols: 10);

      expect(screen.viewOffset, 0);
      expect(screen.selectionLines().last, 'line 20');
    });
  });

  group('a double-width glyph that will not fit the last column', () {
    test('survives a re-wrap with its spacer intact', () {
      // The wide character cannot start in the final column, so the
      // terminal parks a spacer there and wraps the glyph.
      final screen = Screen(rows: 3, cols: 6, scrollbackBytes: 40000);
      _feed(screen, 'abcde一fgh\r\nsecond\r\nthird');
      final before = screen.selectionLines();

      screen.resize(rows: 3, cols: 9);

      expect(screen.selectionLines(), before);
    });

    test('reads back out of history the same way', () {
      final screen = Screen(rows: 2, cols: 6, scrollbackBytes: 40000);
      _feed(screen, 'abcde一fgh\r\nsecond\r\nthird\r\nfourth');

      expect(screen.selectionLines().first, 'abcde一fgh');
    });

    test('survives being taken back out of history by a growing view', () {
      // Growing the viewport pulls history back to fill it, so the spacer
      // is read again through the re-wrap rather than through the
      // scrollback cache.
      final screen = Screen(rows: 2, cols: 6, scrollbackBytes: 40000);
      _feed(screen, 'abcde一fgh\r\nsecond\r\nthird\r\nfourth');
      final before = screen.selectionLines();

      screen.resize(rows: 12, cols: 8);

      expect(screen.selectionLines(), before);
    });
  });
}
