// Reflow against a real Buffer: the packed arrays, the viewport ring,
// the line store seam, and the byte cap all participate here, none of
// which the fake row sink exercises.

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/src/color.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/reflow.dart';
import 'package:test/test.dart';

void _write(Buffer buffer, int row, String text, {bool wrapped = false}) {
  final base = buffer.rowBase(row);
  for (var col = 0; col < text.length; col++) {
    buffer.setCharCodeAt(base, col, text.codeUnitAt(col));
  }
  buffer.setWrappedAt(row, wrapped: wrapped);
}

String _readFrom(Buffer buffer, int base) {
  final out = StringBuffer();
  for (var col = 0; col < buffer.cols; col++) {
    out.writeCharCode(buffer.charCodeAt(base, col));
  }
  return out.toString();
}

String _row(Buffer buffer, int row) => _readFrom(buffer, buffer.rowBase(row));

String _scrollbackRow(Buffer buffer, int line) =>
    _readFrom(buffer, Buffer.scrollbackHandle(line));

/// Every row the buffer holds, oldest first.
List<String> _all(Buffer buffer) => [
  for (var i = 0; i < buffer.scrollbackLength; i++) _scrollbackRow(buffer, i),
  for (var r = 0; r < buffer.rows; r++) _row(buffer, r),
];

/// Which of those rows continue the row above them.
List<bool> _wraps(Buffer buffer) => [
  for (var i = 0; i < buffer.scrollbackLength; i++)
    buffer.scrollbackWrappedAt(i),
  for (var r = 0; r < buffer.rows; r++) buffer.wrappedAt(r),
];

/// No two viewport rows may share storage — an aliased pair would make
/// a write to either appear in both.
void _expectDistinctSlots(Buffer buffer) {
  final seen = <int>{};
  for (var r = 0; r < buffer.rows; r++) {
    expect(seen.add(buffer.rowBase(r)), isTrue, reason: 'row $r');
  }
}

void main() {
  group('widening', () {
    test('rejoins a wrapped run into one row', () {
      final buffer = Buffer(rows: 3, cols: 5, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcde');
      _write(buffer, 1, 'fg   ', wrapped: true);

      buffer.resizeReflowing(newRows: 3, newCols: 10);

      expect(_row(buffer, 0), 'abcdefg   ');
      expect(buffer.wrappedAt(0), isFalse);
      _expectDistinctSlots(buffer);
    });

    test('leaves the row it freed blank rather than duplicated', () {
      final buffer = Buffer(rows: 3, cols: 5, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcde');
      _write(buffer, 1, 'fg   ', wrapped: true);

      buffer.resizeReflowing(newRows: 3, newCols: 10);

      expect(_row(buffer, 1), ' ' * 10);
      expect(_row(buffer, 2), ' ' * 10);
    });

    test('keeps separate logical lines separate', () {
      final buffer = Buffer(rows: 3, cols: 4, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcd');
      _write(buffer, 1, 'ef  ', wrapped: true);
      _write(buffer, 2, 'ghij');

      buffer.resizeReflowing(newRows: 3, newCols: 8);

      expect(_all(buffer), ['abcdef  ', 'ghij    ', '        ']);
      expect(_wraps(buffer), [false, false, false]);
    });
  });

  group('narrowing', () {
    test('splits a row and marks the continuation', () {
      final buffer = Buffer(rows: 3, cols: 6, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcdef');

      buffer.resizeReflowing(newRows: 3, newCols: 3);

      expect(_all(buffer), ['abc', 'def', '   ']);
      expect(_wraps(buffer), [false, true, false]);
      _expectDistinctSlots(buffer);
    });

    test('pushes rows it created into scrollback', () {
      final buffer = Buffer(rows: 2, cols: 6, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcdef');
      _write(buffer, 1, 'ghijkl');

      buffer.resizeReflowing(newRows: 2, newCols: 3);

      expect(buffer.scrollbackLength, 2);
      expect(_all(buffer), ['abc', 'def', 'ghi', 'jkl']);
      _expectDistinctSlots(buffer);
    });

    test('holds every row it created, however many that is', () {
      final buffer = Buffer(rows: 2, cols: 8, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcdefgh');
      _write(buffer, 1, 'ijklmnop');

      buffer.resizeReflowing(newRows: 2, newCols: 2);

      expect(_all(buffer).join(), 'abcdefghijklmnop');
      expect(buffer.scrollbackLength, 6);
    });

    test('keeps the newest lines when the byte budget cannot fit', () {
      final buffer = Buffer(
        rows: 2,
        cols: 8,
        scrollbackBytes: 4 * bytesPerCell + lineOverheadBytes + 48,
      );
      _write(buffer, 0, 'abcdefgh');
      _write(buffer, 1, 'ijklmnop');

      buffer.resizeReflowing(newRows: 2, newCols: 2);

      // Two logical lines cannot both fit the budget; the older one
      // falls off whole and the newer keeps its wrapped run intact.
      expect(_all(buffer), ['ij', 'kl', 'mn', 'op']);
      expect(buffer.scrollbackLength, 2);
      _expectDistinctSlots(buffer);
    });
  });

  group('content already in scrollback', () {
    test('re-wraps alongside the viewport', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'aaaa');
      buffer.scrollUpOne();
      _write(buffer, 0, 'bbbb');
      _write(buffer, 1, 'cccc');

      buffer.resizeReflowing(newRows: 2, newCols: 8);

      expect(_all(buffer), ['aaaa    ', 'bbbb    ', 'cccc    ']);
      _expectDistinctSlots(buffer);
    });

    test('rejoins a run that crosses the scrollback boundary', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcd');
      _write(buffer, 1, 'ef  ', wrapped: true);
      buffer
        ..scrollUpOne()
        ..resizeReflowing(newRows: 2, newCols: 8);

      expect(_all(buffer).first, 'abcdef  ');
      expect(buffer.scrollbackLength, 0);
    });

    test('treats the oldest row as a line start whatever its wrap bit', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcd', wrapped: true);
      _write(buffer, 1, 'efgh');

      buffer.resizeReflowing(newRows: 2, newCols: 8);

      expect(_all(buffer), ['abcd    ', 'efgh    ']);
    });
  });

  group('gating', () {
    test('leaves a buffer without scrollback to truncate and pad', () {
      final buffer = Buffer(rows: 2, cols: 6, scrollbackBytes: 0 * 4096);
      _write(buffer, 0, 'abcdef');

      buffer.resizeReflowing(newRows: 2, newCols: 3);

      expect(_row(buffer, 0), 'abc');
      expect(_row(buffer, 1), '   ');
    });

    test('does nothing structural when only the row count changes', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcd');
      _write(buffer, 1, 'ef  ', wrapped: true);

      buffer.resizeReflowing(newRows: 4, newCols: 4);

      expect(_row(buffer, 0), 'abcd');
      expect(_row(buffer, 1), 'ef  ');
      expect(buffer.wrappedAt(1), isTrue);
    });
  });

  group('cell contents', () {
    test('carries colour and attributes to the new position', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      final base = buffer.rowBase(0);
      buffer
        ..setCell(
          base,
          3,
          charCode: 0x58,
          fg: packColor(const IndexedColor(9)),
          bg: packColor(const RgbColor(1, 2, 3)),
          style: packStyle(
            attrs: CellAttrs.setBold(CellAttrs.none),
            width: CellWidth.single,
          ),
        )
        ..resizeReflowing(newRows: 2, newCols: 2);

      final moved = buffer.rowBase(1);
      expect(buffer.charCodeAt(moved, 1), 0x58);
      expect(colorIndex(buffer.fgAt(moved, 1)), 9);
      expect(colorRed(buffer.bgAt(moved, 1)), 1);
      expect(CellAttrs.isBold(styleAttrs(buffer.styleAt(moved, 1))), isTrue);
    });

    test('keeps a styled space that a bare trim would drop', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 20 * 4096);
      final base = buffer.rowBase(0);
      buffer
        ..setCharCodeAt(base, 0, 0x61)
        ..setCell(
          base,
          1,
          charCode: blankCharCode,
          fg: packedDefaultFg,
          bg: packColor(const IndexedColor(4)),
          style: blankStyle,
        )
        ..resizeReflowing(newRows: 2, newCols: 8);

      expect(colorIndex(buffer.bgAt(buffer.rowBase(0), 1)), 4);
    });
  });

  group('double-width clusters', () {
    /// A cluster covering [col] and the column after it. A ZWJ emoji
    /// has this exact shape — one code, two columns.
    void writeWide(Buffer buffer, int row, int col, int charCode) {
      final base = buffer.rowBase(row);
      buffer
        ..setCharCodeAt(base, col, charCode)
        ..setStyleAt(
          base,
          col,
          packStyle(attrs: CellAttrs.none, width: CellWidth.wide),
        )
        ..setStyleAt(
          base,
          col + 1,
          packStyle(attrs: CellAttrs.none, width: CellWidth.continuation),
        );
    }

    Buffer clustered() {
      final buffer = Buffer(rows: 3, cols: 6, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abc  f');
      writeWide(buffer, 0, 3, 0x1F468);
      return buffer;
    }

    test('breaks a column early rather than splitting one', () {
      final buffer = clustered()..resizeReflowing(newRows: 3, newCols: 4);

      expect(buffer.charCodeAt(buffer.rowBase(1), 0), 0x1F468);
      expect(
        styleWidth(buffer.styleAt(buffer.rowBase(1), 1)),
        CellWidth.continuation,
      );
      expect(buffer.wrappedAt(1), isTrue);
    });

    test('tags the column the break gave up', () {
      final buffer = clustered()..resizeReflowing(newRows: 3, newCols: 4);

      expect(
        styleWidth(buffer.styleAt(buffer.rowBase(0), 3)),
        CellWidth.spacerHead,
      );
      expect(buffer.charCodeAt(buffer.rowBase(0), 3), blankCharCode);
    });

    test('drops that column again rather than growing the line', () {
      final buffer = clustered()
        ..resizeReflowing(newRows: 3, newCols: 4)
        ..resizeReflowing(newRows: 3, newCols: 6);

      final base = buffer.rowBase(0);
      expect(buffer.charCodeAt(base, 3), 0x1F468);
      expect(styleWidth(buffer.styleAt(base, 3)), CellWidth.wide);
      expect(buffer.charCodeAt(base, 5), 0x66);
      expect(buffer.scrollbackLength, 0);
    });

    test('keeps the cluster whole down to a single column', () {
      final buffer = clustered()..resizeReflowing(newRows: 3, newCols: 1);

      var found = 0;
      for (var i = 0; i < buffer.scrollbackLength; i++) {
        if (buffer.charCodeAt(Buffer.scrollbackHandle(i), 0) == 0x1F468) {
          found++;
        }
      }
      for (var r = 0; r < buffer.rows; r++) {
        if (buffer.charCodeAt(buffer.rowBase(r), 0) == 0x1F468) found++;
      }

      expect(found, 1);
    });
  });

  group('pins', () {
    test('follows its cell down when a row splits', () {
      final buffer = Buffer(rows: 3, cols: 6, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcdef');
      final pin = ReflowPin(row: 0, col: 4);

      buffer.resizeReflowing(newRows: 3, newCols: 3, pins: [pin]);

      expect(pin.row, 1);
      expect(pin.col, 1);
      expect(buffer.charCodeAt(buffer.rowBase(pin.row), pin.col), 0x65);
    });

    test('follows its cell up when a run rejoins', () {
      final buffer = Buffer(rows: 3, cols: 5, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcde');
      _write(buffer, 1, 'fg   ', wrapped: true);
      final pin = ReflowPin(row: 1, col: 1);

      buffer.resizeReflowing(newRows: 3, newCols: 10, pins: [pin]);

      expect(pin.row, 0);
      expect(pin.col, 6);
      expect(buffer.charCodeAt(buffer.rowBase(0), 6), 0x67);
    });

    test('lands somewhere real when parked past the last glyph', () {
      // A fresh prompt line looks exactly like this, so the cell the
      // pin needs has to survive trimming.
      final buffer = Buffer(rows: 2, cols: 8, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'ab');
      final pin = ReflowPin(row: 0, col: 5);

      buffer.resizeReflowing(newRows: 2, newCols: 3, pins: [pin]);

      expect(pin.row, 1);
      expect(pin.col, 2);
    });

    test('reports a row that landed in scrollback as negative', () {
      final buffer = Buffer(rows: 2, cols: 6, scrollbackBytes: 20 * 4096);
      _write(buffer, 0, 'abcdef');
      _write(buffer, 1, 'ghijkl');
      final pin = ReflowPin(row: 0, col: 0);

      buffer.resizeReflowing(newRows: 2, newCols: 3, pins: [pin]);

      expect(pin.row, -2);
      expect(_scrollbackRow(buffer, 0), 'abc');
    });

    test('clamps to the viewport when only rows change', () {
      final buffer = Buffer(rows: 4, cols: 4, scrollbackBytes: 20 * 4096);
      final pin = ReflowPin(row: 3, col: 3);

      buffer.resizeReflowing(newRows: 2, newCols: 4, pins: [pin]);

      expect(pin.row, 1);
      expect(pin.col, 3);
    });
  });

  group('repeated resizes', () {
    test('returns to its starting shape across a narrow and back', () {
      final buffer = Buffer(rows: 3, cols: 12, scrollbackBytes: 40 * 4096);
      _write(buffer, 0, 'the quick br');
      _write(buffer, 1, 'own fox     ', wrapped: true);
      _write(buffer, 2, 'jumps       ');

      for (var cols = 11; cols >= 2; cols--) {
        buffer.resizeReflowing(newRows: 3, newCols: cols);
      }
      buffer.resizeReflowing(newRows: 3, newCols: 12);

      expect(_all(buffer), ['the quick br', 'own fox     ', 'jumps       ']);
      expect(_wraps(buffer), [false, true, false]);
      _expectDistinctSlots(buffer);
    });

    test('survives a drag that changes rows and columns together', () {
      final buffer = Buffer(rows: 4, cols: 10, scrollbackBytes: 40 * 4096);
      _write(buffer, 0, 'alpha beta');
      _write(buffer, 1, ' gamma    ', wrapped: true);

      buffer
        ..resizeReflowing(newRows: 2, newCols: 6)
        ..resizeReflowing(newRows: 6, newCols: 20);

      expect(_all(buffer).first, 'alpha beta gamma    ');
      _expectDistinctSlots(buffer);
    });
  });
}
