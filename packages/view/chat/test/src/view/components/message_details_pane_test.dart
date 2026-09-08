import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/message_details_pane.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart'
    show DetailsTab;
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show
        Contribution,
        CreatedFileContribution,
        DiffContribution,
        DiffHunk,
        DiffLine,
        DiffLineKind,
        FileDiff,
        SourceContribution,
        ToolCallCanceled,
        ToolCallDefault,
        ToolCallFailed,
        ToolCallInBackground,
        ToolCallSucceeded;

class _MockShellUseCase extends Mock implements ShellUseCase {}

class _MockSurface extends Mock implements TerminalSurface {}

class _MockOSPlatformRepository extends Mock implements OSPlatformRepository {}

/// A shell feature holding nothing and remembering nothing: no live shell,
/// and no record left behind either, which is what every tool call here is.
ShellUseCase _noShells() {
  final shell = _MockShellUseCase();
  when(
    () => shell.agentShellFor(any()),
  ).thenAnswer((_) => Stream.value(const AgentShellNone()));
  return shell;
}

Component _themed(Component child, {ShellUseCase? shell}) =>
    RepositoryProvider<ShellUseCase>.value(
      value: shell ?? _noShells(),
      child: AppTheme(
        data: appThemeDefault,
        child: TuiTheme(data: appThemeDefault, child: child),
      ),
    );

/// Presses, moves, and releases the left button, which is what a user
/// selecting a run of text does.
Future<void> _drag(
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

class _Selection extends ChangeNotifier
    implements ValueListenable<TimelineItem?> {
  _Selection(this._value);

  TimelineItem? _value;

  @override
  TimelineItem? get value => _value;

  set value(TimelineItem? item) {
    _value = item;
    notifyListeners();
  }
}

Component _paneOver(_Selection selection, {ShellUseCase? shell}) => _themed(
  ValueListenableBuilder<TimelineItem?>(
    valueListenable: selection,
    builder: (context, item, _) => MessageDetailsPane(selected: item),
  ),
  shell: shell,
);

final _t0 = DateTime.utc(2026);

TranscriptParagraphBlock _lines(int count) => _block(
  text: [for (var i = 1; i <= count; i++) 'line $i'].join('\n\n'),
  startedAfter: Duration.zero,
  endedAfter: const Duration(milliseconds: 800),
  tokens: 20,
);

ReasoningStubTimelineItem _thinking(int lines) => ReasoningStubTimelineItem(
  id: 'r1',
  timestamp: _t0,
  text: [for (var i = 1; i <= lines; i++) 'line $i'].join('\n\n'),
  running: true,
);

ReasoningStubTimelineItem _reasoning() => ReasoningStubTimelineItem(
  id: 'r1',
  timestamp: _t0,
  text: 'thinking hard',
  stat: BlockStat(
    startedAt: _t0,
    endedAt: _t0.add(const Duration(milliseconds: 1200)),
    tokenCount: 51,
  ),
);

ToolActivityTimelineItem _tool({
  bool isError = false,
  List<Contribution> contributions = const [],
  Map<String, Object?> arguments = const {'expression': '2+2'},
}) => ToolActivityTimelineItem(
  id: 't1',
  timestamp: _t0,
  toolCall: ToolCallDefault(
    id: 'tc1',
    name: 'calculator',
    arguments: arguments,
  ),
  labelTemplate: r'Calculated ${expression}',
  result: isError
      ? const ToolCallFailed(
          callId: 'tc1',
          toolName: 'calculator',
          message: 'boom',
          elapsedMs: 35,
        )
      : ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
          elapsedMs: 35,
          contributions: contributions,
        ),
);

TranscriptParagraphBlock _block({
  required String text,
  required Duration startedAfter,
  required Duration endedAfter,
  required int tokens,
}) => TranscriptParagraphBlock(
  id: TranscriptBlockId.v7(),
  text: text,
  stat: BlockStat(
    startedAt: _t0.add(startedAfter),
    endedAt: _t0.add(endedAfter),
    tokenCount: tokens,
  ),
);

MessageTimelineItem _answer({List<TranscriptParagraphBlock>? blocks}) =>
    MessageTimelineItem(
      id: 'a1',
      role: Role.assistant,
      timestamp: _t0,
      responseId: 0,
      blocks:
          blocks ??
          [
            _block(
              text: 'done',
              startedAfter: Duration.zero,
              endedAfter: const Duration(milliseconds: 800),
              tokens: 20,
            ),
          ],
    );

void main() {
  group('MessageDetailsPane', () {
    test('shows a reasoning stub in full with its stat line', () async {
      await testNocterm('reasoning detail', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _reasoning())),
        );

        expect(tester.terminalState, containsText('Reasoning'));
        expect(tester.terminalState, containsText('thinking hard'));
        expect(tester.terminalState, containsText('1.2s  51 tok'));
      });
    });

    test('shows tool output in Details, arguments behind {}', () async {
      await testNocterm('tool detail', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _tool())),
        );

        // Details is the default: the tool's name, cost, and output.
        expect(tester.terminalState, containsText('calculator'));
        expect(tester.terminalState, containsText('Output'));
        expect(tester.terminalState, containsText('4'));
        expect(tester.terminalState, containsText('35ms'));
        expect(tester.terminalState, isNot(containsText('2+2')));

        // The arguments live behind the {} tab, its own pinned pane.
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(selected: _tool(), tab: DetailsTab.properties),
          ),
        );
        expect(tester.terminalState, containsText('expression'));
        expect(tester.terminalState, containsText('2+2'));
      });
    });

    test('labels a failed tool result as an error', () async {
      await testNocterm('tool error detail', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _tool(isError: true))),
        );

        expect(tester.terminalState, containsText('Error'));
        expect(tester.terminalState, containsText('boom'));
      });
    });

    test('wraps the header when the pane is too narrow for it', () async {
      // Provenance, glyph, name, and verdict are one sentence; squeezed, it
      // should break onto the next line rather than run off the pane.
      await testNocterm('narrow header', size: const Size(14, 12), (
        tester,
      ) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _tool(isError: true))),
        );

        expect(tester.terminalState, containsText('calculator'));
        expect(tester.terminalState, containsText('Failed'));
      });
    });

    test('labels an interrupted tool result as interrupted', () async {
      final item = ToolActivityTimelineItem(
        id: 't1',
        timestamp: _t0,
        toolCall: const ToolCallDefault(
          id: 'tc1',
          name: 'calculator',
          arguments: {'expression': '2+2'},
        ),
        labelTemplate: r'Calculated ${expression}',
        result: const ToolCallCanceled(
          callId: 'tc1',
          toolName: 'calculator',
          message: 'stopped',
        ),
      );

      await testNocterm('tool interrupted detail', (tester) async {
        await tester.pumpComponent(_themed(MessageDetailsPane(selected: item)));

        expect(tester.terminalState, containsText('Interrupted'));
      });
    });

    test('labels a call handed back to the background as output', () async {
      // What the call returned is the handoff text, and returning it is a
      // success — the job it left running gets its own row.
      final item = ToolActivityTimelineItem(
        id: 't1',
        timestamp: _t0,
        toolCall: const ToolCallDefault(
          id: 'tc1',
          name: 'bash',
          arguments: {'command': 'sleep 30'},
        ),
        labelTemplate: r'Running ${command}',
        result: const ToolCallInBackground(
          callId: 'tc1',
          toolName: 'bash',
          content: 'Still running, in session shell:0.',
        ),
      );

      await testNocterm('tool background detail', (tester) async {
        await tester.pumpComponent(_themed(MessageDetailsPane(selected: item)));

        expect(tester.terminalState, containsText('Output'));
        expect(tester.terminalState, containsText('shell:0'));
      });
    });

    test('shows a running job as still running', () async {
      await testNocterm('background job detail', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: BackgroundJobTimelineItem(
                id: 'j1',
                timestamp: _t0,
                job: const JobInBackground(
                  callId: 'tc1',
                  toolName: 'bash',
                ),
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('Running in the background'));
        expect(tester.terminalState, containsText('bash'));
        expect(tester.terminalState, containsText('Still running.'));
      });
    });

    test('shows a settled job as what its report said', () async {
      await testNocterm('background job settled detail', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: BackgroundJobTimelineItem(
                id: 'j1',
                timestamp: _t0,
                job: const JobInBackground(
                  callId: 'tc1',
                  toolName: 'bash',
                ),
                settled: const DeliveredJobReport(
                  callId: 'tc1',
                  toolName: 'bash',
                  succeeded: true,
                  body: 'the whole output',
                  outstanding: 0,
                ),
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('the whole output'));
        expect(tester.terminalState, isNot(containsText('Still running.')));
      });
    });

    // A shell fills Details, but the call keeps its name in the header and its
    // arguments behind {} — losing them the moment a command runs is how you
    // end up looking at an unlabelled terminal.
    test('keeps name and args reachable when a shell fills Details', () async {
      final session = _MockSurface();
      when(() => session.changes).thenAnswer((_) => const Stream.empty());
      when(() => session.screen).thenReturn(null);
      when(() => session.exited).thenReturn(false);
      final shell = _MockShellUseCase();
      when(
        () => shell.agentShellFor('tc1'),
      ).thenAnswer((_) => Stream.value(AgentShellLive(session)));

      await testNocterm('tool shell detail', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _tool()), shell: shell),
        );
        await tester.pump();

        // The terminal fills Details; the header still names the call.
        expect(tester.terminalState, containsText('calculator'));
        expect(tester.terminalState, containsText('Starting'));

        // The arguments are a tab away, not lost to the terminal.
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(selected: _tool(), tab: DetailsTab.properties),
            shell: shell,
          ),
        );
        expect(tester.terminalState, containsText('expression'));
      }, size: const Size(80, 30));
    });

    ToolActivityTimelineItem tallCall() => _tool(
      arguments: {'command': List.filled(20, 'echo one').join('\n')},
    );

    ShellUseCase spawningShellOn() {
      final session = _MockSurface();
      when(() => session.changes).thenAnswer((_) => const Stream.empty());
      when(() => session.screen).thenReturn(null);
      when(() => session.exited).thenReturn(false);
      final shell = _MockShellUseCase();
      when(
        () => shell.agentShellFor('tc1'),
      ).thenAnswer((_) => Stream.value(AgentShellLive(session)));
      return shell;
    }

    Future<void> wheelDown(NoctermTester tester, {required int over}) async {
      for (var tick = 0; tick < 8; tick++) {
        await tester.sendMouseEvent(
          MouseEvent(
            button: MouseButton.wheelDown,
            x: 2,
            y: over,
            pressed: true,
          ),
        );
      }
      await tester.pump();
    }

    // The terminal fills Details; the command that ran it is reached through
    // the {} tab, not by scrolling past a terminal that has no ceiling.
    test('reaches the shell command through the {} tab', () async {
      await testNocterm('details pane tabs', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(selected: tallCall()),
            shell: spawningShellOn(),
          ),
        );
        await tester.pump();

        // Details is the terminal, not the command text.
        expect(tester.terminalState, containsText('Starting'));
        expect(tester.terminalState, isNot(containsText('echo one')));

        // The command is behind {}, its own pinned pane.
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: tallCall(),
              tab: DetailsTab.properties,
            ),
            shell: spawningShellOn(),
          ),
        );
        expect(tester.terminalState, containsText('echo one'));
      }, size: const Size(40, 20));
    });

    test('follows the tail once the user has scrolled to it', () async {
      final selection = _Selection(_answer(blocks: [_lines(30)]));

      await testNocterm('details tail follow', (tester) async {
        await tester.pumpComponent(_paneOver(selection));

        expect(tester.terminalState, containsText('Bestie'));
        expect(tester.terminalState, isNot(containsText('line 30')));

        for (var spin = 0; spin < 20; spin++) {
          await wheelDown(tester, over: 6);
        }
        expect(tester.terminalState, containsText('line 30'));

        selection.value = _answer(blocks: [_lines(40)]);
        await tester.pump();

        expect(tester.terminalState, containsText('line 40'));
      }, size: const Size(40, 12));
    });

    test('follows streaming text as it outgrows the pane', () async {
      final selection = _Selection(_thinking(2));

      await testNocterm('details streaming follow', (tester) async {
        await tester.pumpComponent(_paneOver(selection));
        expect(tester.terminalState, containsText('Reasoning'));

        selection.value = _thinking(30);
        await tester.pump();

        expect(tester.terminalState, containsText('line 30'));
      }, size: const Size(40, 12));
    });

    test('opens a streaming item at its tail', () async {
      final selection = _Selection(_answer());

      await testNocterm('details streaming open', (tester) async {
        await tester.pumpComponent(_paneOver(selection));
        expect(tester.terminalState, containsText('Bestie'));

        selection.value = _thinking(30);
        await tester.pump();
        expect(tester.terminalState, containsText('line 30'));

        selection.value = _thinking(40);
        await tester.pump();
        expect(tester.terminalState, containsText('line 40'));
      }, size: const Size(40, 12));
    });

    test('opens a newly selected item on its header', () async {
      final selection = _Selection(_answer(blocks: [_lines(30)]));

      await testNocterm('details reselect resets', (tester) async {
        await tester.pumpComponent(_paneOver(selection));
        for (var spin = 0; spin < 20; spin++) {
          await wheelDown(tester, over: 6);
        }
        expect(tester.terminalState, containsText('line 30'));

        selection.value = _reasoning();
        await tester.pump();

        expect(tester.terminalState, containsText('Reasoning'));
        expect(tester.terminalState, containsText('thinking hard'));
      }, size: const Size(40, 12));
    });

    test('leaves no shell heading on a call that holds none', () async {
      await testNocterm('tool no shell', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _tool())),
        );
        await tester.pump();

        expect(tester.terminalState, containsText('calculator'));
        expect(tester.terminalState, isNot(containsText('Shell')));
      });
    });

    test('shows a job report in full on selection', () async {
      await testNocterm('subagent report detail', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: JobReportTimelineItem(
                id: 's1',
                timestamp: _t0,
                report: const DeliveredJobReport(
                  callId: 'call-1',
                  toolName: 'Research',
                  succeeded: true,
                  body: 'the findings',
                  outstanding: 0,
                ),
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('Report'));
        expect(tester.terminalState, containsText('Research'));
        expect(tester.terminalState, containsText('the findings'));
      });
    });

    test('lists deduplicated source contributions', () async {
      await testNocterm('tool sources', (tester) async {
        const source = SourceContribution(
          url: 'https://example.com',
          title: 'Example',
        );
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: _tool(contributions: const [source, source]),
            ),
          ),
        );

        expect(tester.terminalState, containsText('Sources'));
        expect(
          tester.terminalState,
          containsText('Example (https://example.com)'),
        );
      });
    });

    test('draws a changed file as a diff under its summary', () async {
      await testNocterm('tool diff', (tester) async {
        const change = DiffContribution(
          path: 'lib/a.dart',
          diff: FileDiff(
            hunks: [
              DiffHunk(
                oldStart: 3,
                oldCount: 2,
                newStart: 3,
                newCount: 2,
                lines: [
                  DiffLine(kind: DiffLineKind.context, text: 'keep'),
                  DiffLine(kind: DiffLineKind.removed, text: 'cow'),
                  DiffLine(kind: DiffLineKind.added, text: 'bull'),
                ],
              ),
            ],
            added: 1,
            removed: 1,
            truncated: true,
          ),
        );
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(selected: _tool(contributions: const [change])),
          ),
        );

        expect(tester.terminalState, containsText('lib/a.dart  +1 −1'));
        expect(tester.terminalState, containsText('@@ -3,2 +3,2 @@'));
        expect(tester.terminalState, containsText('keep'));
        expect(tester.terminalState, containsText('cow'));
        expect(tester.terminalState, containsText('bull'));
        expect(tester.terminalState, containsText('[diff truncated]'));
      });
    });

    test('draws a created file as code under its summary', () async {
      await testNocterm('tool created file', (tester) async {
        const created = CreatedFileContribution(
          path: 'lib/new.dart',
          text: 'void main() {\n  print(1);\n}\n',
          lines: 3,
          truncated: true,
        );
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(selected: _tool(contributions: const [created])),
          ),
        );

        expect(tester.terminalState, containsText('lib/new.dart  +3'));
        expect(tester.terminalState, containsText('1 void main() {'));
        expect(tester.terminalState, containsText('2   print(1);'));
        expect(tester.terminalState, containsText('[file truncated]'));
      });
    });

    test('shows an answer message as sender plus telemetry', () async {
      await testNocterm('answer detail', (tester) async {
        await tester.pumpComponent(
          _themed(MessageDetailsPane(selected: _answer())),
        );

        expect(tester.terminalState, containsText('Bestie'));
        expect(tester.terminalState, containsText('800ms  20 tok'));
      });
    });

    test('sums a multi-block answer into one stat line', () async {
      // One message, several blocks: the reader wants what the answer cost,
      // not what each paragraph of it did.
      await testNocterm('merged stats', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: _answer(
                blocks: [
                  _block(
                    text: 'second',
                    startedAfter: const Duration(seconds: 1),
                    endedAfter: const Duration(seconds: 3),
                    tokens: 30,
                  ),
                  _block(
                    text: 'first',
                    startedAfter: Duration.zero,
                    endedAfter: const Duration(seconds: 2),
                    tokens: 12,
                  ),
                ],
              ),
            ),
          ),
        );

        // Earliest start to latest end, whichever block each came from.
        expect(tester.terminalState, containsText('3.0s  42 tok'));
      });
    });

    test('shows the reasoning a compaction summary was drawn from', () async {
      await testNocterm('compaction reasoning', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: CompactionMarkerTimelineItem(
                id: 'c1',
                timestamp: _t0,
                summary: 'the memory note',
                summaryReasoning: 'why it kept that',
                tokensBefore: 1234,
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('Reasoning'));
        expect(tester.terminalState, containsText('why it kept that'));
        expect(tester.terminalState, containsText('Summary'));
      });
    });

    test('copies a selection dragged across the pane', () async {
      final copied = <String>[];
      final platform = _MockOSPlatformRepository();
      when(() => platform.copyToClipboard(any())).thenAnswer((
        invocation,
      ) async {
        copied.add(invocation.positionalArguments.single as String);
      });

      await testNocterm('copy selection', (tester) async {
        await tester.pumpComponent(
          RepositoryProvider<OSPlatformRepository>.value(
            value: platform,
            child: _themed(MessageDetailsPane(selected: _reasoning())),
          ),
        );

        // The header is fixed chrome; the selectable body sits below it.
        await _drag(tester, from: (0, 4), to: (13, 4));

        expect(copied.single, contains('thinking'));
      });
    });

    test('renders the placeholder when nothing is selected', () async {
      await testNocterm('placeholder', (tester) async {
        await tester.pumpComponent(
          _themed(const MessageDetailsPane(selected: null)),
        );
        expect(
          tester.terminalState,
          containsText('Pick a message to read it here.'),
        );
      });
    });

    test('renders notice, model card, and compaction items', () async {
      await testNocterm('non-message items', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: NoticeTimelineItem(
                id: 'n1',
                timestamp: _t0,
                text: 'welcome',
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('System'));

        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: ModelCardTimelineItem(
                id: 'm1',
                timestamp: _t0,
                card: const ModelSnapshot.remote(
                  modelId: 'org/model',
                  displayName: 'Model',
                  contextSize: 4096,
                  provider: 'OpenRouter',
                ),
              ),
              tab: DetailsTab.properties,
            ),
          ),
        );
        expect(tester.terminalState, containsText('org/model'));

        await tester.pumpComponent(
          _themed(
            MessageDetailsPane(
              selected: CompactionMarkerTimelineItem(
                id: 'c1',
                timestamp: _t0,
                summary: 'the memory note',
                tokensBefore: 1234,
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Compaction memory'));
        expect(tester.terminalState, containsText('the memory note'));
      });
    });
  });
}
