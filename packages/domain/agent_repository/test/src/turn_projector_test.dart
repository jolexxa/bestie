import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        AgentCancelled,
        AgentCompactionCompleted,
        AgentCompactionFailed,
        AgentCompactionStarted,
        AgentHandle,
        AgentKind,
        AgentNeedsToolResults,
        AgentReasoningDelta,
        AgentStarted,
        AgentSummaryDelta,
        AgentSummaryReasoningDelta,
        AgentTextDelta,
        AgentToolCallEmitted,
        AgentToolCallStarted,
        AgentToolResponseApplied,
        AgentUpdated,
        BlockStat,
        Role,
        ToolCallDefault,
        ToolCallFailed,
        ToolCallSucceeded,
        Transcript,
        TranscriptBlockId,
        TranscriptEntry,
        TranscriptEntryId,
        TranscriptId,
        TranscriptParagraphBlock,
        TranscriptReasoningBlock,
        TranscriptToolCallBlock,
        TranscriptToolCallResponseBlock;
import 'package:agent_repository/src/turn/turn_activity.dart';
import 'package:agent_repository/src/turn/turn_projector.dart';
import 'package:test/test.dart';

const _agent = AgentHandle(id: 'primary', kind: AgentKind.primary);

final _entryId = TranscriptEntryId.v7();
final _textBlockId = TranscriptBlockId.v7();
final _reasoningBlockId = TranscriptBlockId.v7();

TranscriptEntry _userTE(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.user,
  blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
);

Transcript _ts(List<TranscriptEntry> entries) => Transcript(
  id: TranscriptId.v7(),
  revision: entries.length,
  entries: entries,
);

/// A projector mid-turn over [base] — the history the turn answers, which is
/// already committed before it starts.
TurnProjector _begun({List<TranscriptEntry> base = const []}) =>
    TurnProjector()..begin(responseId: 1, base: base);

AgentTextDelta _text(String text, {AgentHandle agent = _agent, DateTime? at}) =>
    AgentTextDelta(
      timestamp: at ?? DateTime.utc(2025),
      agent: agent,
      entryId: _entryId,
      blockId: _textBlockId,
      text: text,
    );

AgentReasoningDelta _reasoning(String text, {DateTime? at}) =>
    AgentReasoningDelta(
      timestamp: at ?? DateTime.utc(2025),
      agent: _agent,
      entryId: _entryId,
      blockId: _reasoningBlockId,
      text: text,
    );

void main() {
  group('TurnProjector mirror', () {
    test('begin opens a turn that has generated nothing yet', () {
      final projector = _begun(base: [_userTE('earlier')]);

      expect(projector.turnEntries, isEmpty);
      expect(projector.active, isTrue);
    });

    test('a mirror shorter than the history read as no generations', () {
      final projector = _begun(base: [_userTE('earlier')])
        ..apply(
          AgentUpdated(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            transcript: _ts(const []),
          ),
        );

      expect(projector.turnEntries, isEmpty);
    });

    test('text and reasoning deltas coalesce into stable blocks', () {
      final projector = _begun()
        ..apply(
          AgentStarted(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            transcript: _ts([_userTE('hi')]),
          ),
        )
        ..apply(_reasoning('thinking'))
        ..apply(_reasoning(' hard'))
        ..apply(_text('an'))
        ..apply(_text('swer'));

      final assistant = projector.turnEntries.last;
      expect(assistant.role, Role.assistant);
      expect(assistant.blocks, hasLength(2));
      final reasoning = assistant.blocks.first as TranscriptReasoningBlock;
      final paragraph = assistant.blocks.last as TranscriptParagraphBlock;
      expect(reasoning.text, 'thinking hard');
      expect(paragraph.text, 'answer');
    });

    test('live blocks carry stats spanning first to latest delta', () {
      final t0 = DateTime.utc(2025);
      final t1 = t0.add(const Duration(milliseconds: 250));
      final projector = _begun()
        ..apply(_text('an', at: t0))
        ..apply(_text('swer', at: t1));

      final assistant = projector.turnEntries.last;
      final paragraph = assistant.blocks.single as TranscriptParagraphBlock;
      expect(paragraph.stat, BlockStat(startedAt: t0, endedAt: t1));
    });

    test('summary reasoning deltas clear prefill and accumulate', () {
      final projector = _begun()
        ..apply(
          AgentSummaryReasoningDelta(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            text: 'condensing',
          ),
        );

      expect(projector.liveSummaryReasoning, 'condensing');
    });

    test('an emitted tool call arrives stamped', () {
      const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
      final stamp = DateTime.utc(2025);
      final projector = _begun()
        ..apply(
          AgentToolCallEmitted(
            timestamp: stamp,
            agent: _agent,
            entryId: _entryId,
            blockId: TranscriptBlockId.v7(),
            toolCall: call,
          ),
        );

      final assistant = projector.turnEntries.last;
      final block = assistant.blocks
          .whereType<TranscriptToolCallBlock>()
          .single;
      expect(block.stat, BlockStat(startedAt: stamp, endedAt: stamp));
    });

    test(
      'an emitted tool call projects as TurnToolCallEmitted for eager start',
      () {
        const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
        final projection = _begun().apply(
          AgentToolCallEmitted(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: _entryId,
            blockId: TranscriptBlockId.v7(),
            toolCall: call,
          ),
        );

        expect(projection, isA<TurnToolCallEmitted>());
        expect((projection as TurnToolCallEmitted).toolCall, call);
      },
    );

    test('full-transcript events replace the mirror wholesale', () {
      final projector = _begun()..apply(_text('stale'));

      final authoritative = _ts([_userTE('hello'), _userTE('rewritten')]);
      projector.apply(
        AgentUpdated(
          timestamp: DateTime.utc(2025),
          agent: _agent,
          transcript: authoritative,
        ),
      );

      expect(
        projector.turnEntries.map((e) => e.id),
        authoritative.entries.map((e) => e.id),
      );
    });

    test('an emitted tool call lands in the assistant entry', () {
      const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
      final projector = _begun()
        ..apply(_text('let me look'))
        ..apply(
          AgentToolCallEmitted(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: _entryId,
            blockId: TranscriptBlockId.v7(),
            toolCall: call,
          ),
        );

      final assistant = projector.turnEntries.last;
      expect(
        assistant.blocks.whereType<TranscriptToolCallBlock>().single.toolCall,
        call,
      );
    });

    test('needs-tool-results upserts the authoritative entry by id', () {
      const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
      final projector = _begun()..apply(_text('partial'));

      final finalized = TranscriptEntry(
        id: _entryId,
        role: Role.assistant,
        blocks: [
          TranscriptParagraphBlock(
            id: TranscriptBlockId.v7(),
            text: 'partial, finalized',
          ),
          TranscriptToolCallBlock(id: TranscriptBlockId.v7(), toolCall: call),
        ],
      );
      final projection = projector.apply(
        AgentNeedsToolResults(
          timestamp: DateTime.utc(2025),
          agent: _agent,
          entry: finalized,
          toolCalls: const [call],
        ),
      );

      expect(projection, isA<TurnNeedsTools>());
      final entries = projector.turnEntries.where((e) => e.id == _entryId);
      expect(entries, hasLength(1));
      expect(entries.single.blocks, hasLength(2));
    });

    test('needs-tool-results adds an authoritative entry not yet mirrored', () {
      const call = ToolCallDefault(id: 'tc1', name: 'search', arguments: {});
      final entry = TranscriptEntry(
        id: TranscriptEntryId.v7(),
        role: Role.assistant,
        blocks: [
          TranscriptToolCallBlock(
            id: TranscriptBlockId.v7(),
            toolCall: call,
          ),
        ],
      );
      final projector = _begun()
        ..apply(
          AgentNeedsToolResults(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entry: entry,
            toolCalls: const [call],
          ),
        );

      expect(projector.turnEntries, contains(same(entry)));
    });

    test('an applied tool result becomes its own tool entry', () {
      const result = ToolCallSucceeded(
        callId: 'tc1',
        toolName: 'search',
        content: 'found it',
      );
      final projector = _begun()
        ..apply(
          AgentToolResponseApplied(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: TranscriptEntryId.v7(),
            blockId: TranscriptBlockId.v7(),
            response: result,
          ),
        );

      final tool = projector.turnEntries.last;
      expect(tool.role, Role.tool);
      expect(tool.name, 'search');
      expect(
        tool.blocks
            .whereType<TranscriptToolCallResponseBlock>()
            .single
            .response,
        result,
      );
      expect(projector.alerts, isEmpty);
    });

    test('a re-applied tool result replaces the block in place', () {
      const first = ToolCallSucceeded(
        callId: 'tc1',
        toolName: 'search',
        content: 'draft',
      );
      const second = ToolCallSucceeded(
        callId: 'tc1',
        toolName: 'search',
        content: 'final',
      );
      final entryId = TranscriptEntryId.v7();
      final blockId = TranscriptBlockId.v7();
      final projector = _begun()
        ..apply(
          AgentToolResponseApplied(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: entryId,
            blockId: blockId,
            response: first,
          ),
        )
        ..apply(
          AgentToolResponseApplied(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: entryId,
            blockId: blockId,
            response: second,
          ),
        );

      final tools = projector.turnEntries.where((e) => e.role == Role.tool);
      expect(tools, hasLength(1));
      expect(
        tools.single.blocks
            .whereType<TranscriptToolCallResponseBlock>()
            .single
            .response
            .modelText,
        'final',
      );
    });

    test('an error tool result is stored on the block without an alert', () {
      const result = ToolCallFailed(
        callId: 'tc1',
        toolName: 'search',
        message: 'no network',
      );
      final projector = _begun()
        ..apply(
          AgentToolResponseApplied(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            entryId: TranscriptEntryId.v7(),
            blockId: TranscriptBlockId.v7(),
            response: result,
          ),
        );

      // The failure lives on the tool result block, not as a floating alert.
      expect(projector.alerts, isEmpty);
      final tool = projector.turnEntries
          .where((e) => e.role == Role.tool)
          .single;
      expect(
        tool.blocks
            .whereType<TranscriptToolCallResponseBlock>()
            .single
            .response,
        isA<ToolCallFailed>(),
      );
    });

    test('terminal events adopt the authoritative transcript', () {
      final projector = _begun()..apply(_text('partial'));

      final finalTranscript = _ts([_userTE('hello'), _userTE('final')]);
      final projection = projector.apply(
        AgentCancelled(
          timestamp: DateTime.utc(2025),
          agent: _agent,
          transcript: finalTranscript,
        ),
      );

      expect(projection, isA<TurnCancelledProjection>());
      expect(projector.active, isFalse);
      expect(
        projector.turnEntries.map((e) => e.id),
        finalTranscript.entries.map((e) => e.id),
      );
    });
  });

  group('TurnProjector activity', () {
    final at = DateTime.utc(2025);
    const call = ToolCallDefault(id: 'c', name: 'echo', arguments: {});
    final started = AgentToolCallStarted(
      timestamp: at,
      agent: _agent,
      name: 'echo',
    );
    final emitted = AgentToolCallEmitted(
      timestamp: at,
      agent: _agent,
      entryId: _entryId,
      blockId: TranscriptBlockId.v7(),
      toolCall: call,
    );
    final updated = AgentUpdated(
      timestamp: at,
      agent: _agent,
      transcript: _ts([_userTE('hi')]),
    );

    test('starts out thinking and stays there through reasoning', () {
      final projector = _begun();
      expect(projector.activity, TurnActivity.thinking);

      projector.apply(_reasoning('hmm'));
      expect(projector.activity, TurnActivity.thinking);
    });

    test('answer text means responding, but blank text does not', () {
      final projector = _begun()..apply(_text('  \n'));
      expect(projector.activity, TurnActivity.thinking);

      projector.apply(_text('hi'));
      expect(projector.activity, TurnActivity.responding);

      projector.apply(_reasoning('wait'));
      expect(projector.activity, TurnActivity.thinking);
    });

    test('a tool call is drafted until it lands, then executes', () {
      final projector = _begun()..apply(_text('let me check'));

      expect(projector.apply(started), isA<TurnProgressed>());
      expect(projector.activity, TurnActivity.draftingToolCall);

      expect(projector.apply(emitted), isA<TurnToolCallEmitted>());
      expect(projector.activity, TurnActivity.executingTools);
    });

    test('an updated transcript means the tools are done', () {
      final projector = _begun()
        ..apply(started)
        ..apply(emitted)
        ..apply(updated);

      expect(projector.activity, TurnActivity.thinking);
    });

    test('compaction holds until it completes', () {
      final projector = _begun()
        ..apply(
          AgentCompactionStarted(
            timestamp: at,
            agent: _agent,
            tokensBefore: 9,
            compactAt: 8,
            contextSize: 10,
          ),
        );
      expect(projector.activity, TurnActivity.compacting);

      projector.apply(
        AgentSummaryDelta(timestamp: at, agent: _agent, text: 'sum'),
      );
      expect(projector.activity, TurnActivity.compacting);

      projector.apply(
        AgentCompactionCompleted(
          timestamp: at,
          agent: _agent,
          outcome: const AgentCompactionFailed(reason: 'sampleFailed'),
        ),
      );
      expect(projector.activity, TurnActivity.thinking);
    });

    test('a new turn starts out thinking again', () {
      final projector = _begun()
        ..apply(started)
        ..begin(responseId: 2, base: [_userTE('x')]);

      expect(projector.activity, TurnActivity.thinking);
    });
  });

  group('TurnProjector agent binding', () {
    test('AgentStarted replaces the mirror and deltas accumulate', () {
      final projector = _begun()
        ..apply(
          AgentStarted(
            timestamp: DateTime.utc(2025),
            agent: _agent,
            transcript: _ts([_userTE('hi')]),
          ),
        )
        ..apply(_text('mine'));

      final assistant = projector.turnEntries.last;
      final paragraph = assistant.blocks.single as TranscriptParagraphBlock;
      expect(paragraph.text, 'mine');
    });

    test('events before begin are ignored', () {
      final projector = TurnProjector();
      final projection = projector.apply(_text('early'));

      expect(projection, isA<TurnProjectionIgnored>());
      expect(projector.active, isFalse);
    });
  });
}
