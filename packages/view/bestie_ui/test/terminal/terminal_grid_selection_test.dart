// End-to-end selection pinning: real SelectionArea, real delegate, real
// mouse events. A completed selection must stay glued to its text while
// the terminal keeps living.

import 'dart:convert';

import 'package:bestie_ui/src/terminal/terminal_grid.dart';
import 'package:nocterm/nocterm.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

void main() {
  final gridKey = GlobalKey();

  RenderTerminalGrid grid() =>
      (gridKey.currentContext as Element?)!.renderObject! as RenderTerminalGrid;

  ts.Screen screenWith(String input, {int rows = 4, int cols = 10}) {
    final s = ts.Screen(rows: rows, cols: cols, scrollbackBytes: 50 * 4096);
    VtParser(sink: s).advance(utf8.encode(input));
    s.snapshot();
    return s;
  }

  void feed(ts.Screen screen, String input) {
    VtParser(sink: screen).advance(utf8.encode(input));
    screen.snapshot();
  }

  Future<void> drag(
    NoctermTester tester, {
    required (int, int) from,
    required (int, int) to,
  }) async {
    await tester.sendMouseEvent(
      MouseEvent(
        button: MouseButton.left,
        x: from.$1,
        y: from.$2,
        pressed: true,
      ),
    );
    await tester.sendMouseEvent(
      MouseEvent(
        button: MouseButton.left,
        x: to.$1,
        y: to.$2,
        pressed: true,
        isMotion: true,
        buttons: const {MouseButton.left},
      ),
    );
    await tester.sendMouseEvent(
      MouseEvent(button: MouseButton.left, x: to.$1, y: to.$2, pressed: false),
    );
  }

  test('completed selection survives streaming output', () async {
    await testNocterm('output', (tester) async {
      final screen = screenWith('aaa\r\nbbb\r\nccc');
      await tester.pumpComponent(
        SelectionArea(
          child: TerminalGrid(key: gridKey, screen: screen),
        ),
      );

      await drag(tester, from: (0, 1), to: (3, 1));
      expect(grid().getSelectedContent()?.plainText, 'bbb');

      feed(screen, '\r\nddd\r\neee\r\nfff');
      await tester.pump();

      expect(grid().getSelectedContent()?.plainText, 'bbb');
    }, size: const Size(10, 4));
  });

  test('completed selection survives a user scroll', () async {
    await testNocterm('scroll', (tester) async {
      final screen = screenWith(
        List.generate(10, (i) => 'row$i').join('\r\n'),
      );
      await tester.pumpComponent(
        SelectionArea(
          child: TerminalGrid(key: gridKey, screen: screen),
        ),
      );

      await drag(tester, from: (0, 1), to: (4, 1));
      final selected = grid().getSelectedContent()?.plainText;
      expect(selected, isNotNull);

      screen.setViewOffset(3);
      await tester.pump();

      expect(grid().getSelectedContent()?.plainText, selected);
    }, size: const Size(10, 4));
  });

  test('completed selection survives resize reflow', () async {
    await testNocterm('resize', (tester) async {
      final screen = screenWith(
        List.generate(8, (i) => 'row $i: quick brown fox').join('\r\n'),
        cols: 30,
      );
      await tester.pumpComponent(
        SelectionArea(
          child: TerminalGrid(key: gridKey, screen: screen),
        ),
      );

      await drag(tester, from: (0, 1), to: (9, 1));
      final selected = grid().getSelectedContent()?.plainText;
      expect(selected, isNot(anyOf(isNull, '')));

      screen.resize(rows: 4, cols: 18);
      await tester.pump();

      expect(grid().getSelectedContent()?.plainText, selected);
    }, size: const Size(30, 4));
  });

  test('active drag anchor survives streaming output', () async {
    await testNocterm('drag-stream', (tester) async {
      final screen = screenWith('aaa\r\nbbb\r\nccc');
      await tester.pumpComponent(
        SelectionArea(
          child: TerminalGrid(key: gridKey, screen: screen),
        ),
      );

      await tester.sendMouseEvent(
        const MouseEvent(button: MouseButton.left, x: 0, y: 1, pressed: true),
      );

      feed(screen, '\r\nddd\r\neee');
      await tester.pump();

      await tester.sendMouseEvent(
        const MouseEvent(
          button: MouseButton.left,
          x: 3,
          y: 1,
          pressed: true,
          isMotion: true,
          buttons: {MouseButton.left},
        ),
      );
      await tester.sendMouseEvent(
        const MouseEvent(button: MouseButton.left, x: 3, y: 1, pressed: false),
      );

      expect(grid().getSelectedContent()?.plainText, contains('bbb'));
    }, size: const Size(10, 4));
  });
}
