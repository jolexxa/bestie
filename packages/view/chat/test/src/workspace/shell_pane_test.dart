import 'dart:async';
import 'dart:convert';

import 'package:agentic_terminal/agentic_terminal.dart'
    hide MouseButton, MouseEvent;
import 'package:bestie_chat_view/src/workspace/shell_pane.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

class _MockTerminalHost extends Mock implements TerminalHost {}

class _MockAgentTerminal extends Mock implements AgentTerminal {}

class _MockOSPlatformRepository extends Mock implements OSPlatformRepository {}

const _request = ShellSessionRequest(
  executable: '/opt/bestie/bin/brush',
  environment: {'SHELL': '/opt/bestie/bin/brush'},
  launchMode: ShellLaunchMode.interactive,
  rows: 24,
  cols: 80,
  scrollbackBytes: 10000 * 4096,
  forwardHostResize: false,
);

ts.Screen _screenWith(String input, {int rows = 4, int cols = 8}) {
  final s = ts.Screen(rows: rows, cols: cols, scrollbackBytes: 0);
  VtParser(sink: s).advance(utf8.encode(input));
  s.snapshot();
  return s;
}

_MockAgentTerminal _liveTerminal({
  ts.Screen? screen,
  Stream<void>? screenChanges,
}) {
  final terminal = _MockAgentTerminal();
  when(() => terminal.screen).thenReturn(screen ?? _screenWith('hi'));
  when(
    () => terminal.screenChanges,
  ).thenAnswer((_) => screenChanges ?? const Stream<void>.empty());
  when(() => terminal.exit).thenAnswer((_) => Completer<ProcessExit>().future);
  when(terminal.close).thenAnswer((_) async {});
  when(() => terminal.writeBytes(any())).thenReturn(null);
  when(
    () => terminal.resize(
      rows: any(named: 'rows'),
      cols: any(named: 'cols'),
    ),
  ).thenReturn(null);
  return terminal;
}

_MockTerminalHost _hostAnswering(
  Future<TerminalSpawnResult> Function() answer,
) {
  final host = _MockTerminalHost();
  when(
    () => host.spawn(
      executable: _request.executable,
      arguments: _request.arguments,
      environment: _request.environment,
      launchMode: _request.launchMode,
      rows: _request.rows,
      cols: _request.cols,
      scrollbackBytes: _request.scrollbackBytes,
      forwardHostResize: _request.forwardHostResize,
    ),
  ).thenAnswer((_) => answer());
  return host;
}

ShellSession _notSpawned() => InteractiveShell(
  id: 'shell:0',
  host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
  request: _request,
);

ShellSession _spawnedWith(_MockAgentTerminal terminal) => InteractiveShell(
  id: 'shell:0',
  host: _hostAnswering(() async => TerminalSpawnSucceeded(terminal)),
  request: _request,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

Component _themed(Component child, {OSPlatformRepository? platform}) =>
    RepositoryProvider<OSPlatformRepository>.value(
      value: platform ?? _MockOSPlatformRepository(),
      child: AppTheme(
        data: appThemeDefault,
        child: TuiTheme(data: appThemeDefault, child: child),
      ),
    );

Component _pane(
  ShellSession session, {
  bool focused = true,
  bool interactive = true,
  void Function({required bool hovered})? onHoverChanged,
  Key? key,
}) => SizedBox(
  width: 12,
  height: 6,
  child: ShellPane(
    key: key,
    surface: session,
    focused: focused,
    interactive: interactive,
    onHoverChanged: onHoverChanged,
  ),
);

Future<void> _drag(
  NoctermTester tester, {
  required (int, int) from,
  required (int, int) to,
}) async {
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: from.$1, y: from.$2, pressed: true),
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

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  group('ShellPane', () {
    test('shows a placeholder before the shell has spawned', () async {
      await testNocterm('placeholder', (tester) async {
        final session = _notSpawned();
        await tester.pumpComponent(_themed(_pane(session)));
        expect(tester.terminalState, containsText('Starting'));
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('renders the session screen inside its frame', () async {
      await testNocterm('render', (tester) async {
        final session = _spawnedWith(_liveTerminal());
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));
        expect(tester.terminalState, containsText('hi'));
        // The frame is always drawn, so focus never reflows the child.
        expect(tester.terminalState.getCellAt(0, 0)?.char, '┌');
      }, size: const Size(12, 6));
    });

    test('interactive: forwards decoded bytes to the session', () async {
      await testNocterm('write', (tester) async {
        final terminal = _liveTerminal();
        final session = _spawnedWith(terminal);
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));

        await tester.sendRawBytes(const [0x61]); // 'a'

        verify(() => terminal.writeBytes(const [0x61])).called(1);
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('interactive: forwards a bare Esc to the session', () async {
      await testNocterm('esc', (tester) async {
        final terminal = _liveTerminal();
        final session = _spawnedWith(terminal);
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));

        await tester.sendRawBytes(const [0x1B]);

        verify(() => terminal.writeBytes(const [0x1B])).called(1);
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('unfocused: keystrokes bubble unconsumed', () async {
      await testNocterm('unfocused', (tester) async {
        final terminal = _liveTerminal();
        final session = _spawnedWith(terminal);
        await settle();
        await tester.pumpComponent(_themed(_pane(session, focused: false)));

        await tester.sendRawBytes(const [0x61]);
        await tester.sendRawBytes(const [0x1B]);

        verifyNever(() => terminal.writeBytes(any()));
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('interactive: resizes the session when the pane lays out', () async {
      await testNocterm('resize', (tester) async {
        final terminal = _liveTerminal();
        final session = _spawnedWith(terminal);
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));

        verify(
          () => terminal.resize(
            rows: any(named: 'rows'),
            cols: any(named: 'cols'),
          ),
        ).called(1);
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test(
      'reports hover upward through onHoverChanged',
      () async {
        await testNocterm('hover', (tester) async {
          final session = _spawnedWith(_liveTerminal());
          await settle();
          final reported = <bool>[];
          await tester.pumpComponent(
            _themed(
              Row(
                children: [
                  _pane(
                    session,
                    onHoverChanged: ({required hovered}) =>
                        reported.add(hovered),
                  ),
                  const SizedBox(width: 20, height: 6),
                ],
              ),
            ),
          );

          expect(reported, <bool>[]);

          await tester.hover(5, 3);
          expect(reported, [true]);

          await tester.hover(20, 3);
          expect(reported, [true, false]);

          await session.dispose();
        }, size: const Size(32, 6));
      },
    );

    test('a pane unmounting under the cursor reports hover released', () async {
      await testNocterm('hover-unmount', (tester) async {
        final session = _spawnedWith(_liveTerminal());
        await settle();
        final reported = <bool>[];
        await tester.pumpComponent(
          _themed(
            _pane(
              session,
              onHoverChanged: ({required hovered}) => reported.add(hovered),
            ),
          ),
        );

        await tester.hover(5, 3);
        expect(reported, [true]);

        await tester.pumpComponent(
          _themed(const SizedBox(width: 12, height: 6)),
        );
        expect(reported, [true, false]);

        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('read-only: never wires input to the session', () async {
      await testNocterm('read-only', (tester) async {
        final terminal = _liveTerminal();
        final session = _spawnedWith(terminal);
        await settle();
        await tester.pumpComponent(_themed(_pane(session, interactive: false)));

        await tester.sendRawBytes(const [0x61]);

        verifyNever(() => terminal.writeBytes(any()));
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test(
      'interactive: copies a completed selection to the clipboard',
      () async {
        await testNocterm('copy-interactive', (tester) async {
          final session = _spawnedWith(
            _liveTerminal(screen: _screenWith('abc')),
          );
          await settle();
          final platform = _MockOSPlatformRepository();
          when(() => platform.copyToClipboard(any())).thenAnswer((_) async {});
          await tester.pumpComponent(
            _themed(_pane(session), platform: platform),
          );

          await _drag(tester, from: (1, 1), to: (3, 1));

          verify(() => platform.copyToClipboard(any())).called(1);
          await session.dispose();
        }, size: const Size(12, 6));
      },
    );

    test('read-only: copies a completed selection to the clipboard', () async {
      await testNocterm('copy-readonly', (tester) async {
        final session = _spawnedWith(_liveTerminal(screen: _screenWith('abc')));
        await settle();
        final platform = _MockOSPlatformRepository();
        when(() => platform.copyToClipboard(any())).thenAnswer((_) async {});
        await tester.pumpComponent(
          _themed(_pane(session, interactive: false), platform: platform),
        );

        // A read-only pane draws no focus frame, so its content starts at the
        // pane's own origin rather than one cell inside it.
        await _drag(tester, from: (0, 0), to: (2, 0));

        verify(() => platform.copyToClipboard(any())).called(1);
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('rebuilds when the session repaints', () async {
      await testNocterm('repaint', (tester) async {
        final changes = StreamController<void>.broadcast();
        final screen = _screenWith('hi');
        final session = _spawnedWith(
          _liveTerminal(screen: screen, screenChanges: changes.stream),
        );
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));

        VtParser(sink: screen).advance(utf8.encode('\r\nmore'));
        changes.add(null);
        await tester.pump();

        expect(tester.terminalState, containsText('more'));

        await changes.close();
        await session.dispose();
      }, size: const Size(12, 6));
    });

    test('disposes cleanly when unmounted', () async {
      await testNocterm('dispose', (tester) async {
        final session = _spawnedWith(_liveTerminal());
        await settle();
        await tester.pumpComponent(_themed(_pane(session)));
        await tester.pumpComponent(
          _themed(const SizedBox(width: 12, height: 6)),
        );
        await session.dispose();
      }, size: const Size(12, 6));
    });
  });
}
