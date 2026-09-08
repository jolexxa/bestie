// The LineStore walk: rows scroll in oldest-first, whole logical lines
// evict from the front under the byte cap, and every derived index
// (rows, chars, pins) stays consistent through it all.

import 'dart:typed_data';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/line_store.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:test/test.dart';

/// A viewport row's packed arrays built from [text], padded to [cols].
/// `W` emits a wide cell followed by its continuation; `S` emits a
/// trailing spacer-head cell.
({Uint32List chars, Uint32List fg, Uint32List bg, Uint16List style}) _row(
  String text,
  int cols,
) {
  final chars = Uint32List(cols)..fillRange(0, cols, blankCharCode);
  final fg = Uint32List(cols)..fillRange(0, cols, packedDefaultFg);
  final bg = Uint32List(cols)..fillRange(0, cols, packedDefaultBg);
  final style = Uint16List(cols)..fillRange(0, cols, blankStyle);
  var col = 0;
  for (final rune in text.runes) {
    switch (String.fromCharCode(rune)) {
      case 'W':
        chars[col] = rune;
        style[col] = packStyle(attrs: CellAttrs.none, width: CellWidth.wide);
        col++;
        chars[col] = 0;
        style[col] = packStyle(
          attrs: CellAttrs.none,
          width: CellWidth.continuation,
        );
        col++;
      case 'S':
        chars[col] = blankCharCode;
        style[col] = packStyle(
          attrs: CellAttrs.none,
          width: CellWidth.spacerHead,
        );
        col++;
      default:
        chars[col] = rune;
        style[col] = blankStyle;
        col++;
    }
  }
  return (chars: chars, fg: fg, bg: bg, style: style);
}

void _push(
  LineStore store,
  String text, {
  int cols = 8,
  bool continuesAbove = false,
  bool continuesOnward = false,
}) {
  final row = _row(text, cols);
  store.appendRow(
    chars: row.chars,
    fg: row.fg,
    bg: row.bg,
    style: row.style,
    base: 0,
    cols: cols,
    continuesAbove: continuesAbove,
    continuesOnward: continuesOnward,
  );
}

LineStore _store({int maxBytes = 1 << 20, int cols = 8}) =>
    LineStore(maxBytes: maxBytes, graphemes: GraphemeTable(), cols: cols);

void main() {
  group('appendRow', () {
    test('a hard row becomes a closed trimmed line', () {
      final store = _store();
      _push(store, 'abc');

      expect(store.lineCount, 1);
      final line = store.lineAt(0);
      expect(line.length, 3);
      expect(line.open, isFalse);
      expect(line.charLength, 3);
      expect(store.totalRows, 1);
      expect(store.totalChars, 4);
    });

    test('soft-wrapped rows join into one open line at full width', () {
      final store = _store();
      _push(store, 'aaaaaaaa', continuesOnward: true);
      _push(store, 'bbb', continuesAbove: true);

      expect(store.lineCount, 1);
      final line = store.lineAt(0);
      expect(line.length, 11);
      expect(line.open, isFalse);
      expect(store.totalChars, 12);
    });

    test('a continuing row drops its trailing spacer-head cell', () {
      final store = _store();
      _push(store, 'aaaaaaaS', continuesOnward: true);
      _push(store, 'Wb', continuesAbove: true);

      final line = store.lineAt(0);
      expect(line.length, 7 + 3);
      expect(line.hasWide, isTrue);
    });

    test('an open line omits its separator until closed', () {
      final store = _store();
      _push(store, 'aaaaaaaa', continuesOnward: true);

      expect(store.lastIsOpen, isTrue);
      expect(store.totalChars, 8);

      _push(store, 'b', continuesAbove: true);
      expect(store.lastIsOpen, isFalse);
      expect(store.totalChars, 10);
    });

    test('a blank row is one empty line: one row, one separator', () {
      final store = _store();
      _push(store, 'a');
      _push(store, '');
      _push(store, 'b');

      expect(store.lineCount, 3);
      expect(store.lineAt(1).length, 0);
      expect(store.totalRows, 3);
      expect(store.totalChars, 2 + 1 + 2);
    });

    test('styled trailing blanks survive trimming', () {
      final store = _store(cols: 4);
      final row = _row('a', 4);
      row.bg[2] = 99;
      store.appendRow(
        chars: row.chars,
        fg: row.fg,
        bg: row.bg,
        style: row.style,
        base: 0,
        cols: 4,
        continuesAbove: false,
        continuesOnward: false,
      );

      expect(store.lineAt(0).length, 3);
    });

    test("a line ending in a wrapped row loses that row's padding", () {
      final store = _store();
      // The row wraps, so its padding to the margin is content — until the
      // continuation turns out to hold nothing, which ends the line there.
      _push(store, 'abc', continuesOnward: true);
      _push(store, '', continuesAbove: true);

      final line = store.lineAt(0);
      expect(line.length, 3);
      expect(line.charLength, 3);
      expect(store.totalChars, 4);
    });

    test('padding inside a wrapped line is content, not trailing blanks', () {
      final store = _store();
      _push(store, 'abc', continuesOnward: true);
      _push(store, 'd', continuesAbove: true);

      final line = store.lineAt(0);
      expect(line.length, 8 + 1);
      expect(line.charLength, 9);
      expect(store.totalChars, 10);
    });
  });

  group('row index', () {
    test('maps absolute rows to line slices across widths', () {
      final store = _store(cols: 4);
      _push(store, 'aaaa', cols: 4, continuesOnward: true);
      _push(store, 'aa', cols: 4, continuesAbove: true);
      _push(store, 'bb', cols: 4);

      expect(store.totalRows, 3);
      void expectSlice(int row, LogicalLine line, int index, int within) {
        final slice = store.sliceAtRow(row);
        expect(slice.line, same(line));
        expect(slice.lineIndex, index);
        expect(slice.rowWithinLine, within);
        expect(store.rowContinuesAbove(row), within > 0);
      }

      expectSlice(0, store.lineAt(0), 0, 0);
      expectSlice(1, store.lineAt(0), 0, 1);
      expectSlice(2, store.lineAt(1), 1, 0);

      store.setCols(2);
      expect(store.totalRows, 4);
      expect(store.sliceAtRow(2).rowWithinLine, 2);
      expect(store.sliceAtRow(3).line, store.lineAt(1));

      store.setCols(6);
      expect(store.totalRows, 2);
    });

    test('wide lines count exact break rows, not naive division', () {
      final store = _store(cols: 6);
      _push(store, 'aaaaWS', cols: 7, continuesOnward: true);
      _push(store, 'bb', cols: 7, continuesAbove: true);

      store.setCols(5);
      final line = store.lineAt(0);
      expect(line.hasWide, isTrue);
      expect(store.totalRows, line.rowsAt(5));
    });

    test('firstRowOf answers relative to surviving history', () {
      final store = _store(cols: 4);
      _push(store, 'aa', cols: 4);
      _push(store, 'bb', cols: 4);

      expect(store.firstRowOf(store.lineAt(1)), 1);
    });
  });

  group('eviction', () {
    test('evicts whole oldest lines once bytes exceed the cap', () {
      final store = _store(
        maxBytes: 3 * (4 * bytesPerCell + lineOverheadBytes),
      );
      for (var i = 0; i < 6; i++) {
        _push(store, 'row$i');
      }

      expect(store.lineCount, lessThan(6));
      expect(store.totalBytes, lessThanOrEqualTo(store.maxBytes));
      final oldest = store.lineAt(0);
      expect(
        String.fromCharCodes(
          [for (var i = 0; i < oldest.length; i++) oldest.charCodeAt(i)],
        ),
        isNot('row0'),
      );
    });

    test('epoch offsets keep the indexes consistent after eviction', () {
      final store = _store(
        maxBytes: 4 * (4 * bytesPerCell + lineOverheadBytes),
      );
      for (var i = 0; i < 30; i++) {
        _push(store, 'row$i');
      }

      expect(store.totalRows, store.lineCount);
      final slice = store.sliceAtRow(0);
      expect(slice.lineIndex, 0);
      expect(slice.rowWithinLine, 0);
      expect(
        store.firstRowOf(store.lineAt(store.lineCount - 1)),
        store.lineCount - 1,
      );
    });

    test('never evicts the only line even over budget', () {
      final store = _store(maxBytes: 8);
      _push(store, 'aaaaaaaa', continuesOnward: true);
      _push(store, 'bbbbbbbb', continuesAbove: true, continuesOnward: true);

      expect(store.lineCount, 1);
      expect(store.totalBytes, greaterThan(store.maxBytes));
    });

    test('pins on an evicted line relocate to the front', () {
      final store = _store(
        maxBytes: 2 * (4 * bytesPerCell + lineOverheadBytes),
      );
      _push(store, 'aaa');
      final pin = store.track(LinePin(line: store.lineAt(0), offset: 2));
      for (var i = 0; i < 5; i++) {
        _push(store, 'bbb$i');
      }

      expect(pin.line, isNull);
      expect(pin.offset, 0);
      expect(store.charOffsetOf(pin), 0);
    });
  });

  group('pins and char offsets', () {
    test('charOffsetOf and pinAtCharOffset round-trip', () {
      final store = _store();
      _push(store, 'abc');
      _push(store, 'defg');

      final pin = store.pinAtCharOffset(6)!;
      expect(pin.line, store.lineAt(1));
      expect(pin.offset, 2);
      expect(store.charOffsetOf(pin), 6);
    });

    test('offsets past the store belong to the viewport', () {
      final store = _store();
      _push(store, 'abc');

      expect(store.pinAtCharOffset(4), isNull);
      expect(store.totalChars, 4);
    });

    test('a pin survives eviction of the lines before it', () {
      final store = _store(maxBytes: 600);
      _push(store, 'keep me');
      _push(store, 'target');
      final pin = store.pinAtCharOffset(store.totalChars - 3)!;
      final line = pin.line!;

      _push(store, 'noise1');
      _push(store, 'noise2');

      expect(store.indexOf(line), 0);
      expect(pin.line, line);
      expect(store.charOffsetOf(pin), 4);
    });
  });

  group('seq contiguity across removeLast', () {
    test('a line appended after removeLast is still indexable', () {
      final store = _store();
      _push(store, 'aaa');
      _push(store, 'bbb');
      store.removeLast();
      _push(store, 'ccc');

      final newest = store.lineAt(store.lineCount - 1);
      expect(store.indexOf(newest), store.lineCount - 1);
      expect(store.firstRowOf(newest), store.lineCount - 1);
    });

    test('front eviction after removeLast never lands on a neighbor', () {
      final store = _store(maxBytes: 600);
      _push(store, 'aaaaaa');
      _push(store, 'bbbbbb');
      store.removeLast();
      _push(store, 'cccccc');
      _push(store, 'dddddd');
      _push(store, 'eeeeee');

      for (var i = 0; i < store.lineCount; i++) {
        final line = store.lineAt(i);
        expect(store.indexOf(line), i, reason: 'line $i');
        expect(store.firstRowOf(line), i, reason: 'line $i');
      }
    });

    test('a resize-style remove and re-append round-trip stays sound', () {
      final store = _store();
      _push(store, 'aaa');
      _push(store, 'wrapwrap', continuesOnward: true);
      store.removeLast();
      _push(store, 'wrapwr', continuesOnward: true);
      _push(store, 'ap', continuesAbove: true);

      final seam = store.lineAt(1);
      expect(store.indexOf(seam), 1);
      expect(store.charOffsetOf(LinePin(line: seam, offset: 0)), 4);
    });
  });

  test('removeLast reclaims the newest line for the viewport', () {
    final store = _store();
    _push(store, 'aaa');
    _push(store, 'bbbb', continuesOnward: true);

    final line = store.removeLast()!;
    expect(line.length, 8);
    expect(store.lineCount, 1);
    expect(store.totalRows, 1);
    expect(store.totalChars, 4);
  });

  test('clear drops everything and detaches pins', () {
    final store = _store();
    _push(store, 'abc');
    final pin = store.track(LinePin(line: store.lineAt(0), offset: 1));

    store.clear();

    expect(store.isEmpty, isTrue);
    expect(store.totalRows, 0);
    expect(store.totalChars, 0);
    expect(pin.line, isNull);
  });
}
