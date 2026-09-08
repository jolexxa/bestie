import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

/// A screen with a deliberately small history.
Screen _screen({
  required int rows,
  required int cols,
  required int scrollbackBytes,
}) => Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);

/// Collects what a screen drops. [lines] fills as the screen is fed, because
/// eviction is reported inside the mutation that does it.
class _Evicted {
  _Evicted(this._screen) {
    _screen.onEvicted = (text, pen, units) => lines.add(utf8.decode(text));
  }

  final Screen _screen;

  /// The text of every line dropped, which is what these tests are about.
  final List<String> lines = [];

  /// Stops collecting, the way a recorder that has seen enough would.
  void stop() => _screen.onEvicted = null;
}

String _numbered(int from, int to) => [
  for (var i = from; i <= to; i++) 'line $i',
].join('\r\n');

void main() {
  test('says nothing while the history still fits', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 20000);
    final evicted = _Evicted(screen).lines;

    _feed(screen, _numbered(1, 20));

    expect(evicted, isEmpty);
  });

  test('hands over each line it drops, oldest first', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 2400);
    final evicted = _Evicted(screen).lines;

    _feed(screen, _numbered(1, 30));

    expect(evicted, isNotEmpty);
    expect(evicted.first, 'line 1');
    expect(evicted, [
      for (var i = 1; i <= evicted.length; i++) 'line $i',
    ]);
  });

  test('what it dropped and what it kept make the whole, with no seam', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 2400);
    final evicted = _Evicted(screen).lines;

    _feed(screen, _numbered(1, 40));

    expect(
      [...evicted, ...screen.selectionLines()],
      [
        for (var i = 1; i <= 40; i++) 'line $i',
      ],
    );
  });

  test('renders a dropped line the way it would have read on screen', () {
    // Long enough to soft-wrap several times: a logical line is stored
    // unwrapped, so what leaves is the line the child printed, not the rows
    // the terminal broke it into.
    final screen = _screen(rows: 3, cols: 10, scrollbackBytes: 700);
    final evicted = _Evicted(screen).lines;
    final long = 'a' * 45;

    _feed(screen, '$long\r\n${_numbered(1, 20)}');

    expect(evicted.first, long);
  });

  test('keeps a blank line, which is content like any other', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 2000);
    final evicted = _Evicted(screen).lines;

    _feed(screen, 'first\r\n\r\nthird\r\n${_numbered(1, 25)}');

    expect(evicted.take(3), ['first', '', 'third']);
  });

  test('hands over the history it is told to erase', () {
    // `ESC[3J` takes the history off the screen. Off the screen is not
    // unprinted, so what it drops leaves the same way anything else does.
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 20000);
    final evicted = _Evicted(screen).lines;
    _feed(screen, _numbered(1, 20));
    expect(evicted, isEmpty, reason: 'nothing has overflowed yet');

    _feed(screen, '\x1b[3J');

    expect(
      [...evicted, ...screen.selectionLines()],
      [
        for (var i = 1; i <= 20; i++) 'line $i',
      ],
    );
  });

  test('lets go of a pin into the history it hands over', () {
    // Erasing the history drops the line a pin was holding, so afterwards the
    // pin reports the front of what survived rather than a place in text that
    // is no longer there.
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 20000);
    final evicted = _Evicted(screen).lines;
    _feed(screen, _numbered(1, 20));
    final anchor = screen.anchorAt(30)!;
    expect(screen.offsetOfAnchor(anchor), 30, reason: 'held where it was put');

    _feed(screen, '\x1b[3J');

    expect(screen.offsetOfAnchor(anchor), 0);
    expect(evicted, isNotEmpty);
  });

  test('says nothing for a screen that keeps no history at all', () {
    // The alt screen: a child that repaints has nothing to scroll back to.
    final screen = Screen(rows: 3, cols: 10, scrollbackBytes: 0);
    final evicted = _Evicted(screen).lines;

    _feed(screen, _numbered(1, 40));

    expect(evicted, isEmpty);
  });

  test('a resize that hands history back does not re-report it', () {
    // `_resizeWithReflow` pulls closed lines out of the store and pushes the
    // re-wrapped rows back in, closing them a second time. Reporting on
    // closure would double-count every one of them; reporting on eviction
    // cannot, because an evicted line is never handed back.
    final screen = _screen(rows: 6, cols: 40, scrollbackBytes: 30000);
    final evicted = _Evicted(screen).lines;
    _feed(screen, _numbered(1, 30));
    expect(evicted, isEmpty, reason: 'nothing has overflowed yet');

    screen
      ..resize(rows: 6, cols: 12)
      ..resize(rows: 20, cols: 60)
      ..resize(rows: 6, cols: 40);

    expect(evicted, isEmpty);
    expect(screen.selectionLines(), [
      for (var i = 1; i <= 30; i++) 'line $i',
    ]);
  });

  test('a resize under pressure reports only what it actually drops', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 3000);
    final evicted = _Evicted(screen).lines;
    _feed(screen, _numbered(1, 40));
    final droppedBefore = [...evicted];

    screen
      ..resize(rows: 4, cols: 8)
      ..resize(rows: 4, cols: 20);

    expect(
      evicted.take(droppedBefore.length),
      droppedBefore,
      reason: 'already-dropped lines are never revisited',
    );
    expect(
      [...evicted, ...screen.selectionLines()],
      [
        for (var i = 1; i <= 40; i++) 'line $i',
      ],
    );
  });

  test('stops reporting once nobody is listening', () {
    final screen = _screen(rows: 4, cols: 20, scrollbackBytes: 2000);
    final capture = _Evicted(screen);
    _feed(screen, _numbered(1, 25));
    expect(capture.lines, isNotEmpty);

    final seen = capture.lines.length;
    capture.stop();
    _feed(screen, '\r\n${_numbered(26, 50)}');

    expect(capture.lines, hasLength(seen));
  });
}
