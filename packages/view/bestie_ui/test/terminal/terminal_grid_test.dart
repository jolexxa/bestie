// Test file: heavy on focused unit assertions, light on dependencies.

import 'dart:convert';
import 'dart:math' as math;

import 'package:bestie_ui/src/terminal/terminal_grid.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas is not on the public nocterm surface; the paint tests
// need it to read back the cells the grid drew.
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

ts.Screen _screenWith(String input, {int rows = 3, int cols = 6}) {
  final s = ts.Screen(rows: rows, cols: cols, scrollbackBytes: 0 * 4096);
  VtParser(sink: s).advance(utf8.encode(input));
  s.snapshot();
  return s;
}

void main() {
  group('RenderTerminalGrid Selectable', () {
    test('selectableText trims padding and drops the trailing blank row', () {
      // 3-row screen: "ab", "cde", then a blank row. Copy trims each
      // line's trailing padding and drops the trailing blank row.
      final screen = _screenWith('ab\r\ncde');
      final grid = RenderTerminalGrid(screen: screen);

      expect(grid.selectableText, 'ab\ncde');
    });

    test('selectableLayout exposes one line per logical line', () {
      final screen = _screenWith('ab\r\ncde');
      final grid = RenderTerminalGrid(screen: screen);

      final layout = grid.selectableLayout!;
      expect(layout.lines, ['ab', 'cde']);
      expect(layout.actualWidth, 6);
      expect(layout.actualHeight, 2);
    });

    test('joins a soft-wrapped line back into one', () {
      // "abcdef" prints past a 4-col margin, wrapping onto a second
      // row; the copy rejoins it with no newline.
      final screen = _screenWith('abcdef', cols: 4);
      final grid = RenderTerminalGrid(screen: screen);

      expect(grid.selectableText, 'abcdef');
    });

    test('selectableText prepends scrollback rows in order', () {
      // 2-row screen with 5 lines of scrollback. After feeding 4
      // newlines worth of content, the first 2 ("aa", "bb") fall
      // into scrollback and only "cc"/"dd" remain in the viewport.
      final screen = ts.Screen(rows: 2, cols: 4, scrollbackBytes: 5 * 4096);
      VtParser(sink: screen).advance(utf8.encode('aa\r\nbb\r\ncc\r\ndd'));
      screen.snapshot();
      expect(screen.scrollbackLength, 2);

      final grid = RenderTerminalGrid(screen: screen);
      // 4 buffer rows: 2 scrollback ("aa", "bb") + 2 live ("cc", "dd").
      expect(grid.selectableLayout!.lines, ['aa', 'bb', 'cc', 'dd']);
    });

    test('getCharacterIndexAtLocalPosition translates viewport row '
        'to buffer row using viewOffset', () {
      // 2-row screen, scrollback = ["aa", "bb"], viewport = ["cc", "dd"].
      final screen = ts.Screen(rows: 2, cols: 4, scrollbackBytes: 5 * 4096);
      VtParser(sink: screen).advance(utf8.encode('aa\r\nbb\r\ncc\r\ndd'));
      screen.snapshot();
      final grid = RenderTerminalGrid(screen: screen);

      // Lines are trimmed to "aa"/"bb"/"cc"/"dd", so the joined text is
      // "aa\nbb\ncc\ndd" and each row starts three chars after the last.
      // viewOffset = 0 → viewport row 0 is buffer row 2 ("cc") at 6.
      expect(
        grid.getCharacterIndexAtLocalPosition(Offset.zero),
        6,
      );
      // viewOffset = 0 → viewport row 1 is buffer row 3 ("dd"), at 9.
      expect(
        grid.getCharacterIndexAtLocalPosition(const Offset(0, 1)),
        9,
      );

      // Scroll up by 2 → viewport row 0 is now buffer row 0 ("aa") at 0.
      screen.setViewOffset(2);
      expect(
        grid.getCharacterIndexAtLocalPosition(Offset.zero),
        0,
      );
      // viewport row 1 is now buffer row 1 ("bb") at 3.
      expect(
        grid.getCharacterIndexAtLocalPosition(const Offset(0, 1)),
        3,
      );
    });

    test('getCharacterIndexAtLocalPosition rounds to nearest column', () {
      final screen = _screenWith('hello', rows: 1, cols: 10);
      final grid = RenderTerminalGrid(screen: screen);

      // x = 0.0 → start of row → index 0
      expect(grid.getCharacterIndexAtLocalPosition(Offset.zero), 0);
      // x = 0.4 → still col 0 (under midpoint) → index 0
      expect(grid.getCharacterIndexAtLocalPosition(const Offset(0.4, 0)), 0);
      // x = 0.6 → col 1 (past midpoint of col 0) → index 1
      expect(grid.getCharacterIndexAtLocalPosition(const Offset(0.6, 0)), 1);
      // x = 5.0 → col 5 → index 5 (the space after "hello")
      expect(grid.getCharacterIndexAtLocalPosition(const Offset(5, 0)), 5);
    });

    test('cache invalidates when screen.mutationCount bumps', () {
      final screen = _screenWith('one', rows: 2, cols: 5);
      final grid = RenderTerminalGrid(screen: screen);
      expect(grid.selectableLayout!.lines.first, 'one');

      // Print more content; the cache must rebuild on next read.
      VtParser(sink: screen).advance(utf8.encode('!'));
      screen.snapshot();
      expect(grid.selectableLayout!.lines.first, 'one!');
    });

    test('lazy text build is consistent with eager char-index math', () {
      // The `selectableText` string and the `selectionMetrics` offset
      // index come from separate calls but must produce the same
      // mapping. This test guards against drift: an index returned
      // by getCharacterIndexAtLocalPosition must point at the same
      // character that selectableText says lives there.
      final screen = ts.Screen(rows: 2, cols: 4, scrollbackBytes: 5 * 4096);
      VtParser(sink: screen).advance(utf8.encode('aa\r\nbb\r\ncc\r\ndd'));
      screen.snapshot();
      final grid = RenderTerminalGrid(screen: screen);

      // Touch getCharacterIndexAtLocalPosition FIRST (forces only
      // the eager metrics path to populate). Then read text — that
      // triggers the lazy text build. They must agree.
      final indexForCcRow0 = grid.getCharacterIndexAtLocalPosition(Offset.zero);
      final text = grid.selectableText;
      expect(text[indexForCcRow0], 'c');

      // Same check for a column inside the row.
      final indexForCcCol1 = grid.getCharacterIndexAtLocalPosition(
        const Offset(1, 0),
      );
      expect(text[indexForCcCol1], 'c');

      // And for the second viewport row ("dd" → buffer row 3).
      final indexForDdCol1 = grid.getCharacterIndexAtLocalPosition(
        const Offset(1, 1),
      );
      expect(text[indexForDdCol1], 'd');
    });

    test('drops the selection when eviction runs backwards', () {
      // Eviction is monotonic on the main buffer, but entering the alt
      // screen reports zero evicted chars — a backwards jump. A selection
      // anchored in the (now-gone) main-buffer history is dropped rather
      // than re-anchored onto the wrong text.
      final screen = ts.Screen(rows: 2, cols: 4, scrollbackBytes: 64);
      VtParser(sink: screen).advance(
        utf8.encode(List.generate(30, (i) => 'row$i').join('\r\n')),
      );
      screen.snapshot();

      // A read with no selection catches _seenEvictedChars up to the main
      // buffer's evicted count.
      final grid = RenderTerminalGrid(screen: screen);
      expect(grid.selectableText.isNotEmpty, isTrue);
      expect(screen.evictedSelectionChars, greaterThan(0));

      // Hold a selection, then switch to the alt screen so the reported
      // eviction snaps back to zero.
      grid.dispatchSelectionEvent(const SelectAllSelectionEvent());
      VtParser(sink: screen).advance(utf8.encode('\x1B[?1049h'));
      screen.snapshot();
      expect(screen.evictedSelectionChars, 0);

      // The next cache read re-anchors, sees the backwards delta, and clears.
      grid.selectableText;
      expect(grid.selectionStart, isNull);
      expect(grid.selectionEnd, isNull);
    });
  });

  group('RenderTerminalGrid selection auto-scroll', () {
    // A [rows]-tall viewport over ["aa","bb","cc","dd"] with scrollback.
    // At rows:2 the live viewport is ["cc","dd"]; lines are trimmed, so
    // the joined-text offsets are aa=0, bb=3, cc=6, dd=9 (2 chars + newline).
    RenderTerminalGrid gridWithScrollback({int rows = 2}) {
      final screen = ts.Screen(rows: rows, cols: 4, scrollbackBytes: 5 * 4096);
      VtParser(sink: screen).advance(utf8.encode('aa\r\nbb\r\ncc\r\ndd'));
      screen.snapshot();
      return RenderTerminalGrid(screen: screen)
        ..layout(BoxConstraints.tight(Size(4, rows.toDouble())));
    }

    // Auto-scroll is rate-limited by nocterm's SelectionAutoScroller against a
    // monotonic clock: a drag past the edge scrolls by (velocity × elapsed
    // time), not one row per event. Drive that clock deterministically via the
    // sanctioned test hook so the pump is reproducible.
    late Duration now;
    setUp(() {
      now = Duration.zero;
      SelectionAutoScroller.debugClockOverride = () => now;
    });
    tearDown(() => SelectionAutoScroller.debugClockOverride = null);

    void advance() => now += const Duration(milliseconds: 100);

    test('dragging past the top edge auto-scrolls into scrollback until it '
        'runs out', () {
      final grid = gridWithScrollback();
      final screen = grid.screen;

      // Anchor at the bottom viewport row ("dd").
      grid.dispatchSelectionEvent(
        const SelectionEdgeUpdateEvent.forStart(globalPosition: Offset(0, 1)),
      );
      expect(grid.selectionStart, 9);
      expect(screen.viewOffset, 0);

      const aboveTop = SelectionEdgeUpdateEvent.forEnd(
        globalPosition: Offset(0, -1),
      );

      // First frame past the edge only establishes the clock baseline: the end
      // resolves to the top visible row ("cc") and it asks for another frame
      // (pending) without scrolling yet.
      expect(grid.dispatchSelectionEvent(aboveTop), SelectionResult.pending);
      expect(screen.viewOffset, 0);
      expect(grid.selectionEnd, 6);

      // Pump frames with time advancing; the view scrolls up into scrollback
      // and stays pending while more rows remain to reveal.
      var settled = false;
      for (var i = 0; i < 20 && !settled; i++) {
        advance();
        settled =
            grid.dispatchSelectionEvent(aboveTop) != SelectionResult.pending;
      }

      // Scrollback exhausted: the whole buffer is selected ("aa" at offset 0)
      // and the view is pinned at its maximum offset, so the pump stops.
      expect(
        settled,
        isTrue,
        reason: 'auto-scroll should settle once scrollback runs out',
      );
      expect(screen.viewOffset, 2);
      expect(grid.selectionEnd, 0);
    });

    test('an end drag in the neutral middle band never auto-scrolls', () {
      // Auto-scroll is edge-triggered: a 2-row viewport is all edge, so use a
      // 3-row one, which has a genuine neutral middle row (row 1).
      final grid = gridWithScrollback(rows: 3);
      final screen = grid.screen;

      grid.dispatchSelectionEvent(
        const SelectionEdgeUpdateEvent.forStart(globalPosition: Offset.zero),
      );
      const middle = SelectionEdgeUpdateEvent.forEnd(
        globalPosition: Offset(1, 1),
      );

      // Even pumped across time, an end edge parked in the neutral band stays
      // out of the auto-scroll zone: never pending, never scrolls.
      for (var i = 0; i < 5; i++) {
        expect(
          grid.dispatchSelectionEvent(middle),
          isNot(SelectionResult.pending),
        );
        advance();
      }
      expect(screen.viewOffset, 0);
    });

    test('only the dragged end edge auto-scrolls, never the start edge', () {
      final grid = gridWithScrollback();
      final screen = grid.screen;

      // The root only re-fires the end edge; a start edge past the top must
      // never scroll, even as time advances.
      const startAboveTop = SelectionEdgeUpdateEvent.forStart(
        globalPosition: Offset(0, -1),
      );
      for (var i = 0; i < 5; i++) {
        expect(
          grid.dispatchSelectionEvent(startAboveTop),
          isNot(SelectionResult.pending),
        );
        advance();
      }
      expect(screen.viewOffset, 0);
    });
  });

  group('RenderTerminalGrid paint', () {
    const selectionBg = Color.fromRGB(50, 100, 200);

    // Paints the grid into a fresh cell buffer and hands it back to read.
    //
    // [rows] and [cols] size the grid's box. [viewport] is the canvas area it
    // is allowed to draw into, defaulting to exactly that box, and [at] is
    // where in the canvas the box starts — a scroll view hands its child a
    // negative offset once the child has passed the top edge.
    //
    // The buffer behind the canvas is deliberately larger than the viewport,
    // so a write that escapes the viewport lands somewhere a test can read it
    // rather than falling off the buffer and looking contained.
    Buffer paintGrid(
      RenderTerminalGrid grid, {
      int rows = 2,
      int cols = 6,
      Rect? viewport,
      Offset at = Offset.zero,
    }) {
      final area =
          viewport ?? Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble());
      final buffer = Buffer(
        math.max(cols, (area.left + area.width).ceil()) + 4,
        math.max(rows, (area.top + area.height).ceil()) + 4,
      );
      grid
        ..layout(BoxConstraints.tight(Size(cols.toDouble(), rows.toDouble())))
        ..paint(TerminalCanvas(buffer, area), at);
      return buffer;
    }

    test('highlights selected content but not trailing padding', () {
      final screen = _screenWith('hello', rows: 2);
      // Select everything: only "hello" (cols 0..4) is content.
      final grid = RenderTerminalGrid(screen: screen, showCursor: false)
        ..dispatchSelectionEvent(const SelectAllSelectionEvent());
      final buffer = paintGrid(grid);

      for (var c = 0; c < 5; c++) {
        expect(
          buffer.getCell(c, 0).style.backgroundColor,
          selectionBg,
          reason: 'col $c ("${'hello'[c]}") should be highlighted',
        );
      }
      // Col 5 is trailing padding — not part of the line, so not selected.
      expect(buffer.getCell(5, 0).style.backgroundColor, isNot(selectionBg));
      // The blank second row is dropped from the selection entirely.
      expect(buffer.getCell(0, 1).style.backgroundColor, isNot(selectionBg));
    });

    test('paints every glyph when nothing is selected', () {
      final screen = _screenWith('hi', rows: 1, cols: 4);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);
      expect(grid.showCursor, isFalse);

      final buffer = paintGrid(grid, rows: 1, cols: 4);

      expect(buffer.getCell(0, 0).char, 'h');
      expect(buffer.getCell(1, 0).char, 'i');
      expect(buffer.getCell(0, 0).style.backgroundColor, isNot(selectionBg));
    });

    // A screen is sized by whoever owns the session and reaches its box a
    // frame later at best — a replayed transcript opens at the width it was
    // recorded at, and a pane narrower than the shell's minimum never gets
    // there. Painting past the box puts those cells over its neighbours.
    test('draws nothing past a box narrower than the screen', () {
      final screen = _screenWith('abcdefgh', rows: 1, cols: 8);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(grid, rows: 1, cols: 4);

      expect(buffer.getCell(3, 0).char, 'd');
      expect(
        buffer.getCell(4, 0).char,
        isNot('e'),
        reason: 'col 4 is outside the box',
      );
    });

    test('draws nothing past a box shorter than the screen', () {
      final screen = _screenWith('one\r\ntwo\r\nsix', cols: 4);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(grid, cols: 4);

      expect(buffer.getCell(0, 1).char, 't');
      expect(
        buffer.getCell(0, 2).char,
        isNot('s'),
        reason: 'row 2 is outside the box',
      );
    });

    // A details pane scrolls one long column, so a grid that has passed the
    // top edge is asked to paint at a negative offset. A clipped canvas moves
    // where `setRaw` writes without bounding it — unlike every other draw
    // call — so the grid has to know the viewport's edges or it paints over
    // whatever is showing there instead.
    test('draws nothing once it has scrolled off the top', () {
      final screen = _screenWith('one\r\ntwo', rows: 2);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(
        grid,
        viewport: const Rect.fromLTWH(0, 2, 6, 2),
        at: const Offset(0, -2),
      );

      expect(buffer.getCell(0, 0).char, isNot('o'));
      expect(buffer.getCell(0, 1).char, isNot('t'));
    });

    test('draws only the rows still inside the viewport', () {
      final screen = _screenWith('one\r\ntwo', rows: 2);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(
        grid,
        viewport: const Rect.fromLTWH(0, 2, 6, 2),
        at: const Offset(0, -1),
      );

      expect(buffer.getCell(0, 2).char, 't', reason: 'row 1 slid to the top');
      expect(
        buffer.getCell(0, 1).char,
        isNot('o'),
        reason: 'row 0 is above the viewport',
      );
    });

    test('draws nothing once it has scrolled off the bottom', () {
      final screen = _screenWith('one\r\ntwo', rows: 2);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(
        grid,
        viewport: const Rect.fromLTWH(0, 0, 6, 1),
        at: const Offset(0, 1),
      );

      expect(buffer.getCell(0, 1).char, isNot('o'));
    });

    test('draws nothing past the right edge of the viewport', () {
      final screen = _screenWith('abcdef', rows: 1);
      final grid = RenderTerminalGrid(screen: screen, showCursor: false);

      final buffer = paintGrid(
        grid,
        rows: 1,
        viewport: const Rect.fromLTWH(0, 0, 3, 1),
        at: const Offset(1, 0),
      );

      expect(buffer.getCell(2, 0).char, 'b');
      expect(buffer.getCell(3, 0).char, isNot('c'));
    });

    test('draws the cursor cell inverted', () {
      // After "x" the cursor sits on the blank col 1.
      final screen = _screenWith('x', rows: 1, cols: 4);
      final buffer = paintGrid(
        RenderTerminalGrid(screen: screen),
        rows: 1,
        cols: 4,
      );

      expect(buffer.getCell(1, 0).style.color, Colors.black);
      expect(buffer.getCell(1, 0).style.backgroundColor, Colors.white);
    });

    test('blanks the continuation half of a wide glyph', () {
      final screen = _screenWith('世', rows: 1, cols: 4);
      final buffer = paintGrid(
        RenderTerminalGrid(screen: screen, showCursor: false),
        rows: 1,
        cols: 4,
      );

      expect(buffer.getCell(0, 0).char, '世');
      // The right half renders a zero-width space, not a second glyph.
      expect(buffer.getCell(1, 0).char, '​');
    });

    test('paints SGR text attributes onto the cells', () {
      final screen = _screenWith(
        '\x1B[1mA\x1B[0m' // bold
        '\x1B[4mB\x1B[0m' // underline
        '\x1B[7mC\x1B[0m' // inverse
        '\x1B[2mD\x1B[0m' // faint
        '\x1B[9mE\x1B[0m' // strikethrough
        '\x1B[3mF', // italic
        rows: 1,
      );
      final buffer = paintGrid(
        RenderTerminalGrid(screen: screen, showCursor: false),
        rows: 1,
      );

      expect(buffer.getCell(0, 0).style.fontWeight, FontWeight.bold);
      expect(buffer.getCell(1, 0).style.decoration?.hasUnderline, isTrue);
      // Inverse swaps: the default white foreground becomes the background.
      expect(buffer.getCell(2, 0).style.backgroundColor, Colors.white);
      // Faint dims the default white foreground.
      expect(
        buffer.getCell(3, 0).style.color,
        const Color.fromRGB(124, 124, 121),
      );
      expect(buffer.getCell(4, 0).style.decoration?.hasLineThrough, isTrue);
      expect(buffer.getCell(5, 0).style.fontStyle, FontStyle.italic);
    });

    test('combines underline and strikethrough on one cell', () {
      final screen = _screenWith('\x1B[4;9mX', rows: 1, cols: 2);
      final buffer = paintGrid(
        RenderTerminalGrid(screen: screen, showCursor: false),
        rows: 1,
        cols: 2,
      );
      final decoration = buffer.getCell(0, 0).style.decoration!;

      expect(decoration.hasUnderline, isTrue);
      expect(decoration.hasLineThrough, isTrue);
    });

    test('resolves every colour kind', () {
      final screen = _screenWith(
        '\x1B[38;5;1mA\x1B[0m' // indexed < 16
        '\x1B[38;5;21mB\x1B[0m' // indexed colour cube
        '\x1B[38;5;240mC\x1B[0m' // indexed grayscale ramp
        '\x1B[38;2;10;20;30mD', // 24-bit rgb
        rows: 1,
        cols: 4,
      );
      final buffer = paintGrid(
        RenderTerminalGrid(screen: screen, showCursor: false),
        rows: 1,
        cols: 4,
      );

      expect(buffer.getCell(0, 0).style.color, const Color.fromRGB(205, 0, 0));
      expect(buffer.getCell(1, 0).style.color, const Color.fromRGB(0, 0, 255));
      expect(buffer.getCell(2, 0).style.color, const Color.fromRGB(88, 88, 88));
      expect(buffer.getCell(3, 0).style.color, const Color.fromRGB(10, 20, 30));
    });
  });

  group('TerminalGrid component', () {
    test('mounts, then rebuilds in place through updateRenderObject', () async {
      await testNocterm('terminal grid lifecycle', (tester) async {
        await tester.pumpComponent(const _GridHarness());
        expect(tester.terminalState, containsText('one')); // createRenderObject

        // A setState rebuild feeds a new config to the same element:
        // updateRenderObject drives the screen and showCursor setters.
        _GridHarnessState.current!.show('two', showCursor: false);
        await tester.pump();
        expect(tester.terminalState, containsText('two'));

        // Rebuild again with showCursor unchanged: the setter's no-op path.
        _GridHarnessState.current!.show('six', showCursor: false);
        await tester.pump();
        expect(tester.terminalState, containsText('six'));
      });
    });
  });
}

/// Drives [TerminalGrid] through a setState rebuild so the framework
/// reconciles it in place (updateRenderObject) instead of remounting.
class _GridHarness extends StatefulComponent {
  const _GridHarness();

  @override
  State<_GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<_GridHarness> {
  static _GridHarnessState? current;

  ts.Screen _screen = _screenWith('one', rows: 1);
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();
    current = this;
  }

  void show(String label, {required bool showCursor}) => setState(() {
    _screen = _screenWith(label, rows: 1);
    _showCursor = showCursor;
  });

  @override
  Component build(BuildContext context) => SizedBox(
    width: 6,
    height: 1,
    child: TerminalGrid(screen: _screen, showCursor: _showCursor),
  );
}
