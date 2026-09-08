// Test file: heavy on focused unit assertions, light on dependencies.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _screen({int rows = 2, int cols = 8, int scrollbackBytes = 1 << 16}) =>
    Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);

void _write(Screen screen, String input) =>
    VtParser(sink: screen).advance(utf8.encode(input));

/// Enough lines to push some of them off the top into history.
void _fill(Screen screen) {
  _write(screen, [for (var i = 1; i <= 6; i++) 'line $i'].join('\r\n'));
  screen.flushPending();
}

void main() {
  group('ED 3', () {
    test('drops the history', () {
      final screen = _screen();
      _fill(screen);
      expect(screen.selectionLines().length, greaterThan(2));

      _write(screen, '\x1b[3J');

      expect(screen.selectionLines(), ['line 5', 'line 6']);
    });

    test('leaves the display alone', () {
      // The point of it being its own sequence: `ESC[3J` is half of a full
      // clear, and on its own it takes nothing off the screen.
      final screen = _screen();
      _fill(screen);

      _write(screen, '\x1b[3J');

      expect(screen.selectionLines(), contains('line 6'));
    });

    test('brings a scrolled-back view home', () {
      // The rows it was showing no longer exist, so staying put would be
      // looking at nothing.
      final screen = _screen();
      _fill(screen);
      screen.setViewOffset(2);
      expect(screen.viewOffset, 2);

      _write(screen, '\x1b[3J');

      expect(screen.viewOffset, 0);
    });

    test('is a no-op on a screen that keeps no history', () {
      final screen = _screen(scrollbackBytes: 0);
      _fill(screen);

      _write(screen, '\x1b[3J');

      expect(screen.selectionLines(), ['line 5', 'line 6']);
    });

    test('leaves the screen usable afterwards', () {
      final screen = _screen();
      _fill(screen);

      _write(screen, '\x1b[3J\x1b[2J\x1b[H');
      _write(screen, 'fresh');
      screen.flushPending();

      expect(screen.selectionLines(), ['fresh']);
    });
  });

  group('ED 2', () {
    test('clears the display and keeps the history', () {
      final screen = _screen();
      _fill(screen);

      _write(screen, '\x1b[2J');
      screen.flushPending();

      expect(screen.selectionLines(), ['line 1', 'line 2', 'line 3', 'line 4']);
    });
  });

  group('EL', () {
    test('ignores a parameter it has no meaning for', () {
      // EL has no parameter 3; it must not be read as ED's.
      final screen = _screen();
      _fill(screen);
      final before = screen.selectionLines();

      _write(screen, '\x1b[3K');

      expect(screen.selectionLines(), before);
    });
  });
}
