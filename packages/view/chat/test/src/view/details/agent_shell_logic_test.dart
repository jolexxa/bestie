import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bestie_chat_view/src/view/details/state/agent_shell_cubit.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_output.dart';
import 'package:bestie_chat_view/src/view/details/state/agent_shell_state.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';

class _MockShellUseCase extends Mock implements ShellUseCase {}

class _MockSurface extends Mock implements TerminalSurface {}

/// A parsed replay of [text], ready to draw — what the domain hands back once
/// it has read and parsed a record off the main isolate.
AgentShellReplay _replay(String text) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  return AgentShellReplay(
    RecordedShell(
      screen: Screen.fromAnsi(
        bytes,
        rows: 24,
        cols: 80,
        scrollbackBytes: defaultReplayScrollbackBytes,
      ),
    ),
  );
}

void main() {
  late _MockShellUseCase shell;
  late StreamController<AgentShellAttachment> attachments;
  late AgentShellLogic logic;

  setUp(() {
    shell = _MockShellUseCase();
    attachments = StreamController<AgentShellAttachment>.broadcast();
    when(
      () => shell.agentShellFor('tc1'),
    ).thenAnswer((_) => attachments.stream);
    logic = AgentShellLogic(shell: shell, toolCallId: 'tc1');
  });

  tearDown(() async {
    logic.stop();
    await attachments.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('holds nothing until the call has something to show', () {
    expect(logic.start(), isA<NoAgentShell>());
  });

  test('draws the live shell while the call holds one', () async {
    logic.start();
    final session = _MockSurface();

    attachments.add(AgentShellLive(session));
    await settle();

    final state = logic.value;
    expect(state, isA<AgentShellAttached>());
    expect((state as AgentShellAttached).surface, same(session));
    expect(state.isLive, isTrue);
  });

  // The whole point of keeping the pen beside the text: a call that finished
  // still has something to show, and it is a terminal, not a wall of text.
  test('draws the record it left once the shell is gone', () async {
    logic.start();
    attachments.add(AgentShellLive(_MockSurface()));
    await settle();

    attachments.add(const AgentShellLoading());
    await settle();
    attachments.add(_replay('hello'));
    await settle();

    final state = logic.value;
    expect(state, isA<AgentShellAttached>());
    expect((state as AgentShellAttached).isLive, isFalse);
    expect(state.surface.screen?.selectionLines(), ['hello']);
    expect(state.surface.exited, isTrue);
  });

  // The terminal's chrome has to be on screen at its final size while the read
  // is in flight.
  test('shows the terminal chrome while the record is read', () async {
    logic.start();

    attachments.add(const AgentShellLoading());
    await settle();

    expect(logic.value, isA<AgentShellPending>());
  });

  // The parse happens off-isolate in the domain; the logic simply adopts the
  // ready surface, keyed so the pane follows that one object.
  test('adopts the parsed replay surface once it arrives', () async {
    logic.start();
    attachments.add(const AgentShellLoading());
    await settle();
    final replay = _replay('done');
    attachments.add(replay);
    await settle();

    final state = logic.value as AgentShellAttached;
    expect(state.surface, same(replay.surface));
    expect(state.surface.screen?.selectionLines(), ['done']);
  });

  test('holds nothing for a call that left no record', () async {
    logic.start();
    attachments.add(AgentShellLive(_MockSurface()));
    await settle();

    attachments.add(const AgentShellNone());
    await settle();

    expect(logic.value, isA<NoAgentShell>());
  });

  // A live shell is ahead of anything on disk, so it wins.
  test('drops a replay when a live shell arrives', () async {
    logic.start();
    attachments.add(_replay('old'));
    await settle();
    expect(logic.value, isA<AgentShellAttached>());

    final session = _MockSurface();
    attachments.add(AgentShellLive(session));
    await settle();

    expect((logic.value as AgentShellAttached).surface, same(session));
  });

  // Republishing the same session is not a change and must not churn the
  // surface holding a live terminal.
  test('republishing the same shell changes nothing', () async {
    logic.start();
    final session = _MockSurface();
    attachments.add(AgentShellLive(session));
    await settle();

    final binding = logic.bind();
    var changes = 0;
    binding.onOutput<AttachmentChanged>((_) => changes++);

    attachments.add(AgentShellLive(session));
    await settle();

    expect(changes, 0);
    binding.dispose();
  });

  test('stops following once stopped', () async {
    logic.start();
    final binding = logic.bind();
    var changes = 0;
    binding.onOutput<AttachmentChanged>((_) => changes++);

    logic.stop();
    attachments.add(AgentShellLive(_MockSurface()));
    await settle();

    expect(changes, 0);
    binding.dispose();
  });
}
