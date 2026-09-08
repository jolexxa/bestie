import 'dart:convert';

import 'package:bestie_chat_view/src/workspace/interactive_terminal_view.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_cubit.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

class _MockSurface extends Mock implements TerminalSurface {}

/// A cubit over a stubbed session, reporting what the view decides to send.
///
/// The viewport is delegated to the real [ts.Screen] so a scroll assertion
/// reads the same value the surface renders from.
class _Harness {
  _Harness(this.screen, {this.onWrite}) {
    when(
      () => session.changes,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => session.exited).thenReturn(false);
    when(() => session.screen).thenReturn(screen);
    when(() => session.viewOffset).thenAnswer((_) => screen.viewOffset);
    when(() => session.setViewOffset(any())).thenAnswer(
      (i) => screen.setViewOffset(i.positionalArguments.first as int),
    );
    when(() => session.write(any())).thenAnswer((i) {
      onWrite?.call(i.positionalArguments.first as List<int>);
    });
    when(
      () => session.resize(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(null);
    cubit = ShellPaneCubit(logic: ShellPaneLogic(surface: session));
  }

  final ts.Screen screen;
  final session = _MockSurface();

  /// Bytes the view routed to the child, as they are routed.
  final void Function(List<int> bytes)? onWrite;

  late final ShellPaneCubit cubit;
}

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

ts.Screen _screenWith(
  String input, {
  int rows = 4,
  int cols = 8,
  int scrollbackBytes = 0,
}) {
  final s = ts.Screen(rows: rows, cols: cols, scrollbackBytes: scrollbackBytes);
  VtParser(sink: s).advance(utf8.encode(input));
  s.snapshot();
  return s;
}

Component _pane(
  ts.Screen screen, {
  bool focused = true,
  void Function(List<int> bytes)? onBytes,
  double width = 12,
  double height = 6,
}) => SizedBox(
  width: width,
  height: height,
  child: InteractiveTerminalView(
    screen: screen,
    focused: focused,
    cubit: _Harness(screen, onWrite: onBytes).cubit,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  group('InteractiveTerminalView', () {
    test('renders the screen', () async {
      await testNocterm('render', (tester) async {
        final screen = _screenWith('hi');
        await tester.pumpComponent(_themed(_pane(screen)));
        expect(tester.terminalState, containsText('hi'));
      }, size: const Size(12, 6));
    });

    test('ignores keystrokes while unfocused, including Esc', () async {
      await testNocterm('unfocused', (tester) async {
        final screen = _screenWith('hi');
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, focused: false, onBytes: sent.addAll)),
        );
        await tester.sendRawBytes(const [0x61]); // 'a'
        await tester.sendRawBytes(const [0x1B]); // Esc
        expect(sent.isEmpty, isTrue);
      }, size: const Size(12, 6));
    });

    test('forwards a printable key and resets any scrollback view', () async {
      await testNocterm('forward', (tester) async {
        final screen = _screenWith('hi');
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll)),
        );
        await tester.sendRawBytes(const [0x61]); // 'a'
        expect(sent, [0x61]);
        expect(screen.viewOffset, 0);
      }, size: const Size(12, 6));
    });

    test('forwards a bare Esc to the child', () async {
      await testNocterm('esc', (tester) async {
        final screen = _screenWith('hi');
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll)),
        );

        await tester.sendRawBytes(const [0x1B]);

        expect(sent, [0x1B]);
      }, size: const Size(12, 6));
    });

    test('scrollback keys navigate history without forwarding', () async {
      await testNocterm('scrollback', (tester) async {
        final screen = _screenWith(
          List.generate(20, (i) => 'row$i').join('\r\n'),
          scrollbackBytes: 40 * 4096,
        );
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll, width: 14, height: 8)),
        );

        // Shift+PgUp: ESC [ 5 ; 2 ~
        await tester.sendRawBytes(const [0x1B, 0x5B, 0x35, 0x3B, 0x32, 0x7E]);
        expect(screen.viewOffset, greaterThan(0));
        final afterUp = screen.viewOffset;

        // Shift+PgDn: ESC [ 6 ; 2 ~
        await tester.sendRawBytes(const [0x1B, 0x5B, 0x36, 0x3B, 0x32, 0x7E]);
        expect(screen.viewOffset, lessThan(afterUp));
        expect(sent.isEmpty, isTrue);
      }, size: const Size(14, 8));
    });

    test('a pure mouse sequence is dropped when mouse mode is off', () async {
      await testNocterm('mouse-off', (tester) async {
        final screen = _screenWith('hi');
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll)),
        );
        // SGR left-button press at col 5, row 5.
        await tester.sendRawBytes(utf8.encode('\x1B[<0;5;5M'));
        expect(sent.isEmpty, isTrue);
      }, size: const Size(12, 6));
    });

    test('hover wheel scrolls history — no focus required', () async {
      await testNocterm('wheel', (tester) async {
        final screen = _screenWith(
          List.generate(20, (i) => 'row$i').join('\r\n'),
          scrollbackBytes: 40 * 4096,
        );
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(
            _pane(
              screen,
              focused: false,
              onBytes: sent.addAll,
              width: 14,
              height: 8,
            ),
          ),
        );

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelUp,
            x: 5,
            y: 5,
            pressed: true,
          ),
        );
        expect(screen.viewOffset, 3);
        expect(sent.isEmpty, isTrue);

        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.wheelDown,
            x: 5,
            y: 5,
            pressed: true,
          ),
        );
        expect(screen.viewOffset, 0);
      }, size: const Size(14, 8));
    });

    test(
      'a mouse click is offset into the grid when mouse mode is on',
      () async {
        await testNocterm('mouse-on', (tester) async {
          final screen = _screenWith('hi')
            ..modes.mouseMode = ts.MouseMode.vt200;
          final sent = <int>[];
          await tester.pumpComponent(
            _themed(_pane(screen, onBytes: sent.addAll)),
          );
          // Non-wheel button press on the child's screen; the child has
          // mouse tracking on, so the sequence should reach it rather than
          // being stripped.
          await tester.sendRawBytes(utf8.encode('\x1B[<0;5;3M'));
          expect(sent.isNotEmpty, isTrue);
        }, size: const Size(12, 6));
      },
    );

    test('a drag leaving the grid still delivers its release', () async {
      await testNocterm('drag-out', (tester) async {
        final screen = _screenWith('hi')..modes.mouseMode = ts.MouseMode.vt200;
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll)),
        );

        await tester.sendRawBytes(utf8.encode('\x1B[<0;5;3M')); // press inside
        sent.clear();
        // Drag past the screen's right edge, release out there: the child
        // must still see the button come up, clamped onto its grid.
        await tester.sendRawBytes(utf8.encode('\x1B[<32;20;3M'));
        await tester.sendRawBytes(utf8.encode('\x1B[<0;20;3m'));

        expect(
          utf8.decode(sent),
          '\x1B[<32;8;3M\x1B[<0;8;3m',
        );
      }, size: const Size(12, 6));
    });

    test('a gesture that began outside never reaches the child', () async {
      await testNocterm('foreign-drag', (tester) async {
        final screen = _screenWith('hi')..modes.mouseMode = ts.MouseMode.vt200;
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, onBytes: sent.addAll)),
        );

        await tester.sendRawBytes(utf8.encode('\x1B[<0;20;3M')); // press out
        await tester.sendRawBytes(utf8.encode('\x1B[<32;5;3M')); // drag across
        await tester.sendRawBytes(utf8.encode('\x1B[<0;5;3m')); // release in

        expect(sent.isEmpty, isTrue);
      }, size: const Size(12, 6));
    });

    test('unfocused: wheel still reaches a mouse-tracking child', () async {
      await testNocterm('unfocused-wheel', (tester) async {
        final screen = _screenWith('hi')..modes.mouseMode = ts.MouseMode.vt200;
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(_pane(screen, focused: false, onBytes: sent.addAll)),
        );

        await tester.sendRawBytes(utf8.encode('\x1B[<64;5;3M')); // wheel in
        expect(utf8.decode(sent), '\x1B[<64;5;3M');

        sent.clear();
        await tester.sendRawBytes(utf8.encode('\x1B[<0;5;3M')); // click in
        expect(sent.isEmpty, isTrue);
      }, size: const Size(12, 6));
    });

    test('declines a mouse click outside the grid even when focused', () async {
      await testNocterm('mouse-outside', (tester) async {
        final screen = _screenWith('hi')..modes.mouseMode = ts.MouseMode.vt200;
        final sent = <int>[];
        await tester.pumpComponent(
          _themed(
            Row(
              children: [
                _pane(screen, onBytes: sent.addAll),
                const SizedBox(width: 20, height: 6),
              ],
            ),
          ),
        );
        // SGR left-button press at col 20 — past the 12-cell pane. Even a
        // mouse-hungry child must not see it; the click belongs to whoever
        // owns that region.
        await tester.sendRawBytes(utf8.encode('\x1B[<0;20;5M'));
        expect(sent.isEmpty, isTrue);
      }, size: const Size(32, 6));
    });

    test('disposes cleanly when unmounted', () async {
      await testNocterm('dispose', (tester) async {
        final screen = _screenWith('hi');
        await tester.pumpComponent(_themed(_pane(screen)));
        await tester.pumpComponent(
          _themed(const SizedBox(width: 12, height: 6)),
        );
      }, size: const Size(12, 6));
    });
  });
}
