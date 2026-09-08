import 'package:agent_repository/agent_repository.dart';
import 'package:agent_repository/src/message/timeline_fold.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

final _time = DateTime.utc(2025);

MessageEntry _entry(
  String id,
  List<TranscriptBlock> blocks, {
  Role role = Role.assistant,
}) => MessageEntry(
  id: id,
  timestamp: _time,
  responseId: 1,
  entry: TranscriptEntry(
    id: TranscriptEntryId.v7(),
    role: role,
    blocks: blocks,
  ),
);

TranscriptToolCallBlock _call() => TranscriptToolCallBlock(
  id: TranscriptBlockId.v7(),
  toolCall: const ToolCallDefault(id: 'call', name: 'search', arguments: {}),
);

TranscriptToolCallResponseBlock _response(ToolCallResponse response) =>
    TranscriptToolCallResponseBlock(
      id: TranscriptBlockId.v7(),
      response: response,
    );

void main() {
  test('splits reasoning, tool activity, and answer in prompt order', () {
    final items = foldTimeline([
      _entry('assistant', [
        TranscriptReasoningBlock(id: TranscriptBlockId.v7(), text: 'think'),
        _call(),
        TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: 'answer'),
      ]),
      _entry('tool', [
        _response(
          const ToolCallSucceeded(
            callId: 'call',
            toolName: 'search',
            content: 'ok',
          ),
        ),
      ], role: Role.tool),
    ]);

    expect(items[0], isA<ReasoningStubTimelineItem>());
    expect((items[1] as ToolActivityTimelineItem).result?.modelText, 'ok');
    expect((items[2] as MessageTimelineItem).text, 'answer');
  });

  test('marks unresolved tool calls as running only for a live turn', () {
    final settled = foldTimeline([
      _entry('assistant', [_call()]),
    ]);
    final live = foldTimeline([
      _entry('assistant', [_call()]),
    ], live: true);

    expect((settled.single as ToolActivityTimelineItem).running, isFalse);
    expect((live.single as ToolActivityTimelineItem).running, isTrue);
  });

  test('settles a trailing reasoning run once the tail closes', () {
    final reasoning = [
      TranscriptReasoningBlock(id: TranscriptBlockId.v7(), text: 'hmm'),
    ];
    final open = foldTimeline([_entry('assistant', reasoning)], live: true);
    final closed = foldTimeline(
      [_entry('assistant', reasoning)],
      live: true,
      tailOpen: false,
    );

    expect((open.single as ReasoningStubTimelineItem).running, isTrue);
    expect((closed.single as ReasoningStubTimelineItem).running, isFalse);
  });

  test('settles a trailing answer once the tail closes', () {
    final answer = [
      TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: 'so'),
    ];
    final open = foldTimeline([_entry('assistant', answer)], live: true);
    final closed = foldTimeline(
      [_entry('assistant', answer)],
      live: true,
      tailOpen: false,
    );

    expect((open.single as MessageTimelineItem).running, isTrue);
    expect((closed.single as MessageTimelineItem).running, isFalse);
  });

  test('keeps unresolved tool calls running when the tail closes', () {
    final closed = foldTimeline(
      [
        _entry('assistant', [_call()]),
      ],
      live: true,
      tailOpen: false,
    );

    expect((closed.single as ToolActivityTimelineItem).running, isTrue);
  });

  test('renders each delivered job report as its own timeline item', () {
    final items = foldTimeline([
      JobReportEntry(
        id: 'reports',
        timestamp: _time,
        responseId: 2,
        reports: const [
          DeliveredJobReport(
            callId: 'a',
            toolName: 'shell',
            succeeded: true,
            body: 'done',
            outstanding: 0,
          ),
        ],
      ),
    ]);

    expect(items.single, isA<JobReportTimelineItem>());
  });

  group('backgrounded jobs', () {
    JobBackgroundedEntry backgrounded(String callId) => JobBackgroundedEntry(
      id: 'bg-$callId',
      timestamp: _time,
      job: JobInBackground(callId: callId, toolName: 'bash'),
    );

    JobReportEntry reporting(String callId) => JobReportEntry(
      id: 'reports-$callId',
      timestamp: _time,
      responseId: 2,
      reports: [
        DeliveredJobReport(
          callId: callId,
          toolName: 'bash',
          succeeded: true,
          body: 'done',
          outstanding: 0,
        ),
      ],
    );

    BackgroundJobTimelineItem only(List<TimelineItem> items) =>
        items.whereType<BackgroundJobTimelineItem>().single;

    test('renders a backgrounded job as its own row', () {
      final item = only(foldTimeline([backgrounded('a')]));

      expect(item.job.callId, 'a');
      expect(item.settled, isNull);
    });

    test('settles the row from the report that shares its call id', () {
      // The report comes after the job in the entry list, so pairing it needs
      // the whole list read before the walk.
      final item = only(foldTimeline([backgrounded('a'), reporting('a')]));

      expect(item.settled?.body, 'done');
    });

    test('leaves a job unsettled when the report is for another call', () {
      final item = only(foldTimeline([backgrounded('a'), reporting('b')]));

      expect(item.settled, isNull);
    });

    test('keeps the report row alongside the job it settles', () {
      final items = foldTimeline([backgrounded('a'), reporting('a')]);

      expect(items.map((i) => i.runtimeType), [
        BackgroundJobTimelineItem,
        JobReportTimelineItem,
      ]);
    });

    TranscriptToolCallBlock call(String id) => TranscriptToolCallBlock(
      id: TranscriptBlockId.v7(),
      toolCall: ToolCallDefault(id: id, name: 'bash', arguments: const {}),
    );

    MessageEntry answered(String callId) => _entry('tool-$callId', [
      _response(
        ToolCallInBackground(
          callId: callId,
          toolName: 'bash',
          content: 'started $callId',
        ),
      ),
    ], role: Role.tool);

    test('pairs every parallel call with its answer when jobs interleave', () {
      // The session files each job right after the entry answering its call,
      // so the second call's answer arrives after the first call's job.
      final items = foldTimeline([
        _entry('assistant', [call('a'), call('b')]),
        answered('a'),
        backgrounded('a'),
        answered('b'),
        backgrounded('b'),
      ]);

      final tools = items.whereType<ToolActivityTimelineItem>().toList();
      expect(tools.map((t) => t.result?.modelText), [
        'started a',
        'started b',
      ]);
    });

    test('seats each job under the call that started it', () {
      final items = foldTimeline([
        _entry('assistant', [call('a'), call('b')]),
        answered('a'),
        backgrounded('a'),
        answered('b'),
        backgrounded('b'),
        _entry('answer', [
          TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: 'done'),
        ]),
      ]);

      expect(
        items.map(
          (i) => switch (i) {
            ToolActivityTimelineItem(:final toolCall) => 'tool ${toolCall.id}',
            BackgroundJobTimelineItem(:final job) => 'job ${job.callId}',
            MessageTimelineItem(:final text) => text,
            _ => i.runtimeType.toString(),
          },
        ),
        ['tool a', 'job a', 'tool b', 'job b', 'done'],
      );
    });

    test('trails a job no call in the turn claims', () {
      final items = foldTimeline([
        _entry('assistant', [call('a')]),
        answered('a'),
        backgrounded('a'),
        backgrounded('stray'),
      ]);

      expect(
        items.whereType<BackgroundJobTimelineItem>().map((i) => i.job.callId),
        ['a', 'stray'],
      );
      expect(items.last, isA<BackgroundJobTimelineItem>());
    });
  });

  test('keeps system transcript entries out of timeline rows', () {
    expect(
      foldTimeline([
        _entry(
          'summary',
          [
            TranscriptParagraphBlock(
              id: TranscriptBlockId.v7(),
              text: 'memory',
            ),
          ],
          role: Role.system,
        ),
      ]),
      isEmpty,
    );
  });
}
