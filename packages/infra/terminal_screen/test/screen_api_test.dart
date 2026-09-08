import 'dart:convert';

import 'package:terminal_screen/src/sgr.dart' show Pen, applySgr;
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

Screen _screen({int rows = 4, int cols = 10, int scrollbackBytes = 0}) =>
    Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);

void _feed(Screen screen, String input) {
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
}

void main() {
  group('the viewport', () {
    test('scrolls up into history and back down by a delta', () {
      final screen = _screen(scrollbackBytes: 10 * 4096);
      _feed(screen, 'a\r\nb\r\nc\r\nd\r\ne\r\nf');

      expect(screen.scrollViewportBy(1), 1);
      expect(screen.viewOffset, 1);
      expect(screen.scrollViewportBy(-1), 0);
      expect(screen.viewOffset, 0);
    });

    // The offset is clamped, so a delta past the end of history reports the
    // offset that was actually applied rather than the one asked for.
    test('reports the offset it could actually apply', () {
      final screen = _screen(scrollbackBytes: 10 * 4096);
      _feed(screen, 'a\r\nb\r\nc\r\nd\r\ne\r\nf');

      expect(screen.scrollViewportBy(500), screen.maxViewOffset);
    });
  });

  group('diffing', () {
    test('a diff against an earlier snapshot reports what changed', () {
      final screen = _screen();
      final before = screen.snapshot();
      _feed(screen, 'hi');

      final diff = screen.diffSince(before);

      expect(diff.isEmpty, isFalse);
      expect(diff.cells.map((c) => c.after.char), containsAll(['h', 'i']));
    });

    test('a diff against the present reports nothing', () {
      final screen = _screen();
      _feed(screen, 'hi');

      expect(screen.diffSince(screen.snapshot()).isEmpty, isTrue);
    });

    test('changes on one row count as one row', () {
      final screen = _screen();
      final before = screen.snapshot();
      _feed(screen, 'hi');

      expect(computeDiff(before, screen.snapshot()).changedRowCount, 1);
    });

    test('changes spread over rows are counted once each', () {
      final screen = _screen();
      final before = screen.snapshot();
      _feed(screen, 'a\r\nb\r\nc');

      expect(computeDiff(before, screen.snapshot()).changedRowCount, 3);
    });

    test('an empty diff counts no rows', () {
      final screen = _screen();
      final snapshot = screen.snapshot();

      expect(computeDiff(snapshot, snapshot).changedRowCount, 0);
    });
  });

  group('waiting for text', () {
    // Text already on screen must not wait for the next mutation — nothing
    // is coming, and the waiter would sit there until it timed out.
    test('completes at once when the text is already there', () {
      final screen = _screen();
      _feed(screen, 'ready');

      return expectLater(
        screen.waitForText(
          'ready',
          timeout: const Duration(milliseconds: 1),
          includeScrollback: true,
        ),
        completion(isA<ScreenSnapshot>()),
      );
    });

    test('completes at once when the text is only in history', () {
      final screen = _screen(scrollbackBytes: 10 * 4096);
      _feed(screen, 'gone\r\na\r\nb\r\nc\r\nd\r\ne');

      return expectLater(
        screen.waitForText(
          'gone',
          timeout: const Duration(milliseconds: 1),
          includeScrollback: true,
        ),
        completion(isA<ScreenSnapshot>()),
      );
    });
  });

  group('SGR colour selection', () {
    test('takes truecolor from the colon form', () {
      final screen = _screen();
      _feed(screen, '\x1B[38:2:10:20:30mx');

      expect(screen.cellAt(0, 0).fg, const RgbColor(10, 20, 30));
    });

    // Some emitters put a colour space in front of the components, making
    // the group six long; the components are then the last three.
    test('skips the colour space when one is present', () {
      final screen = _screen();
      _feed(screen, '\x1B[38:2:0:10:20:30mx');

      expect(screen.cellAt(0, 0).fg, const RgbColor(10, 20, 30));
    });

    test('takes an indexed colour from the colon form', () {
      final screen = _screen();
      _feed(screen, '\x1B[38:5:200mx');

      expect(screen.cellAt(0, 0).fg, const IndexedColor(200));
    });

    test('ignores a colon form with too few components', () {
      final screen = _screen();
      _feed(screen, '\x1B[38:2:10mx');

      expect(screen.cellAt(0, 0).fg, isA<DefaultForeground>());
    });

    // `CSI m` with nothing in it means SGR 0. The parser always hands over a
    // default parameter, so this contract only shows at the helper itself.
    test('no parameters at all is a reset', () {
      final pen = Pen()
        ..fg = const IndexedColor(1)
        ..bg = const IndexedColor(2)
        ..attrs = CellAttrs.setBold(CellAttrs.none);

      applySgr(pen, const []);

      expect(pen.fg, isA<DefaultForeground>());
      expect(pen.bg, isA<DefaultBackground>());
      expect(pen.attrs, CellAttrs.none);
    });
  });

  group('resize behaviour', () {
    test('a reflowing child keeps its own history and cursor line', () {
      const behavior = ReflowingResize();

      expect(behavior.revealsHistoryOnGrow, isTrue);
      expect(behavior.defersMainBufferOnAltScreen, isFalse);
    });

    // A repainting child redraws from the top after a resize, so the main
    // buffer must not be reflowed underneath an alt screen it is about to
    // repaint over.
    test(
      'a repainting child defers the main buffer while on the alt screen',
      () {
        const behavior = RepaintingResize();

        expect(behavior.revealsHistoryOnGrow, isFalse);
        expect(behavior.defersMainBufferOnAltScreen, isTrue);
      },
    );
  });
}
