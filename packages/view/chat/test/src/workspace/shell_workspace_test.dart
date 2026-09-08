import 'dart:async';
import 'dart:convert';

import 'package:agentic_terminal/agentic_terminal.dart'
    hide MouseButton, MouseEvent;
import 'package:bestie_chat_view/src/workspace/shell_workspace.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_cubit.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart' as ts;
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

class _MockShellUseCase extends Mock implements ShellUseCase {}

class _MockTerminalHost extends Mock implements TerminalHost {}

class _MockAgentTerminal extends Mock implements AgentTerminal {}

class _MockOSPlatformRepository extends Mock implements OSPlatformRepository {}

/// The size a shell was opened at.
class _OpenSize {
  _OpenSize(this.rows, this.cols);

  final int rows;
  final int cols;
}

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
  final live = screen ?? _screenWith('hi');
  when(() => terminal.screen).thenReturn(live);
  when(
    () => terminal.screenChanges,
  ).thenAnswer((_) => screenChanges ?? const Stream<void>.empty());
  when(() => terminal.exit).thenAnswer((_) => Completer<ProcessExit>().future);
  when(terminal.close).thenAnswer((_) async {});
  when(() => terminal.writeBytes(any())).thenReturn(null);
  // A real resize reaches the screen, and TerminalView only reports a size
  // that differs from the screen's — a fake that swallowed this would keep
  // re-reporting the same size and hide any genuine resize churn.
  when(
    () => terminal.resize(
      rows: any(named: 'rows'),
      cols: any(named: 'cols'),
    ),
  ).thenAnswer((invocation) {
    live.resize(
      rows: invocation.namedArguments[#rows] as int,
      cols: invocation.namedArguments[#cols] as int,
    );
  });
  return terminal;
}

class _Shell {
  _Shell({_MockAgentTerminal Function()? terminal}) {
    final buildTerminal = terminal ?? _liveTerminal;
    when(
      () => _host.spawn(
        executable: _request.executable,
        arguments: _request.arguments,
        environment: _request.environment,
        launchMode: _request.launchMode,
        rows: _request.rows,
        cols: _request.cols,
        scrollbackBytes: _request.scrollbackBytes,
        forwardHostResize: _request.forwardHostResize,
      ),
    ).thenAnswer((_) async => TerminalSpawnSucceeded(buildTerminal()));

    when(() => useCase.userShells).thenAnswer((_) => _summaries());
    when(() => useCase.userShellsStream).thenAnswer((_) => roster.stream);

    when(() => useCase.sessionFor(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as ShellSessionId;
      for (final session in live) {
        if (session.id == id) return session;
      }
      return null;
    });

    when(
      () => useCase.openUserShell(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenAnswer((invocation) {
      openedAt.add(
        _OpenSize(
          invocation.namedArguments[#rows] as int,
          invocation.namedArguments[#cols] as int,
        ),
      );
      final session = InteractiveShell(
        id: 'shell:${opened.length}',
        host: _host,
        request: _request,
      );
      opened.add(session);
      live.add(session);
      emitRoster();
      return session;
    });

    when(() => useCase.close(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as ShellSessionId;
      closed.add(id);
      live.removeWhere((session) => session.id == id);
      await opened.firstWhere((session) => session.id == id).dispose();
      emitRoster();
    });
  }

  final useCase = _MockShellUseCase();
  final _host = _MockTerminalHost();

  final opened = <ShellSession>[];
  final live = <ShellSession>[];
  final closed = <ShellSessionId>[];
  final openedAt = <_OpenSize>[];

  final roster = StreamController<List<ShellSessionSummary>>.broadcast();

  /// What the repository would publish for the sessions still open.
  List<ShellSessionSummary> _summaries() => [
    for (final session in live)
      ShellSessionSummary(
        id: session.id,
        title: session.title,
        status: ShellSessionStatus.running,
        kind: ShellSessionKind.interactive,
      ),
  ];

  void emitRoster() => roster.add(_summaries());
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

Component _providers(_Shell shell, Component child) =>
    RepositoryProvider<ShellUseCase>.value(
      value: shell.useCase,
      child: RepositoryProvider<OSPlatformRepository>.value(
        value: _MockOSPlatformRepository(),
        child: AppTheme(
          data: appThemeDefault,
          child: TuiTheme(data: appThemeDefault, child: child),
        ),
      ),
    );

/// The view model the chat page owns and hands to the workspace.
ShellWorkspaceCubit _cubitFor(_Shell shell) =>
    ShellWorkspaceCubit(logic: ShellWorkspaceLogic(shell: shell.useCase));

Component _mounted(
  _Shell shell, {
  bool active = true,
  Component detailsTab = const Text('DETAILS'),
  ShellWorkspaceCubit? cubit,
}) => _providers(
  shell,
  ShellWorkspace(
    cubit: cubit ?? _cubitFor(shell),
    active: active,
    pinnedTabs: [
      WorkspacePinnedTab(
        id: detailsTabId,
        label: 'Details',
        child: detailsTab,
      ),
    ],
  ),
);

/// Rebuilds with a fresh [ShellWorkspace] instance and a togglable active
/// flag, standing in for the chat page rebuilding when the router context
/// changes on a mode switch. The cubit outlives those rebuilds, as it does
/// on the page.
class _FreshWorkspace extends StatefulComponent {
  const _FreshWorkspace({required this.cubit, super.key});

  final ShellWorkspaceCubit cubit;

  @override
  State<_FreshWorkspace> createState() => _FreshWorkspaceState();
}

class _FreshWorkspaceState extends State<_FreshWorkspace> {
  bool _active = true;

  void setActive({required bool value}) => setState(() => _active = value);

  @override
  Component build(BuildContext context) => ShellWorkspace(
    cubit: component.cubit,
    active: _active,
    pinnedTabs: const [
      WorkspacePinnedTab(
        id: detailsTabId,
        label: 'Details',
        child: Text('DETAILS'),
      ),
    ],
  );
}

/// Rebuilds on demand while handing its child back by identity, standing in
/// for the chat page rebuilding around a workspace it holds onto.
class _Rebuildable extends StatefulComponent {
  const _Rebuildable({required this.child, super.key});

  final Component child;

  @override
  State<_Rebuildable> createState() => _RebuildableState();
}

class _RebuildableState extends State<_Rebuildable> {
  void rebuild() => setState(() {});

  @override
  Component build(BuildContext context) => component.child;
}

class _BuildProbe extends StatelessComponent {
  const _BuildProbe(this.onBuild);

  final VoidCallback onBuild;

  @override
  Component build(BuildContext context) {
    onBuild();
    return const Text('DETAILS');
  }
}

// Tab strip geometry, from TabStrip's own width math (label + borders, and
// a reserved three-cell close slot on closable tabs), laid out with spacing 1:
//   `Details` is pinned and unclosable  → 11 wide at x 0..10
//   the "+" stub                        → 3 wide at x 12..14
// Once one shell tab (`brush`) exists it takes x 12..22 — its × sitting in
// the reserved slot at x 20 — and pushes the stub to x 24..26.
const _detailsTabX = 2;
const _newStubX = 13;
const _shellCloseX = 20;
const _newStubAfterOneTabX = 25;

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  group('ShellWorkspace', () {
    test('starts on the pinned details tab', () async {
      await testNocterm('initial', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));
        expect(tester.terminalState, containsText('Details'));
        expect(tester.terminalState, containsText('DETAILS'));
      }, size: const Size(40, 12));
    });

    test('the + stub opens a shell tab and shows it', () async {
      await testNocterm('open', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        expect(shell.opened, hasLength(1));
        expect(tester.terminalState, containsText('hi'));
      }, size: const Size(40, 12));
    });

    test('opens the shell at the size the pane was laid out at', () async {
      await testNocterm('open-size', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();

        // 40x12 workspace, less two rows for the tab strip and its rule and
        // two per axis for the frame the pane draws.
        expect(shell.openedAt.single.cols, 38);
        expect(shell.openedAt.single.rows, 8);
      }, size: const Size(40, 12));
    });

    test('switching back to details keeps the shell running', () async {
      await testNocterm('switch', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.tap(_detailsTabX, 0);
        await tester.pump();

        expect(tester.terminalState, containsText('DETAILS'));
        expect(shell.closed.isEmpty, isTrue);
      }, size: const Size(40, 12));
    });

    test('closing a shell tab tears the session down', () async {
      await testNocterm('close', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.tap(_shellCloseX, 0);
        await settle();
        await tester.pump();

        expect(shell.closed, ['shell:0']);
        expect(tester.terminalState, containsText('DETAILS'));
      }, size: const Size(40, 12));
    });

    test('typing reaches the active shell tab', () async {
      await testNocterm('type', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.sendRawBytes(const [0x61]); // 'a'

        final terminal = shell.opened.single.state.terminal!;
        verify(() => terminal.writeBytes(const [0x61])).called(1);
      }, size: const Size(40, 12));
    });

    test('an inactive workspace never captures input', () async {
      await testNocterm('inactive', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell, active: false));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.sendRawBytes(const [0x61]);

        final terminal = shell.opened.single.state.terminal!;
        verifyNever(() => terminal.writeBytes(any()));
      }, size: const Size(40, 12));
    });

    test('a bare Esc forwards to the shell instead of releasing', () async {
      await testNocterm('esc-forwards', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.sendRawBytes(const [0x1B]);

        final terminal = shell.opened.single.state.terminal!;
        verify(() => terminal.writeBytes(const [0x1B])).called(1);
      }, size: const Size(40, 12));
    });

    test(
      'a click away releases input; a click on the pane captures it again',
      () async {
        await testNocterm('click-focus', (tester) async {
          final shell = _Shell();
          await tester.pumpComponent(_mounted(shell));

          await tester.tap(_newStubX, 0);
          await settle();
          await tester.pump();

          // A raw left press while the mouse is over the tab strip — not
          // the pane — hands the keyboard back to bestie.
          await tester.hover(2, 0);
          await tester.sendRawBytes(utf8.encode('\x1B[<0;3;1M'));
          await settle();
          await tester.pump();
          await tester.sendRawBytes(const [0x61]);

          final terminal = shell.opened.single.state.terminal!;
          verifyNever(() => terminal.writeBytes(any()));

          // A raw left press over the pane takes it back.
          await tester.hover(20, 6);
          await tester.sendRawBytes(utf8.encode('\x1B[<0;21;7M'));
          await settle();
          await tester.pump();
          await tester.sendRawBytes(const [0x61]);

          verify(() => terminal.writeBytes(const [0x61])).called(1);
        }, size: const Size(40, 12));
      },
    );

    test(
      'a mode switch away and back keeps the cubit answering raw presses',
      () async {
        await testNocterm('mode-switch-cubit', (tester) async {
          final shell = _Shell();
          final workspace = GlobalKey();
          await tester.pumpComponent(
            _providers(
              shell,
              _FreshWorkspace(key: workspace, cubit: _cubitFor(shell)),
            ),
          );

          await tester.tap(_newStubX, 0);
          await settle();
          await tester.pump();

          _FreshWorkspaceState state() =>
              workspace.currentState! as _FreshWorkspaceState;

          // Mode switch away: the workspace rebuilds as a fresh component
          // instance with active off. The cubit must survive the rebuild —
          // it is still the raw-input hook for every left press app-wide.
          state().setActive(value: false);
          await tester.pump();

          // A raw left press over the tab strip while switched away. With a
          // torn-down cubit this threw a StateError mid-dispatch and killed
          // the chunk before nocterm could parse it.
          await tester.hover(2, 0);
          await tester.sendRawBytes(utf8.encode('\x1B[<0;3;1M'));
          await settle();
          await tester.pump();

          // Mode switch back: a press over the pane refocuses it and typing
          // reaches the shell again.
          state().setActive(value: true);
          await tester.pump();

          await tester.hover(20, 6);
          await tester.sendRawBytes(utf8.encode('\x1B[<0;21;7M'));
          await settle();
          await tester.pump();
          await tester.sendRawBytes(const [0x61]);

          final terminal = shell.opened.single.state.terminal!;
          verify(() => terminal.writeBytes(const [0x61])).called(1);
        }, size: const Size(40, 12));
      },
    );

    test('opens a second tab alongside the first', () async {
      await testNocterm('two-tabs', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();
        await tester.tap(_newStubAfterOneTabX, 0);
        await settle();
        await tester.pump();

        expect(shell.opened, hasLength(2));
        expect(shell.closed.isEmpty, isTrue);
      }, size: const Size(40, 12));
    });

    test('exposes its cubit to descendants through BlocProvider', () async {
      await testNocterm('provider', (tester) async {
        final shell = _Shell();
        final probe = GlobalKey();
        await tester.pumpComponent(
          _mounted(
            shell,
            detailsTab: SizedBox(key: probe, width: 1, height: 1),
          ),
        );

        final cubit = BlocProvider.of<ShellWorkspaceCubit>(
          probe.currentContext!,
          listen: false,
        );

        expect(cubit.state.activeId, detailsTabId);
      }, size: const Size(40, 12));
    });

    test('relabels a tab when its shell retitles itself', () async {
      await testNocterm('retitle', (tester) async {
        final changes = StreamController<void>.broadcast();
        final screen = _screenWith('hi');
        final shell = _Shell(
          terminal: () =>
              _liveTerminal(screen: screen, screenChanges: changes.stream),
        );
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();
        expect(tester.terminalState, containsText('brush'));

        // OSC 0 is how a child renames its window; the repository notices
        // through the session's titleChanges and re-publishes the roster.
        VtParser(sink: screen).advance(utf8.encode('\x1B]0;vim\x07'));
        shell.emitRoster();
        await settle();
        await tester.pump();

        expect(tester.terminalState, containsText('vim'));

        await changes.close();
      }, size: const Size(40, 12));
    });

    // The chat page hands the same workspace instance to every rebuild so a
    // state tick per streamed token stops at that boundary rather than
    // repainting a live terminal. That only holds while an identical child
    // short-circuits the subtree, so pin it here.
    test(
      'an ancestor rebuild does not rebuild the workspace subtree',
      () async {
        await testNocterm('stable-identity', (tester) async {
          final shell = _Shell();
          var probeBuilds = 0;
          final key = GlobalKey<_RebuildableState>();
          final workspace = ShellWorkspace(
            cubit: _cubitFor(shell),
            active: true,
            pinnedTabs: [
              WorkspacePinnedTab(
                id: detailsTabId,
                label: 'Details',
                child: _BuildProbe(() => probeBuilds++),
              ),
            ],
          );

          await tester.pumpComponent(
            _providers(shell, _Rebuildable(key: key, child: workspace)),
          );
          expect(probeBuilds, 1);

          key.currentState!.rebuild();
          await tester.pump();
          key.currentState!.rebuild();
          await tester.pump();

          expect(probeBuilds, 1);
        }, size: const Size(40, 12));
      },
    );

    // The regression this design exists for: collapsing the details pane
    // unmounts the workspace, and that must not take the shells with it.
    test('unmounting leaves sessions running; remounting restores '
        'their tabs', () async {
      await testNocterm('unmount', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        await tester.pumpComponent(
          _providers(shell, const SizedBox(width: 40, height: 12)),
        );
        await settle();

        expect(shell.closed.isEmpty, isTrue);
        expect(shell.opened.single.state.running, isTrue);

        await tester.pumpComponent(_mounted(shell));
        await tester.pump();

        expect(tester.terminalState, containsText('brush'));
        expect(tester.terminalState, containsText('DETAILS'));
      }, size: const Size(40, 12));
    });

    test('a session closed elsewhere folds its tab away', () async {
      await testNocterm('external-close', (tester) async {
        final shell = _Shell();
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();

        shell.live.clear();
        shell.emitRoster();
        await settle();
        await tester.pump();

        expect(tester.terminalState, containsText('DETAILS'));
        expect(tester.terminalState, isNot(containsText('brush')));
      }, size: const Size(40, 12));
    });

    test('closing the active tab selects its neighbor', () async {
      await testNocterm('close-neighbor', (tester) async {
        var spawned = 0;
        final screens = [_screenWith('one'), _screenWith('two')];
        final shell = _Shell(
          terminal: () => _liveTerminal(screen: screens[spawned++]),
        );
        await tester.pumpComponent(_mounted(shell));

        await tester.tap(_newStubX, 0);
        await settle();
        await tester.pump();
        await tester.tap(_newStubAfterOneTabX, 0);
        await settle();
        await tester.pump();

        // Back to the first tab, then close it: the second should show.
        await tester.tap(_newStubX, 0);
        await tester.pump();
        await tester.tap(_shellCloseX, 0);
        await settle();
        await tester.pump();

        expect(shell.closed, ['shell:0']);
        expect(tester.terminalState, containsText('two'));
      }, size: const Size(40, 12));
    });
  });
}
