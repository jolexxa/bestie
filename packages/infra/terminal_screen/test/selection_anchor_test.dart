// Anchors hold a position to its content rather than to an offset, so the
// things that move the selectable text — eviction off the front, a wrapped
// line ending, a row scrolling out of the viewport, a re-wrap — leave a
// caller reading back the same characters it pinned.

import 'dart:convert';

import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

/// What the [length] characters from [anchor] hold now.
String _textAt(Screen screen, SelectionAnchor anchor, int length) {
  final at = screen.offsetOfAnchor(anchor);
  if (at == null) return '<gone>';
  final text = screen.selectionText().text;
  return text.substring(
    at.clamp(0, text.length),
    (at + length).clamp(0, text.length),
  );
}

/// An anchor on the first occurrence of [target].
SelectionAnchor _anchorOn(Screen screen, String target) {
  final at = screen.selectionText().text.indexOf(target);
  expect(at, isNonNegative, reason: 'target not on screen: $target');
  return screen.anchorAt(at)!;
}

void main() {
  group('a held anchor keeps its content across', () {
    // The event offsets cannot survive: an open tail line's padding to the
    // margin is content while the viewport carries the line onward, and stops
    // being content the moment the line ends. Everything below the seam
    // slides, and no eviction reports that it did.
    test('the tail line closing under it', () {
      final screen = Screen(rows: 3, cols: 10, scrollbackBytes: 1 << 16);
      _feed(screen, 'abc${' ' * 7}${' ' * 7}\r\n');
      _feed(screen, 'one\r\n');
      final anchor = _anchorOn(screen, 'one');

      _feed(screen, 'two\r\n');

      expect(_textAt(screen, anchor, 3), 'one');
    });

    test('rows scrolling out of the viewport into history', () {
      final screen = Screen(rows: 4, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\n');
      final anchor = _anchorOn(screen, 'bravo');

      _feed(screen, 'd\r\ne\r\nf\r\ng\r\nh\r\n');

      expect(screen.scrollbackLength, greaterThan(0));
      expect(_textAt(screen, anchor, 5), 'bravo');
    });

    test('eviction off the front of history', () {
      final screen = Screen(rows: 4, cols: 20, scrollbackBytes: 1200);
      _feed(screen, List.generate(8, (i) => 'row number $i').join('\r\n'));
      final anchor = _anchorOn(screen, 'row number 6');

      _feed(screen, '\r\n${List.generate(6, (i) => 'noise $i').join('\r\n')}');

      expect(screen.evictedSelectionChars, greaterThan(0));
      expect(_textAt(screen, anchor, 12), 'row number 6');
    });

    test('a width shrink that re-wraps history', () {
      final screen = Screen(rows: 6, cols: 40, scrollbackBytes: 1 << 16);
      _feed(
        screen,
        List.generate(14, (i) => 'line $i: the quick brown fox').join('\r\n'),
      );
      final anchor = _anchorOn(screen, 'line 5: the quick brown fox');

      screen.resize(rows: 6, cols: 23);

      expect(_textAt(screen, anchor, 27), 'line 5: the quick brown fox');
    });

    test('a width grow that re-wraps history', () {
      final screen = Screen(rows: 6, cols: 23, scrollbackBytes: 1 << 16);
      _feed(
        screen,
        List.generate(14, (i) => 'line $i: the quick brown fox').join('\r\n'),
      );
      final anchor = _anchorOn(screen, 'line 5: the quick brown fox');

      screen.resize(rows: 6, cols: 60);

      expect(_textAt(screen, anchor, 27), 'line 5: the quick brown fox');
    });

    // A growing viewport takes whole closed lines back out of history and
    // draws them again, so an anchor pinned to one of those lines has to come
    // back down with it rather than be left holding a line that has gone.
    test('a growing viewport pulling its line back out of history', () {
      final screen = Screen(rows: 3, cols: 20, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\necho\r\n');
      expect(screen.scrollbackLength, greaterThan(0));
      final anchor = _anchorOn(screen, 'charlie');

      screen.resize(rows: 9, cols: 21);

      expect(screen.scrollbackLength, 0, reason: 'history was not pulled back');
      expect(_textAt(screen, anchor, 7), 'charlie');
    });

    test('a taller viewport pulling it back without re-wrapping', () {
      final screen = Screen(rows: 3, cols: 20, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\necho\r\n');
      final anchor = _anchorOn(screen, 'bravo');

      screen.resize(rows: 9, cols: 20);

      expect(screen.scrollbackLength, 0, reason: 'history was not pulled back');
      expect(_textAt(screen, anchor, 5), 'bravo');
    });

    test('lines inserted above it inside the viewport', () {
      final screen = Screen(rows: 8, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      _feed(screen, '\x1b[H\x1b[3L');

      expect(_textAt(screen, anchor, 5), 'alpha');
    });

    test('lines deleted above it inside the viewport', () {
      final screen = Screen(rows: 8, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'one\r\ntwo\r\nalpha\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      _feed(screen, '\x1b[H\x1b[2M');

      expect(_textAt(screen, anchor, 5), 'alpha');
    });

    test('characters inserted before it on its row', () {
      final screen = Screen(rows: 6, cols: 20, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      _feed(screen, '\x1b[H\x1b[2@');

      expect(_textAt(screen, anchor, 5), 'alpha');
    });

    test('characters deleted before it on its row', () {
      final screen = Screen(rows: 6, cols: 20, scrollbackBytes: 1 << 16);
      _feed(screen, 'xxalpha\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      _feed(screen, '\x1b[H\x1b[2P');

      expect(_textAt(screen, anchor, 5), 'alpha');
    });

    test('a scroll region moving it up the screen', () {
      final screen = Screen(rows: 8, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'one\r\ntwo\r\nalpha\r\nbravo\r\n');
      final anchor = _anchorOn(screen, 'bravo');

      // A region that excludes the top rows, scrolled up inside itself.
      _feed(screen, '\x1b[3;6r\x1b[6;1H\n');

      expect(_textAt(screen, anchor, 5), 'bravo');
    });

    // A resize taken while the alt screen is up is deferred, and settles on
    // the main buffer the moment the alt screen is put away.
    test('a resize deferred behind the alt screen', () {
      final screen = Screen(rows: 15, cols: 18, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\n');
      final anchor = _anchorOn(screen, 'charlie');

      _feed(screen, '\x1b[?1049h');
      screen.resize(rows: 8, cols: 24);
      _feed(screen, '\x1b[?1049l');

      expect(screen.onAltScreen, isFalse);
      expect(_textAt(screen, anchor, 7), 'charlie');
    });

    // A re-wrap does not always lay the same characters out again: a row that
    // was empty at one width can become padding inside a wrapped line at
    // another. A live position has to ride the re-wrap, not trust its offset.
    test('a width shrink that re-wraps the row it sits on', () {
      final screen = Screen(rows: 6, cols: 20, scrollbackBytes: 1 << 16);
      _feed(screen, 'aaaaaaaaaaaaaaaaaaaTARGET');
      final anchor = _anchorOn(screen, 'TARGET');

      screen.resize(rows: 6, cols: 7);

      expect(_textAt(screen, anchor, 6), 'TARGET');
    });

    test('a resize while the anchor is still in the live viewport', () {
      final screen = Screen(rows: 6, cols: 40, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo charlie\r\ndelta\r\n');
      final anchor = _anchorOn(screen, 'bravo charlie');

      screen.resize(rows: 6, cols: 9);

      expect(_textAt(screen, anchor, 13), 'bravo charlie');
    });
  });

  group('an anchor whose content is gone', () {
    test('collapses to the front once its line evicts', () {
      final screen = Screen(rows: 3, cols: 12, scrollbackBytes: 700);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      for (var i = 0; i < 12; i++) {
        _feed(screen, 'noise $i\r\n');
      }

      expect(screen.evictedSelectionChars, greaterThan(0));
      expect(screen.offsetOfAnchor(anchor), 0);
    });

    test('reads as gone once released', () {
      final screen = Screen(rows: 3, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\n');
      final anchor = _anchorOn(screen, 'alpha');

      screen.releaseAnchor(anchor);

      expect(screen.offsetOfAnchor(anchor), isNull);
    });

    test('reads as gone on a screen that never handed it out', () {
      final screen = Screen(rows: 3, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\n');
      final other = Screen(rows: 3, cols: 12, scrollbackBytes: 1 << 16);
      _feed(other, 'alpha\r\n');

      expect(other.offsetOfAnchor(_anchorOn(screen, 'alpha')), isNull);
    });
  });

  group('anchorAt', () {
    test('refuses an offset past the end of the text', () {
      final screen = Screen(rows: 3, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\n');

      expect(screen.anchorAt(screen.selectionContentLength() + 1), isNull);
      expect(screen.anchorAt(-1), isNull);
    });

    test('round-trips the offset it was taken at', () {
      final screen = Screen(rows: 4, cols: 12, scrollbackBytes: 1 << 16);
      _feed(screen, 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\n');

      final text = screen.selectionText().text;
      for (var at = 0; at < text.length; at++) {
        expect(
          screen.offsetOfAnchor(screen.anchorAt(at)!),
          at,
          reason: 'offset $at of ${jsonEncode(text)}',
        );
      }
    });
  });
}
