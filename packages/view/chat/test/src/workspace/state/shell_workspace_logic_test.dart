import 'dart:async';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_cubit.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_data.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_output.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_state.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

class _MockShellUseCase extends Mock implements ShellUseCase {}

class _MockTerminalHost extends Mock implements TerminalHost {}

const _request = ShellSessionRequest(
  executable: '/opt/bestie/bin/brush',
  environment: {'SHELL': '/opt/bestie/bin/brush'},
  rows: 24,
  cols: 80,
  scrollbackBytes: 4096,
);

/// A host whose spawn never settles.
TerminalHost _inertHost() {
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
  ).thenAnswer((_) => Completer<TerminalSpawnResult>().future);
  return host;
}

ShellSessionSummary _summary(String id, {String title = 'zsh'}) =>
    ShellSessionSummary(
      id: id,
      title: title,
      status: ShellSessionStatus.running,
      kind: ShellSessionKind.interactive,
    );

void main() {
  late _MockShellUseCase shell;
  late StreamController<List<ShellSessionSummary>> roster;
  late ShellWorkspaceLogic logic;

  ShellSession session(String id) =>
      InteractiveShell(id: id, host: _inertHost(), request: _request);

  setUp(() {
    shell = _MockShellUseCase();
    roster = StreamController<List<ShellSessionSummary>>.broadcast();
    when(() => shell.userShells).thenReturn(const []);
    when(() => shell.userShellsStream).thenAnswer((_) => roster.stream);
    when(() => shell.close(any())).thenAnswer((_) async {});
    logic = ShellWorkspaceLogic(shell: shell);
  });

  tearDown(() async {
    logic.stop();
    await roster.close();
  });

  ShellWorkspaceState open(String id) {
    final live = session(id);
    when(
      () => shell.openUserShell(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(live);
    when(() => shell.userShells).thenReturn([_summary(id)]);
    return logic.input(const OpenShell(rows: 24, cols: 80));
  }

  group('initial state', () {
    test('starts on the details tab with the roster seeded', () {
      when(() => shell.userShells).thenReturn([_summary('s1')]);
      final state = logic.start();
      expect(state, isA<DetailsActiveState>());
      expect(state.activeId, detailsTabId);
      expect(state.terminalFocused, isFalse);
      expect(state.shells.single.id, 's1');
    });

    test('activeShell and activeSession are null on the details tab', () {
      final state = logic.start();
      expect(state.activeShell, isNull);
      expect(state.activeSession, isNull);
    });
  });

  group('OpenShell', () {
    test('opens through the use case at the requested size and focuses', () {
      logic.start();
      final state = open('s1');
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's1');
      expect(state.terminalFocused, isTrue);
      verify(() => shell.openUserShell(rows: 24, cols: 80)).called(1);
    });

    test('activeSession resolves the new session through the use case', () {
      logic.start();
      final live = session('s1');
      when(
        () => shell.openUserShell(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
        ),
      ).thenReturn(live);
      when(() => shell.userShells).thenReturn([_summary('s1')]);
      when(() => shell.sessionFor('s1')).thenReturn(live);
      final state = logic.input(const OpenShell(rows: 24, cols: 80));
      expect(state.activeShell?.id, 's1');
      expect(state.activeSession, same(live));
    });
  });

  group('SelectTab', () {
    test('back to details keeps the shell running', () {
      logic.start();
      open('s1');
      final state = logic.input(const SelectTab(detailsTabId));
      expect(state, isA<DetailsActiveState>());
      expect(state.activeId, detailsTabId);
      verifyNever(() => shell.close(any()));
    });

    test('onto a shell tab always lands focused', () {
      logic.start();
      open('s1');
      logic
        ..input(const ClickedAt(overActivePane: false))
        ..input(const SelectTab(detailsTabId));
      final state = logic.input(const SelectTab('s1'));
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's1');
    });

    test('the already-shown tab is a no-op', () {
      logic.start();
      open('s1');
      logic.input(const ClickedAt(overActivePane: false));
      final state = logic.input(const SelectTab('s1'));
      expect(state, isA<ShellUnfocusedState>());
    });

    test('an unknown id is a no-op', () {
      logic.start();
      final state = logic.input(const SelectTab('nope'));
      expect(state, isA<DetailsActiveState>());
    });
  });

  group('CloseTab', () {
    ShellWorkspaceState openThree() {
      logic.start();
      open('s1');
      open('s2');
      open('s3');
      when(() => shell.userShells).thenReturn(
        [_summary('s1'), _summary('s2'), _summary('s3')],
      );
      return logic.input(
        RosterUpdated(
          [_summary('s1'), _summary('s2'), _summary('s3')],
        ),
      );
    }

    test('tears the shell down through the use case', () {
      logic.start();
      open('s1');
      logic.input(const CloseTab('s1'));
      verify(() => shell.close('s1')).called(1);
    });

    test('closing the shown tab selects the next one', () {
      openThree();
      logic.input(const SelectTab('s2'));
      final state = logic.input(const CloseTab('s2'));
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's3');
    });

    test('closing the shown last tab selects the previous one', () {
      openThree();
      final state = logic.input(const CloseTab('s3'));
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's2');
    });

    test('closing a background tab keeps the selection', () {
      openThree();
      logic.input(const ClickedAt(overActivePane: false));
      final state = logic.input(const CloseTab('s1'));
      expect(state, isA<ShellUnfocusedState>());
      expect(state.activeId, 's3');
      expect(state.shells.map((s) => s.id), ['s2', 's3']);
    });

    test('closing the only tab returns to details', () {
      logic.start();
      open('s1');
      final state = logic.input(const CloseTab('s1'));
      expect(state, isA<DetailsActiveState>());
      expect(state.activeId, detailsTabId);
      expect(state.shells, isEmpty);
    });

    test('an unknown id is a no-op', () {
      logic.start();
      open('s1');
      final state = logic.input(const CloseTab('nope'));
      expect(state, isA<ShellFocusedState>());
      verifyNever(() => shell.close('nope'));
    });
  });

  group('RosterUpdated', () {
    test('a session closed elsewhere folds its tab away', () {
      logic.start();
      open('s1');
      final state = logic.input(const RosterUpdated([]));
      expect(state, isA<DetailsActiveState>());
      expect(state.shells, isEmpty);
    });

    test('a retitle updates the roster and asks for a rebuild', () {
      logic.start();
      open('s1');
      final outputs = <ShellWorkspaceOutput>[];
      final binding = logic.bind()..onOutput<StateUpdated>(outputs.add);
      final state = logic.input(
        RosterUpdated([_summary('s1', title: 'vim')]),
      );
      expect(state, isA<ShellFocusedState>());
      expect(state.shells.single.title, 'vim');
      expect(outputs, hasLength(1));
      binding.dispose();
    });

    test('a shrink that keeps the shown shell keeps the selection', () {
      logic.start();
      open('s1');
      open('s2');
      final state = logic.input(RosterUpdated([_summary('s2')]));
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's2');
    });
  });

  group('ClickedAt', () {
    test('a click away releases the keyboard', () {
      logic.start();
      open('s1');
      final state = logic.input(const ClickedAt(overActivePane: false));
      expect(state, isA<ShellUnfocusedState>());
      expect(state.terminalFocused, isFalse);
    });

    test('a click on the pane takes the keyboard back', () {
      logic.start();
      open('s1');
      logic.input(const ClickedAt(overActivePane: false));
      final state = logic.input(const ClickedAt(overActivePane: true));
      expect(state, isA<ShellFocusedState>());
      expect(state.terminalFocused, isTrue);
    });

    test('a click on the pane while focused changes nothing', () {
      logic.start();
      open('s1');
      final state = logic.input(const ClickedAt(overActivePane: true));
      expect(state, isA<ShellFocusedState>());
    });

    test('a click away while unfocused changes nothing', () {
      logic.start();
      open('s1');
      logic.input(const ClickedAt(overActivePane: false));
      final state = logic.input(const ClickedAt(overActivePane: false));
      expect(state, isA<ShellUnfocusedState>());
    });

    test('the details tab ignores clicks', () {
      final state = logic.start();
      expect(
        logic.input(const ClickedAt(overActivePane: true)),
        same(state),
      );
    });
  });

  group('PinnedTabsSynced', () {
    test('adopts the pinned tabs the selection can show', () {
      logic.start();
      final state = logic.input(
        const PinnedTabsSynced([propertiesTabId, detailsTabId]),
      );
      expect(state.pinnedIds, [propertiesTabId, detailsTabId]);
    });

    test('an unchanged set asks for no rebuild', () {
      logic.start();
      final outputs = <ShellWorkspaceOutput>[];
      final binding = logic.bind()..onOutput<StateUpdated>(outputs.add);
      logic.input(const PinnedTabsSynced([detailsTabId]));
      expect(outputs, isEmpty);
      binding.dispose();
    });

    test('falls back to Details when the sticky tab is dropped', () {
      logic
        ..start()
        ..input(const PinnedTabsSynced([propertiesTabId, detailsTabId]))
        ..input(const SelectTab(propertiesTabId));
      expect(logic.value.activeId, propertiesTabId);

      final state = logic.input(const PinnedTabsSynced([detailsTabId]));
      expect(state.activeId, detailsTabId);
    });

    test('opens on {} when the selection has no output', () {
      logic.start();
      final state = logic.input(const PinnedTabsSynced([propertiesTabId]));
      expect(state.pinnedIds, [propertiesTabId]);
      expect(state.activeId, propertiesTabId);
    });

    test('leaves a running shell in front', () {
      logic.start();
      open('s1');
      final state = logic.input(
        const PinnedTabsSynced([propertiesTabId, detailsTabId]),
      );
      expect(state, isA<ShellFocusedState>());
      expect(state.activeId, 's1');
      expect(state.pinnedIds, [propertiesTabId, detailsTabId]);
    });
  });

  group('PinnedAreaShown', () {
    test('brings the pinned area forward past a shell', () {
      logic.start();
      open('s1');
      final state = logic.input(const PinnedAreaShown());
      expect(state, isA<DetailsActiveState>());
      expect(state.activeId, detailsTabId);
    });

    test('reveals whichever pinned tab is sticky', () {
      logic
        ..start()
        ..input(const PinnedTabsSynced([propertiesTabId, detailsTabId]))
        ..input(const SelectTab(propertiesTabId));
      open('s1');
      final state = logic.input(const PinnedAreaShown());
      expect(state, isA<DetailsActiveState>());
      expect(state.activeId, propertiesTabId);
    });
  });

  group('roster subscription', () {
    test('published rosters flow in as inputs', () async {
      logic.start();
      roster.add([_summary('s1')]);
      await Future<void>.delayed(Duration.zero);
      expect(logic.value.shells.single.id, 's1');
    });

    test('stopping cancels the subscription', () async {
      logic
        ..start()
        ..stop();
      roster.add([_summary('s1')]);
      await Future<void>.delayed(Duration.zero);
      expect(roster.hasListener, isFalse);
    });
  });
}
