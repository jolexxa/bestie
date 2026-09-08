// The joined selectable text must be invariant across everything a live
// session does short of eviction, so char offsets into it stay pinned to
// their content. These invariants are what keep terminal selections
// anchored while the screen keeps living.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _term({required int rows, required int cols, int scrollback = 200}) =>
    Screen(rows: rows, cols: cols, scrollbackBytes: scrollback * 4096);

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

String _rangeText(Screen screen, int start, int end) {
  final text = screen.selectionText().text;
  return text.substring(
    start.clamp(0, text.length),
    end.clamp(0, text.length),
  );
}

void main() {
  const target = 'line 5: the quick brown fox';

  Screen filled({int rows = 10, int cols = 40, int lines = 20}) {
    final screen = _term(rows: rows, cols: cols);
    _feed(
      screen,
      List.generate(lines, (i) => 'line $i: the quick brown fox').join('\r\n'),
    );
    return screen;
  }

  (int, int) targetRange(Screen screen) {
    final start = screen.selectionText().text.indexOf(target);
    return (start, start + target.length);
  }

  group('selectable text offsets stay pinned across', () {
    test('width shrink', () {
      final screen = filled();
      final (start, end) = targetRange(screen);

      screen.resize(rows: 10, cols: 23);

      expect(_rangeText(screen, start, end), target);
    });

    test('width grow', () {
      final screen = filled(cols: 23);
      final (start, end) = targetRange(screen);

      screen.resize(rows: 10, cols: 60);

      expect(_rangeText(screen, start, end), target);
    });

    test('height shrink and grow', () {
      final screen = filled();
      final (start, end) = targetRange(screen);

      screen.resize(rows: 6, cols: 40);
      expect(_rangeText(screen, start, end), target);

      screen.resize(rows: 14, cols: 40);
      expect(_rangeText(screen, start, end), target);
    });

    test('appended output while under the cap', () {
      final screen = filled(lines: 15);
      final (start, end) = targetRange(screen);

      _feed(screen, '\r\nmore output\r\neven more');

      expect(_rangeText(screen, start, end), target);
    });

    test('resize with the cursor parked past the last glyph', () {
      final screen = filled(lines: 8);
      _feed(screen, '\r\nprompt> ');
      final (start, end) = targetRange(screen);

      screen.resize(rows: 10, cols: 25);

      expect(_rangeText(screen, start, end), target);
    });
  });

  test('evictedSelectionChars re-anchors offsets across eviction', () {
    final screen = Screen(rows: 4, cols: 20, scrollbackBytes: 1200);
    _feed(screen, List.generate(8, (i) => 'row number $i').join('\r\n'));

    const target = 'row number 5';
    final baseline = screen.evictedSelectionChars;
    final start = screen.selectionText().text.indexOf(target) + baseline;

    _feed(screen, '\r\n${List.generate(6, (i) => 'noise $i').join('\r\n')}');

    final shifted = start - screen.evictedSelectionChars;
    expect(screen.evictedSelectionChars, greaterThan(baseline));
    expect(
      screen.selectionText().text.substring(
        shifted,
        shifted + target.length,
      ),
      target,
    );
  });

  test('eviction reports exactly the chars that left the text', () {
    // A row padded to the margin wrapping into a continuation that holds
    // nothing: the padding is stored, but the selectable text never had it,
    // so evicting the line must not claim those chars went with it.
    final screen = Screen(rows: 3, cols: 10, scrollbackBytes: 700);
    _feed(screen, 'abc${' ' * 7}${' ' * 7}\r\n');
    _feed(screen, 'one\r\ntwo\r\n');

    var text = screen.selectionText().text;
    var evicted = screen.evictedSelectionChars;
    var everEvicted = false;

    for (final word in ['three', 'four', 'five', 'six']) {
      _feed(screen, '$word\r\n');
      final grown = screen.selectionText().text;
      final dropped = screen.evictedSelectionChars - evicted;
      everEvicted |= dropped > 0;

      expect(dropped, lessThanOrEqualTo(text.length));
      expect(grown, startsWith(text.substring(dropped)));

      text = grown;
      evicted = screen.evictedSelectionChars;
    }

    expect(everEvicted, isTrue, reason: 'nothing ever evicted');
  });

  test('the full text round-trips a width resize unchanged', () {
    final screen = filled();
    final before = screen.selectionText().text;

    screen.resize(rows: 10, cols: 23);
    final mid = screen.selectionText().text;
    screen.resize(rows: 10, cols: 40);
    final after = screen.selectionText().text;

    expect(mid, before);
    expect(after, before);
  });
}
