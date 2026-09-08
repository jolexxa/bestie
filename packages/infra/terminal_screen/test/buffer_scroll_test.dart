// Separate arrange / act statements read better than cascades here.

import 'package:terminal_screen/src/buffer.dart';
import 'package:terminal_screen/src/color.dart';
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

String _read(Buffer buffer, int row) => _readFrom(buffer, buffer.rowBase(row));

String _readScrollback(Buffer buffer, int line) =>
    _readFrom(buffer, Buffer.scrollbackHandle(line));

/// Every viewport row must be backed by its own slot. Two rows sharing
/// one would make a write to either silently appear in both.
void _expectNoAliasedRows(Buffer buffer) {
  final seen = <int>{};
  for (var row = 0; row < buffer.rows; row++) {
    expect(
      seen.add(buffer.rowBase(row)),
      isTrue,
      reason: 'viewport row $row shares a slot with another row',
    );
  }
}

Buffer _filled({int rows = 6, int cols = 4, int scrollbackBytes = 0}) {
  final buffer = Buffer(
    rows: rows,
    cols: cols,
    scrollbackBytes: scrollbackBytes,
  );
  for (var row = 0; row < rows; row++) {
    _write(buffer, row, 'r$row');
  }
  return buffer;
}

void main() {
  group('scrollRegionUp', () {
    test('shifts the region up and blanks its bottom row', () {
      final buffer = _filled()..scrollRegionUp(1, 3);

      expect(_read(buffer, 1), 'r2');
      expect(_read(buffer, 2), 'r3');
      expect(_read(buffer, 3), '');
    });

    test('leaves rows outside the region untouched', () {
      final buffer = _filled()..scrollRegionUp(1, 3);

      expect(_read(buffer, 0), 'r0');
      expect(_read(buffer, 4), 'r4');
      expect(_read(buffer, 5), 'r5');
    });

    test('carries each soft-wrap marker with the row it belongs to', () {
      final buffer = _filled()
        ..setWrappedAt(2, wrapped: true)
        ..scrollRegionUp(1, 3);

      expect(buffer.wrappedAt(1), isTrue);
      expect(buffer.wrappedAt(2), isFalse);
    });

    test('clears the soft-wrap marker on the blanked row', () {
      final buffer = _filled()
        ..setWrappedAt(3, wrapped: true)
        ..scrollRegionUp(1, 3);

      expect(buffer.wrappedAt(3), isFalse);
    });

    test('blanks the bottom row with the active background', () {
      final buffer = _filled()
        ..scrollRegionUp(1, 3, background: packColor(const IndexedColor(4)));

      expect(
        buffer.bgAt(buffer.rowBase(3), 0),
        packColor(const IndexedColor(4)),
      );
    });

    test('keeps every row backed by its own slot', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollRegionUp(1, 3)
        ..scrollRegionUp(0, 5)
        ..scrollRegionUp(2, 4);

      _expectNoAliasedRows(buffer);
    });

    test('a single-row region just blanks that row', () {
      final buffer = _filled()..scrollRegionUp(2, 2);

      expect(_read(buffer, 2), '');
      expect(_read(buffer, 1), 'r1');
      expect(_read(buffer, 3), 'r3');
    });
  });

  group('scrollRegionDown', () {
    test('shifts the region down and blanks its top row', () {
      final buffer = _filled()..scrollRegionDown(1, 3);

      expect(_read(buffer, 1), '');
      expect(_read(buffer, 2), 'r1');
      expect(_read(buffer, 3), 'r2');
    });

    test('leaves rows outside the region untouched', () {
      final buffer = _filled()..scrollRegionDown(1, 3);

      expect(_read(buffer, 0), 'r0');
      expect(_read(buffer, 4), 'r4');
      expect(_read(buffer, 5), 'r5');
    });

    test('carries each soft-wrap marker with the row it belongs to', () {
      final buffer = _filled()
        ..setWrappedAt(1, wrapped: true)
        ..scrollRegionDown(1, 3);

      expect(buffer.wrappedAt(2), isTrue);
      expect(buffer.wrappedAt(1), isFalse);
    });

    test('blanks the top row with the active background', () {
      final buffer = _filled()
        ..scrollRegionDown(1, 3, background: packColor(const IndexedColor(5)));

      expect(
        buffer.bgAt(buffer.rowBase(1), 0),
        packColor(const IndexedColor(5)),
      );
    });

    test('keeps every row backed by its own slot', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollRegionDown(1, 3)
        ..scrollRegionDown(0, 5)
        ..scrollRegionDown(2, 4);

      _expectNoAliasedRows(buffer);
    });
  });

  group('scrollTopRegionUpToScrollback', () {
    test('evicts the top row into scrollback', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollTopRegionUpToScrollback(2);

      expect(buffer.scrollbackLength, 1);
      expect(_readScrollback(buffer, 0), 'r0');
    });

    test('shifts the region up and blanks its bottom row', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollTopRegionUpToScrollback(2);

      expect(_read(buffer, 0), 'r1');
      expect(_read(buffer, 1), 'r2');
      expect(_read(buffer, 2), '');
    });

    test('preserves the rows below the region in place', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollTopRegionUpToScrollback(2);

      expect(_read(buffer, 3), 'r3');
      expect(_read(buffer, 4), 'r4');
      expect(_read(buffer, 5), 'r5');
    });

    test('preserves soft-wrap markers on the rows below the region', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..setWrappedAt(4, wrapped: true)
        ..scrollTopRegionUpToScrollback(2);

      expect(buffer.wrappedAt(4), isTrue);
      expect(buffer.wrappedAt(3), isFalse);
      expect(buffer.wrappedAt(5), isFalse);
    });

    test('clears the soft-wrap marker on the blanked row', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..setWrappedAt(3, wrapped: true)
        ..scrollTopRegionUpToScrollback(2);

      expect(buffer.wrappedAt(2), isFalse);
    });

    test('blanks the region bottom with the active background', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollTopRegionUpToScrollback(
          2,
          background: packColor(const IndexedColor(6)),
        );

      expect(
        buffer.bgAt(buffer.rowBase(2), 0),
        packColor(const IndexedColor(6)),
      );
    });

    test('scrolls the whole viewport when the region reaches the bottom', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096)
        ..scrollTopRegionUpToScrollback(5);

      expect(buffer.scrollbackLength, 1);
      expect(_readScrollback(buffer, 0), 'r0');
      expect(_read(buffer, 0), 'r1');
      expect(_read(buffer, 4), 'r5');
      expect(_read(buffer, 5), '');
    });

    test('keeps every row backed by its own slot across repeats', () {
      final buffer = _filled(scrollbackBytes: 4 * 4096);
      for (var i = 0; i < 8; i++) {
        buffer.scrollTopRegionUpToScrollback(2);
      }

      _expectNoAliasedRows(buffer);
    });

    test('keeps evicting whole lines once the byte cap is reached', () {
      const lineBytes = 2 * bytesPerCell + lineOverheadBytes;
      final buffer = _filled(scrollbackBytes: 2 * lineBytes + bytesPerCell);
      for (var i = 0; i < 5; i++) {
        _write(buffer, 0, 'x$i');
        buffer.scrollTopRegionUpToScrollback(2);
      }

      expect(buffer.scrollbackLength, 2);
      expect(_readScrollback(buffer, 1), 'x4');
      _expectNoAliasedRows(buffer);
    });
  });
}
