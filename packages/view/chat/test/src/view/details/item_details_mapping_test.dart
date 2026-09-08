import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/details/activity_badge.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:bestie_chat_view/src/view/details/item_details_mapping.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show
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
        ToolCallSucceeded;

final _t0 = DateTime.utc(2026, 1, 1, 14, 30);

ToolActivityTimelineItem _tool({
  Map<String, Object?> arguments = const {'expression': '2+2'},
  ToolCallResponse? result,
}) => ToolActivityTimelineItem(
  id: 't1',
  timestamp: _t0,
  toolCall: ToolCallDefault(
    id: 'tc1',
    name: 'calculator',
    arguments: arguments,
  ),
  result: result,
);

/// The sections of type [T] across both tabs, counting a live section's
/// fallback as one: it fills the same slot, just when the live body turns out
/// to be empty.
List<T> _sections<T extends DetailSection>(ItemDetails details) => [
  for (final section in [...details.properties, ...details.content]) ...[
    if (section is T) section,
    if (section is LiveSection && section.fallback is T) section.fallback! as T,
  ],
];

void main() {
  group('every item gets the same spine', () {
    // Whatever the row is, the pane draws a title and one dim meta line in
    // the same place. A new kind of row inherits the layout rather than
    // inventing one, which is the whole point of mapping before rendering.
    final items = <String, TimelineItem>{
      'message': MessageTimelineItem(
        id: 'm1',
        role: Role.assistant,
        timestamp: _t0,
        blocks: const [],
      ),
      'reasoning': ReasoningStubTimelineItem(
        id: 'r1',
        timestamp: _t0,
        text: 'thinking',
      ),
      'tool': _tool(),
      'tool call draft': ToolCallDraftTimelineItem(id: 'd1', timestamp: _t0),
      'background job': BackgroundJobTimelineItem(
        id: 'j1',
        timestamp: _t0,
        job: const JobInBackground(callId: 'tc1', toolName: 'bash'),
      ),
      'job report': JobReportTimelineItem(
        id: 's1',
        timestamp: _t0,
        report: const DeliveredJobReport(
          callId: 'c1',
          toolName: 'Research',
          succeeded: true,
          body: 'findings',
          outstanding: 0,
        ),
      ),
      'compaction': CompactionMarkerTimelineItem(
        id: 'c1',
        timestamp: _t0,
        summary: 'note',
        tokensBefore: 1234,
      ),
      'notice': NoticeTimelineItem(id: 'n1', timestamp: _t0, text: 'welcome'),
      'model card': ModelCardTimelineItem(
        id: 'mc1',
        timestamp: _t0,
        card: const ModelSnapshot.remote(
          modelId: 'org/model',
          displayName: 'Model',
          contextSize: 4096,
          provider: 'OpenRouter',
        ),
      ),
    };

    for (final MapEntry(key: name, value: item) in items.entries) {
      test('$name has a title and a meta line', () {
        final details = item.asItemDetails;
        expect(details.title, isNotEmpty, reason: '$name needs a title');
        expect(
          details.measurements.first.displayAt(_t0),
          '2:30 PM',
          reason: '$name needs a time',
        );
      });
    }
  });

  group('a tool call still being drafted', () {
    final details = ToolCallDraftTimelineItem(
      id: 'd1',
      timestamp: _t0,
    ).asItemDetails;

    test('reads as a running model row with nothing to show yet', () {
      expect(details.title, 'Tool call');
      expect(details.subtitle, 'Still being written');
      expect(details.accent, DetailAccent.running);
      expect(details.provenance, Provenance.model);
      expect(details.glyph, '·');
      expect(details.content, isEmpty);
      expect(details.properties, isEmpty);
    });
  });

  group('the measurement strip holds its shape', () {
    ReasoningStubTimelineItem streaming({int? tokens, Duration? took}) =>
        ReasoningStubTimelineItem(
          id: 'r1',
          timestamp: _t0,
          text: 'thinking',
          running: tokens == null,
          stat: BlockStat(
            startedAt: _t0,
            endedAt: _t0.add(took ?? Duration.zero),
            tokenCount: tokens,
          ),
        );

    // The reading that arrives last used to arrive as a whole new segment,
    // so the line grew under the reader mid-stream.
    test('declares every slot before any of them has a number', () {
      final live = streaming();
      final settled = streaming(tokens: 51, took: const Duration(seconds: 2));

      expect(
        live.asItemDetails.measurements.length,
        settled.asItemDetails.measurements.length,
      );
    });

    test('draws an empty slot rather than omitting it', () {
      final displays = [
        for (final m in streaming().asItemDetails.measurements)
          m.displayAt(_t0),
      ];
      expect(displays, contains('— tok'));
      expect(displays, contains('— tok/s'));
    });

    test('fills the slot in once the run settles', () {
      final displays = [
        for (final m in streaming(
          tokens: 100,
          took: const Duration(seconds: 2),
        ).asItemDetails.measurements)
          m.displayAt(_t0),
      ];
      expect(displays, contains('100 tok'));
      expect(displays, contains('50.0 tok/s'));
    });

    // A tool call in flight has no elapsed time yet either.
    test('holds a slot for a call that has not landed', () {
      expect(
        _tool().asItemDetails.measurements.map((m) => m.displayAt(_t0)),
        contains('—'),
      );
    });

    // The delta clock stops between chunks; a live slot keeps counting from
    // when the run began so the reading moves with the wall clock.
    test('counts up from when a live run began', () {
      final details = streaming().asItemDetails;
      final later = _t0.add(const Duration(milliseconds: 2500));

      expect(details.live, isTrue);
      expect(
        details.measurements.map((m) => m.displayAt(later)),
        contains('2.5s'),
      );
    });

    test('settles on how long the run took once it lands', () {
      final details = streaming(
        tokens: 100,
        took: const Duration(seconds: 2),
      ).asItemDetails;
      final muchLater = _t0.add(const Duration(minutes: 5));

      expect(details.live, isFalse);
      expect(
        details.measurements.map((m) => m.displayAt(muchLater)),
        contains('2.0s'),
      );
    });

    test('a streaming message counts from its first block', () {
      final details = MessageTimelineItem(
        id: 'm1',
        role: Role.assistant,
        timestamp: _t0,
        running: true,
        blocks: [
          TranscriptParagraphBlock(
            id: TranscriptBlockId.v7(),
            text: 'hel',
            stat: BlockStat(
              startedAt: _t0,
              endedAt: _t0.add(const Duration(milliseconds: 300)),
            ),
          ),
        ],
      ).asItemDetails;

      expect(details.live, isTrue);
      expect(
        details.measurements.map(
          (m) => m.displayAt(_t0.add(const Duration(seconds: 4))),
        ),
        contains('4.0s'),
      );
    });
  });

  group('inputs and outputs split across tabs', () {
    // The command that produced the output is already on the stub that was
    // clicked to get here; Details is what the pane was opened for, and the
    // arguments sit behind the `{}` tab.
    test('a tool shows its shell then sources, arguments in {}', () {
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
          contributions: [SourceContribution(url: 'https://example.com')],
        ),
      ).asItemDetails;

      expect(details.content.first, isA<LiveSection>());
      expect(
        details.content.indexWhere((s) => s is LinksSection),
        greaterThan(details.content.indexWhere((s) => s is LiveSection)),
      );
      expect(details.properties.single, isA<FactsSection>());
    });

    test('a background job puts its shell in Details', () {
      final details = BackgroundJobTimelineItem(
        id: 'j1',
        timestamp: _t0,
        job: const JobInBackground(callId: 'tc1', toolName: 'bash'),
        settled: const DeliveredJobReport(
          callId: 'tc1',
          toolName: 'bash',
          succeeded: true,
          body: 'output',
          outstanding: 0,
        ),
      ).asItemDetails;

      // The shell is the whole of it: the report reads better as the terminal
      // that produced it, and stands in only when there is no terminal.
      final live = details.content.single as LiveSection;
      expect(live.key, 'tc1');
      expect((live.fallback! as TextSection).label, 'Report');
    });

    // A job is titled by its tool, so a backgrounded shell reads as
    // `bash` and nothing else. What it was asked to run is the only
    // thing telling one apart from another, so it is carried even though it
    // comes second.
    test('a background job still says what it was asked to run', () {
      final details = BackgroundJobTimelineItem(
        id: 'j1',
        timestamp: _t0,
        job: const JobInBackground(
          callId: 'tc1',
          toolName: 'bash',
          labelTemplate: r'Continuing in background: ${command}',
          labelArguments: {'command': 'sleep 30'},
        ),
      ).asItemDetails;

      expect(details.content.first, isA<LiveSection>());
      final facts = _sections<FactsSection>(details).single;
      expect(facts.facts.single.label, 'command');
      expect(facts.facts.single.value, 'sleep 30');
    });

    test('a settled report still says what it was asked to run', () {
      final details = JobReportTimelineItem(
        id: 's1',
        timestamp: _t0,
        report: const DeliveredJobReport(
          callId: 'tc1',
          toolName: 'bash',
          succeeded: true,
          body: 'output',
          outstanding: 0,
          labelTemplate: r'Finished: ${command}',
          labelArguments: {'command': 'sleep 30'},
        ),
      ).asItemDetails;

      expect(details.content.first, isA<TextSection>());
      expect(
        _sections<FactsSection>(details).single.facts.single.value,
        'sleep 30',
      );
    });
  });

  group('tool calls', () {
    test('are titled by the tool, not by whoever called it', () {
      expect(_tool().asItemDetails.title, 'calculator');
    });

    test('lay arguments out as facts', () {
      final facts = _sections<FactsSection>(_tool().asItemDetails).single;
      expect(facts.facts.single.label, 'expression');
      expect(facts.facts.single.value, '2+2');
    });

    test('flatten a nested argument into dotted rows', () {
      final facts = _sections<FactsSection>(
        _tool(
          arguments: const {
            'edits': {'path': 'a.dart', 'line': 42},
          },
        ).asItemDetails,
      ).single;
      expect(facts.facts.map((f) => (f.label, f.value)), [
        ('edits.path', 'a.dart'),
        ('edits.line', '42'),
      ]);
    });

    test('index list arguments as they flatten', () {
      final facts = _sections<FactsSection>(
        _tool(
          arguments: const {
            'paths': ['a.dart', 'b.dart'],
          },
        ).asItemDetails,
      ).single;
      expect(facts.facts.map((f) => (f.label, f.value)), [
        ('paths[0]', 'a.dart'),
        ('paths[1]', 'b.dart'),
      ]);
    });

    test('put elapsed time on the meta line, not inside the output', () {
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
          elapsedMs: 35,
        ),
      ).asItemDetails;

      expect(
        details.measurements.map((m) => m.displayAt(_t0)),
        contains('35ms'),
      );
      expect(
        _sections<TextSection>(details).single.text,
        '4',
        reason: 'the value is the value; timing is metadata',
      );
    });

    test('offer a live body keyed by the call, with no forced heading', () {
      final live = _sections<LiveSection>(_tool().asItemDetails).single;
      expect(live.key, 'tc1');
      expect(live.label, isNull);
    });

    test('label a failure as an error', () {
      final details = _tool(
        result: const ToolCallFailed(
          callId: 'tc1',
          toolName: 'calculator',
          message: 'boom',
        ),
      ).asItemDetails;
      final text = _sections<TextSection>(details).single;
      expect(text.label, 'Error');
      expect(text.accent, DetailAccent.error);
      expect(details.subtitle, 'Failed');
    });

    test('label an interruption as one', () {
      final details = _tool(
        result: const ToolCallCanceled(
          callId: 'tc1',
          toolName: 'calculator',
          message: 'stopped',
        ),
      ).asItemDetails;
      expect(details.subtitle, 'Interrupted');
    });

    test('deduplicate sources by url', () {
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
          contributions: [
            SourceContribution(url: 'https://example.com', title: 'Example'),
            SourceContribution(url: 'https://example.com', title: 'Again'),
            SourceContribution(url: 'https://other.com'),
          ],
        ),
      ).asItemDetails;

      final links = _sections<LinksSection>(details).single;
      expect(links.links.map((l) => l.url), [
        'https://example.com',
        'https://other.com',
      ]);
    });

    test('show each changed file as a diff after the live body', () {
      const change = FileDiff(
        hunks: [
          DiffHunk(
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 2,
            lines: [
              DiffLine(kind: DiffLineKind.context, text: 'a'),
              DiffLine(kind: DiffLineKind.added, text: 'b'),
            ],
          ),
        ],
        added: 1,
        removed: 0,
      );
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'edit',
          content: 'Replaced 1 occurrence',
          contributions: [
            DiffContribution(path: 'lib/a.dart', diff: change),
            DiffContribution(path: 'lib/b.dart', diff: change),
          ],
        ),
      ).asItemDetails;

      final diffs = _sections<DiffSection>(details);
      expect(diffs.map((section) => section.path), [
        'lib/a.dart',
        'lib/b.dart',
      ]);
      expect(diffs.first.diff, change);
      expect(
        details.content.indexWhere((s) => s is DiffSection),
        greaterThan(details.content.indexWhere((s) => s is LiveSection)),
      );
      expect(details.subtitle, 'lib/a.dart  +1 −0, lib/b.dart  +1 −0');
    });

    test('show each created file as its text before any diff', () {
      const change = FileDiff(hunks: [], added: 1, removed: 0);
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'create',
          content: 'Created lib/new.dart (2 lines).',
          contributions: [
            DiffContribution(path: 'lib/a.dart', diff: change),
            CreatedFileContribution(
              path: 'lib/new.dart',
              text: 'a\nb\n',
              lines: 2,
              truncated: true,
            ),
          ],
        ),
      ).asItemDetails;

      final created = _sections<CreatedFileSection>(details).single;
      expect(created.path, 'lib/new.dart');
      expect(created.text, 'a\nb\n');
      expect(created.lines, 2);
      expect(created.truncated, isTrue);
      expect(
        details.content.indexWhere((s) => s is CreatedFileSection),
        greaterThan(details.content.indexWhere((s) => s is LiveSection)),
      );
      expect(
        details.content.indexWhere((s) => s is DiffSection),
        greaterThan(details.content.indexWhere((s) => s is CreatedFileSection)),
      );
      expect(details.subtitle, 'lib/new.dart  +2, lib/a.dart  +1 −0');
    });

    test('carry no subtitle when nothing was changed', () {
      final details = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
        ),
      ).asItemDetails;

      expect(_sections<DiffSection>(details), isEmpty);
      expect(details.subtitle, isNull);
    });

    test('offer no links when nothing contributed one', () {
      expect(_sections<LinksSection>(_tool().asItemDetails), isEmpty);
    });
  });

  group('other rows', () {
    // The number the marker exists to report was not shown at all before.
    test('a compaction marker reports what it folded away', () {
      final facts = _sections<FactsSection>(
        CompactionMarkerTimelineItem(
          id: 'c1',
          timestamp: _t0,
          summary: 'note',
          tokensBefore: 1234,
        ).asItemDetails,
      ).single;
      expect(facts.facts.single.value, contains('1,234'));
    });

    test('a compaction marker shows its reasoning before its summary', () {
      final texts = _sections<TextSection>(
        CompactionMarkerTimelineItem(
          id: 'c1',
          timestamp: _t0,
          summary: 'note',
          summaryReasoning: 'why',
          tokensBefore: 1,
        ).asItemDetails,
      );
      expect(texts.map((t) => t.label), ['Reasoning', 'Summary']);
    });

    // Selecting a notice used to render a header and nothing else.
    test('a notice shows its text', () {
      final texts = _sections<TextSection>(
        NoticeTimelineItem(
          id: 'n1',
          timestamp: _t0,
          text: 'welcome',
        ).asItemDetails,
      );
      expect(texts.single.text, 'welcome');
    });

    // It used to be one line of `displayName (modelId)`.
    test('a model card lays out as a facts table', () {
      final facts = _sections<FactsSection>(
        ModelCardTimelineItem(
          id: 'mc1',
          timestamp: _t0,
          card: const ModelSnapshot.remote(
            modelId: 'org/model',
            displayName: 'Model',
            contextSize: 4096,
            provider: 'OpenRouter',
          ),
        ).asItemDetails,
      ).single;
      expect(facts.facts.map((f) => f.label), ['Model', 'Provider', 'Context']);
    });

    test('a running background job says so, and offers its shell', () {
      final details = BackgroundJobTimelineItem(
        id: 'j1',
        timestamp: _t0,
        job: const JobInBackground(callId: 'tc1', toolName: 'bash'),
      ).asItemDetails;

      expect(details.title, 'bash');
      expect(details.subtitle, 'Running in the background');
      expect(_sections<LiveSection>(details).single.key, 'tc1');
    });

    test('a message keeps its source and its merged stats', () {
      final details = MessageTimelineItem(
        id: 'm1',
        role: Role.user,
        timestamp: _t0,
        blocks: [
          TranscriptParagraphBlock(
            id: TranscriptBlockId.v7(),
            text: 'hello ',
            stat: BlockStat(
              startedAt: _t0,
              endedAt: _t0.add(const Duration(milliseconds: 500)),
              tokenCount: 3,
            ),
          ),
          TranscriptParagraphBlock(
            id: TranscriptBlockId.v7(),
            text: 'there',
            stat: BlockStat(
              startedAt: _t0.add(const Duration(milliseconds: 500)),
              endedAt: _t0.add(const Duration(milliseconds: 900)),
              tokenCount: 4,
            ),
          ),
        ],
      ).asItemDetails;

      expect(details.title, 'You');
      expect(_sections<TextSection>(details).single.text, 'hello there');
      expect(
        details.measurements.map((m) => m.displayAt(_t0)),
        contains('7 tok'),
      );
      expect(
        details.measurements.map((m) => m.displayAt(_t0)),
        contains('900ms'),
      );
    });
  });

  group('badges agree with the chat list', () {
    test('a failed call is marked failed', () {
      final badge = ActivityBadge.fromTimelineItem(
        _tool(
          result: const ToolCallFailed(
            callId: 'tc1',
            toolName: 'calculator',
            message: 'boom',
          ),
        ),
      );
      expect(badge?.glyph, '✗');
      expect(badge?.accent, DetailAccent.error);
    });

    test('a running call is marked running', () {
      final badge = ActivityBadge.fromTimelineItem(
        ReasoningStubTimelineItem(
          id: 'r1',
          timestamp: _t0,
          text: '',
          running: true,
        ),
      );
      expect(badge?.accent, DetailAccent.running);
    });

    // The header wears exactly what the row wears; that is what makes
    // clicking a red ✗ land you on a red ✗.
    test('the details header wears the row badge', () {
      final item = _tool(
        result: const ToolCallSucceeded(
          callId: 'tc1',
          toolName: 'calculator',
          content: '4',
        ),
      );
      final badge = ActivityBadge.fromTimelineItem(item);
      final details = item.asItemDetails;
      expect(details.glyph, badge?.glyph);
      expect(details.accent, badge?.accent);
    });

    test('a plain message carries no status badge', () {
      expect(
        ActivityBadge.fromTimelineItem(
          NoticeTimelineItem(id: 'n1', timestamp: _t0, text: 'x'),
        ),
        isNull,
      );
    });
  });

  group('provenance says who is telling you', () {
    MessageTimelineItem message(Role role) => MessageTimelineItem(
      id: 'm1',
      role: role,
      timestamp: _t0,
      blocks: const [],
    );

    test('a message wears its role', () {
      expect(message(Role.user).asItemDetails.provenance, Provenance.you);
      expect(
        message(Role.assistant).asItemDetails.provenance,
        Provenance.model,
      );
      expect(message(Role.tool).asItemDetails.provenance, Provenance.tool);
      expect(
        message(Role.system).asItemDetails.provenance,
        Provenance.harness,
      );
    });

    test('reasoning and tool activity come from the model and its tools', () {
      expect(
        ReasoningStubTimelineItem(
          id: 'r1',
          timestamp: _t0,
          text: 'x',
        ).asItemDetails.provenance,
        Provenance.model,
      );
      expect(_tool().asItemDetails.provenance, Provenance.tool);
      expect(
        BackgroundJobTimelineItem(
          id: 'j1',
          timestamp: _t0,
          job: const JobInBackground(callId: 'tc1', toolName: 'bash'),
        ).asItemDetails.provenance,
        Provenance.tool,
      );
    });

    test('reports, notices, and model cards come from the harness', () {
      expect(
        JobReportTimelineItem(
          id: 's1',
          timestamp: _t0,
          report: const DeliveredJobReport(
            callId: 'c1',
            toolName: 'Research',
            succeeded: true,
            body: 'findings',
            outstanding: 0,
          ),
        ).asItemDetails.provenance,
        Provenance.harness,
      );
      expect(
        NoticeTimelineItem(
          id: 'n1',
          timestamp: _t0,
          text: 'x',
        ).asItemDetails.provenance,
        Provenance.harness,
      );
      expect(
        CompactionMarkerTimelineItem(
          id: 'c1',
          timestamp: _t0,
          summary: 'note',
          tokensBefore: 1,
        ).asItemDetails.provenance,
        Provenance.harness,
      );
    });
  });
}
