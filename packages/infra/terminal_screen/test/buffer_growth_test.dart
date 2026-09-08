// Scrollback content must survive growth without limit until the byte
// cap bites, and every scrolled-off row must stay readable exactly as
// it was written.

// Separate arrange statements read better than cascades in these loops.
// ignore_for_file: cascade_invocations

import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/src/logical_line.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:test/test.dart';

void _write(Buffer buffer, int row, String text) {
  final base = buffer.rowBase(row);
  for (var col = 0; col < text.length; col++) {
    buffer.setCharCodeAt(base, col, text.codeUnitAt(col));
  }
}

String _readFrom(Buffer buffer, int base) {
  final out = StringBuffer();
  for (var col = 0; col < buffer.cols; col++) {
    out.writeCharCode(buffer.charCodeAt(base, col));
  }
  return out.toString().trimRight();
}

String _readScrollback(Buffer buffer, int line) =>
    _readFrom(buffer, Buffer.scrollbackHandle(line));

/// Scroll [lines] rows off the top, numbering each so it can be
/// identified again once it lands in scrollback.
void _scrollOff(Buffer buffer, int lines) {
  for (var i = 0; i < lines; i++) {
    _write(buffer, 0, 'r$i');
    buffer.scrollUpOne();
  }
}

/// Like [_scrollOff] but with fixed-width labels, so every line costs
/// the same number of bytes.
void _scrollOffPadded(Buffer buffer, int lines) {
  for (var i = 0; i < lines; i++) {
    _write(buffer, 0, 'r${i.toString().padLeft(3, '0')}');
    buffer.scrollUpOne();
  }
}

/// Bytes one padded label line costs against the cap.
const int _paddedLineBytes = 4 * bytesPerCell + lineOverheadBytes;

void main() {
  group('history retention', () {
    test('a buffer without history drops scrolled rows', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 0);

      _scrollOff(buffer, 10);

      expect(buffer.scrollbackLength, 0);
    });

    test('keeps every scrolled-off row readable', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 500);

      expect(buffer.scrollbackLength, 500);
      for (var line = 0; line < 500; line++) {
        expect(_readScrollback(buffer, line), 'r$line');
      }
    });

    test('keeps the viewport readable', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 500);
      for (var row = 0; row < 4; row++) {
        _write(buffer, row, 'v$row');
      }

      for (var row = 0; row < 4; row++) {
        expect(_readFrom(buffer, buffer.rowBase(row)), 'v$row');
      }
    });

    test('keeps wrap markers attached to their display rows', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      // A wrap chain is a handshake: the flag set on row 1 at pass i is
      // read as "continues onward" when row 0 scrolls at pass i, and as
      // "continues above" when that same row scrolls at pass i + 1.
      for (var i = 0; i < 100; i++) {
        _write(buffer, 0, 'r$i');
        buffer.setWrappedAt(1, wrapped: i.isOdd);
        buffer.scrollUpOne();
      }

      for (var line = 0; line < 100; line++) {
        expect(
          buffer.scrollbackWrappedAt(line),
          line > 0 && line.isEven,
          reason: 'wrap marker on scrollback line $line',
        );
      }
    });

    test('recycled viewport slots are blanked, never stale', () {
      final buffer = Buffer(rows: 2, cols: 4, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 200);
      buffer.eraseRow(0);

      expect(_readFrom(buffer, buffer.rowBase(0)), '');
      expect(buffer.bgAt(buffer.rowBase(0), 0), packedDefaultBg);
    });
  });

  group('the byte cap', () {
    test('recycles the oldest lines once the budget is in use', () {
      final buffer = Buffer(
        rows: 2,
        cols: 8,
        scrollbackBytes: 100 * _paddedLineBytes,
      );

      _scrollOffPadded(buffer, 150);

      expect(buffer.scrollbackLength, 100);
      expect(_readScrollback(buffer, 0), 'r050');
      expect(_readScrollback(buffer, 99), 'r149');
    });

    test('reports the bytes it holds', () {
      final buffer = Buffer(rows: 2, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOffPadded(buffer, 10);

      expect(buffer.scrollbackBytes, 10 * _paddedLineBytes);
    });
  });

  group('interaction with the rest of the buffer', () {
    test('a resize never costs history', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 100);
      buffer.resize(newRows: 4, newCols: 6);

      expect(_readScrollback(buffer, 0), 'r0');
      expect(_readScrollback(buffer, 99), 'r99');
    });

    test('keeps growing after a resize', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 100);
      buffer.resize(newRows: 6, newCols: 10);
      _scrollOff(buffer, 400);

      expect(buffer.scrollbackLength, 500);
      expect(_readScrollback(buffer, 499), 'r399');
    });

    test('starts over after a full reset', () {
      final buffer = Buffer(rows: 4, cols: 8, scrollbackBytes: 1 << 20);

      _scrollOff(buffer, 200);
      buffer.fullReset();

      expect(buffer.scrollbackLength, 0);
      expect(_readFrom(buffer, buffer.rowBase(0)), '');

      _scrollOff(buffer, 10);
      expect(buffer.scrollbackLength, 10);
      expect(_readScrollback(buffer, 0), 'r0');
    });

    test('evicts into scrollback from a top-anchored region too', () {
      final buffer = Buffer(rows: 6, cols: 8, scrollbackBytes: 1 << 20);

      for (var i = 0; i < 200; i++) {
        _write(buffer, 0, 'r$i');
        buffer.scrollTopRegionUpToScrollback(3);
      }

      expect(buffer.scrollbackLength, 200);
      expect(_readScrollback(buffer, 0), 'r0');
      expect(_readScrollback(buffer, 199), 'r199');
    });
  });
}
