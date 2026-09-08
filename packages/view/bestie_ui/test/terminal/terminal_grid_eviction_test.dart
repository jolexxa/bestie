// Once the scrollback cap is reached, new output evicts history — and a
// selection must ride its text, not its offsets. This is the end-to-end
// contract for the pin-backed selection.

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

  test(
    'selection stays pinned while a full buffer evicts',
    () async {
      await testNocterm('eviction', (tester) async {
        final screen = ts.Screen(rows: 4, cols: 10, scrollbackBytes: 1024);
        feed(screen, List.generate(10, (i) => 'row$i').join('\r\n'));

        await tester.pumpComponent(
          SelectionArea(
            child: TerminalGrid(key: gridKey, screen: screen),
          ),
        );

        await drag(tester, from: (0, 1), to: (4, 1));
        expect(grid().getSelectedContent()?.plainText, 'row7');

        feed(screen, '\r\nrow10\r\nrow11');
        await tester.pump();

        expect(grid().getSelectedContent()?.plainText, 'row7');
      }, size: const Size(10, 4));
    },
  );
}
