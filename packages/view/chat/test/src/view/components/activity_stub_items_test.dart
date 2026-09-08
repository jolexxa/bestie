import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/activity_stub_items.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show ToolCallDefault, ToolCallFailed, ToolCallSucceeded;

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

final _t0 = DateTime.utc(2026);

/// Every rendered row below the first that has anything on it — empty when
/// the component drew a single line.
List<String> _rowsBelowTheFirst(NoctermTester tester) => tester.terminalState
    .getText()
    .split('\n')
    .skip(1)
    .map((row) => row.trim())
    .where((row) => row.isNotEmpty)
    .toList();

void main() {
  group('ReasoningStubItemView', () {
    test('shows the elapsed time once settled', () async {
      await testNocterm('reasoning settled', (tester) async {
        await tester.pumpComponent(
          _themed(
            ReasoningStubItemView(
              ReasoningStubTimelineItem(
                id: 'r1',
                timestamp: _t0,
                text: 'x',
                stat: BlockStat(
                  startedAt: _t0,
                  endedAt: _t0.add(const Duration(milliseconds: 1200)),
                ),
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Thought for 1.2s'));
      });
    });

    test('shows the rolling summary alone while live', () async {
      await testNocterm('reasoning live summary', (tester) async {
        await tester.pumpComponent(
          _themed(
            ReasoningStubItemView(
              ReasoningStubTimelineItem(
                id: 'r1',
                timestamp: _t0,
                text: 'x',
                running: true,
              ),
              snippet: 'checking facts',
            ),
          ),
        );
        expect(tester.terminalState, containsText('checking facts'));
        expect(tester.terminalState, isNot(containsText('Thinking…')));
      });
    });

    test('falls back to Thinking… while live without a summary', () async {
      await testNocterm('reasoning live no summary', (tester) async {
        await tester.pumpComponent(
          _themed(
            ReasoningStubItemView(
              ReasoningStubTimelineItem(
                id: 'r1',
                timestamp: _t0,
                text: 'x',
                running: true,
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Thinking…'));
      });
    });

    test('draws a prefill bar under Thinking… while reprocessing', () async {
      await testNocterm('reasoning prefill bar', (tester) async {
        await tester.pumpComponent(
          _themed(
            ReasoningStubItemView(
              ReasoningStubTimelineItem(
                id: 'r1',
                timestamp: _t0,
                text: 'x',
                running: true,
                prefillFraction: 0.5,
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Thinking…'));
        expect(tester.terminalState, containsText('█'));
      });
    });

    test('shows no prefill bar without a fraction', () async {
      await testNocterm('reasoning no bar', (tester) async {
        await tester.pumpComponent(
          _themed(
            ReasoningStubItemView(
              ReasoningStubTimelineItem(
                id: 'r1',
                timestamp: _t0,
                text: 'x',
                running: true,
              ),
            ),
          ),
        );
        expect(tester.terminalState, isNot(containsText('█')));
      });
    });
  });

  group('ActivityStubItemView / a tool call', () {
    ToolActivityTimelineItem tool({
      bool running = false,
      bool isError = false,
      bool interrupted = false,
      String? label = r'Calculated ${expression}',
      Map<String, Object?> arguments = const {'expression': '2+2'},
    }) => ToolActivityTimelineItem(
      id: 't1',
      timestamp: _t0,
      toolCall: ToolCallDefault(
        id: 'tc1',
        name: 'calculator',
        arguments: arguments,
      ),
      labelTemplate: label,
      running: running,
      result: running || interrupted
          ? null
          : isError
          ? const ToolCallFailed(
              callId: 'tc1',
              toolName: 'calculator',
              message: 'boom',
            )
          : const ToolCallSucceeded(
              callId: 'tc1',
              toolName: 'calculator',
              content: '4',
            ),
    );

    test('renders the interpolated label with a success glyph', () async {
      await testNocterm('tool success', (tester) async {
        await tester.pumpComponent(_themed(ActivityStubItemView(tool())));
        expect(tester.terminalState, containsText('Calculated'));
        expect(tester.terminalState, containsText('2+2'));
        expect(tester.terminalState, containsText('✓'));
      });
    });

    // A stub is an index entry into the details pane, so it costs one row
    // whatever it was called with — a script pasted into `bash` would
    // otherwise push the rest of the conversation off the screen.
    test('flattens a multi-line argument onto its one row', () async {
      await testNocterm('tool multiline argument', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              tool(
                label: r'Ran ${command}',
                arguments: const {
                  'command': 'echo one\necho two\necho three',
                },
              ),
            ),
          ),
        );

        expect(
          tester.terminalState,
          containsText('Ran echo one echo two echo three'),
        );
        expect(_rowsBelowTheFirst(tester), <String>[]);
      });
    });

    test('ellipsizes an argument too long for its one row', () async {
      await testNocterm('tool long argument', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              tool(
                label: r'Ran ${command}',
                arguments: {'command': 'echo ${'x' * 200}'},
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('…'));
        expect(_rowsBelowTheFirst(tester), <String>[]);
      });
    });

    test('spins a live call rather than settling on a glyph', () async {
      await testNocterm('tool running', (tester) async {
        await tester.pumpComponent(
          _themed(ActivityStubItemView(tool(running: true))),
        );
        expect(tester.terminalState, containsText('Calculated'));
        // None of the settled outcomes have been decided yet.
        expect(tester.terminalState, isNot(containsText('✓')));
        expect(tester.terminalState, isNot(containsText('✗')));
        expect(tester.terminalState, isNot(containsText('⚠')));
      });
    });

    test('marks an errored call with a failure glyph', () async {
      await testNocterm('tool error', (tester) async {
        await tester.pumpComponent(
          _themed(ActivityStubItemView(tool(isError: true))),
        );
        expect(tester.terminalState, containsText('✗'));
      });
    });

    test(
      'marks an interrupted call (no result, not live) with a warning glyph',
      () async {
        await testNocterm('tool interrupted', (tester) async {
          await tester.pumpComponent(
            _themed(ActivityStubItemView(tool(interrupted: true))),
          );
          expect(tester.terminalState, containsText('⚠'));
          expect(tester.terminalState, isNot(containsText('✓')));
        });
      },
    );

    test('falls back to the tool name without a template', () async {
      await testNocterm('tool no template', (tester) async {
        await tester.pumpComponent(
          _themed(ActivityStubItemView(tool(label: null))),
        );
        expect(tester.terminalState, containsText('calculator'));
      });
    });

    test('keeps the label beside the first line of a tall value', () async {
      // A shell command runs to many lines. Centering the literal against it
      // strands `Ran` in the middle of the script it introduces.
      await testNocterm('tool multiline label', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              ToolActivityTimelineItem(
                id: 't1',
                timestamp: _t0,
                toolCall: const ToolCallDefault(
                  id: 'tc1',
                  name: 'bash',
                  arguments: {'command': 'count=1\nsleep 1\ndone'},
                ),
                labelTemplate: r'Ran ${command}',
                result: const ToolCallSucceeded(
                  callId: 'tc1',
                  toolName: 'bash',
                  content: '1',
                ),
              ),
            ),
          ),
        );

        final rows = tester.toSnapshot().split('\n');
        expect(rows.first, contains('Ran'));
        expect(rows.first, contains('count=1'));
      });
    });

    test('marks a call whose job runs on as succeeded', () async {
      // The call ran and answered; what its job goes on to do is reported by
      // the job's own row, not by this one.
      await testNocterm('tool in background', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              ToolActivityTimelineItem(
                id: 't1',
                timestamp: _t0,
                toolCall: const ToolCallDefault(
                  id: 'tc1',
                  name: 'subagent',
                  arguments: {'title': 'Research'},
                ),
                labelTemplate: r'Started subagent: ${title}',
                result: const ToolCallInBackground(
                  callId: 'tc1',
                  toolName: 'subagent',
                  content: 'dispatched',
                ),
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('✓'));
        expect(tester.terminalState, isNot(containsText('●')));
      });
    });
  });

  group('ActivityStubItemView / a job that ran on', () {
    BackgroundJobTimelineItem job({DeliveredJobReport? settled}) =>
        BackgroundJobTimelineItem(
          id: 'j1',
          timestamp: _t0,
          job: const JobInBackground(
            callId: 'tc1',
            toolName: 'bash',
            labelTemplate: r'Running ${command}',
            labelArguments: {'command': 'sleep 30'},
          ),
          settled: settled,
        );

    DeliveredJobReport report({required bool succeeded}) => DeliveredJobReport(
      callId: 'tc1',
      toolName: 'bash',
      succeeded: succeeded,
      body: 'done',
      outstanding: 0,
    );

    test('reads as live while the job is still going', () async {
      await testNocterm('job running', (tester) async {
        await tester.pumpComponent(_themed(ActivityStubItemView(job())));

        expect(tester.terminalState, containsText('Running'));
        expect(tester.terminalState, containsText('sleep 30'));
        expect(tester.terminalState, isNot(containsText('✓')));
      });
    });

    test('settles to a success glyph once its report lands', () async {
      await testNocterm('job settled ok', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(job(settled: report(succeeded: true))),
          ),
        );

        expect(tester.terminalState, containsText('✓'));
        // Its own label, not the report's — the report has its own row.
        expect(tester.terminalState, containsText('Running'));
      });
    });

    test('settles to a failure glyph when the job failed', () async {
      await testNocterm('job settled failed', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(job(settled: report(succeeded: false))),
          ),
        );

        expect(tester.terminalState, containsText('✗'));
      });
    });

    test('falls back to the tool name without a stamped label', () async {
      await testNocterm('job no label', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              BackgroundJobTimelineItem(
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

        expect(tester.terminalState, containsText('bash'));
      });
    });
  });

  group('ActivityStubItemView / a settled report', () {
    JobReportTimelineItem item(DeliveredJobReport report) =>
        JobReportTimelineItem(id: 's1', timestamp: _t0, report: report);

    test('renders the stamped label with a success glyph', () async {
      await testNocterm('job report ok', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              item(
                const DeliveredJobReport(
                  callId: 'call-1',
                  toolName: 'subagent',
                  succeeded: true,
                  body: 'done',
                  outstanding: 0,
                  labelTemplate: r'Subagent finished: ${title}',
                  labelArguments: {'title': 'Research'},
                ),
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Subagent finished'));
        expect(tester.terminalState, containsText('Research'));
        expect(tester.terminalState, containsText('✓'));
      });
    });

    test('renders the stamped failure label with a failure glyph', () async {
      await testNocterm('job report failed', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              item(
                const DeliveredJobReport(
                  callId: 'call-1',
                  toolName: 'subagent',
                  succeeded: false,
                  body: 'x',
                  outstanding: 0,
                  labelTemplate: r'Subagent failed: ${title}',
                  labelArguments: {'title': 'Lookup'},
                ),
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('Subagent failed'));
        expect(tester.terminalState, containsText('Lookup'));
        expect(tester.terminalState, containsText('✗'));
      });
    });

    test('falls back to the tool name without a stamped label', () async {
      await testNocterm('job report no label', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              item(
                const DeliveredJobReport(
                  callId: 'call-1',
                  toolName: 'shell',
                  succeeded: true,
                  body: 'done',
                  outstanding: 0,
                ),
              ),
            ),
          ),
        );
        expect(tester.terminalState, containsText('shell'));
      });
    });
  });

  // One view serves all three kinds of labelled row, so it takes the base
  // type and has to answer for the kinds that carry no label. Drawing nothing
  // is the answer: a row that has no stub is not a blank stub.
  group('ActivityStubItemView / a row that carries no label', () {
    test('draws nothing at all', () async {
      await testNocterm('stub without a label', (tester) async {
        await tester.pumpComponent(
          _themed(
            ActivityStubItemView(
              NoticeTimelineItem(id: 'n1', timestamp: _t0, text: 'welcome'),
            ),
          ),
        );

        expect(tester.terminalState.getText().trim(), '');
      });
    });
  });
}
