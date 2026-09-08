import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:test/test.dart';

class _FakeAgent implements Agent {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const handle = AgentHandle(id: 'a', kind: AgentKind.primary);
  final at = DateTime.utc(2025);
  final entryId = TranscriptEntryId.v7();
  final blockId = TranscriptBlockId.v7();
  const call = ToolCallDefault(id: 'c', name: 'tool', arguments: {});
  final transcript = Transcript(
    id: TranscriptId.v7(),
    revision: 0,
    entries: const [],
  );

  group('AgentHandle', () {
    test('compares by id and kind', () {
      const same = AgentHandle(id: 'a', kind: AgentKind.primary, label: 'x');
      const other = AgentHandle(id: 'a', kind: AgentKind.subagent);
      expect(handle, same);
      expect(handle.hashCode, same.hashCode);
      expect(handle, isNot(other));
    });
  });

  group('runtime events', () {
    test('every event carries its fields', () {
      const snapshot = ContextPoolSnapshot(
        contextSize: 10,
        reservedClaims: 0,
        leases: [
          PoolLeaseOccupancy(handle: handle, residentTokens: 1, claimTokens: 0),
        ],
      );
      final events = <RuntimeEvent>[
        PoolStateChanged(timestamp: at, snapshot: snapshot),
        AgentReasoningDelta(
          timestamp: at,
          agent: handle,
          entryId: entryId,
          blockId: blockId,
          text: 'hm',
        ),
        AgentToolCallStarted(timestamp: at, agent: handle, name: 'tool'),
        AgentToolCallEmitted(
          timestamp: at,
          agent: handle,
          entryId: entryId,
          blockId: blockId,
          toolCall: call,
        ),
        AgentNeedsToolResults(
          timestamp: at,
          agent: handle,
          entry: TranscriptEntry(
            id: entryId,
            role: Role.assistant,
            blocks: const [],
          ),
          toolCalls: const [call],
        ),
        AgentToolResponseApplied(
          timestamp: at,
          agent: handle,
          entryId: entryId,
          blockId: blockId,
          response: const ToolCallSucceeded(
            callId: 'c',
            toolName: 'tool',
            content: 'ok',
          ),
        ),
        AgentUpdated(timestamp: at, agent: handle, transcript: transcript),
        AgentCancelled(timestamp: at, agent: handle, transcript: transcript),
        AgentEnded(timestamp: at, agent: handle),
        AgentFailed(
          timestamp: at,
          agent: handle,
          reason: AgentRunFailureReason.loopFailed,
          message: 'nope',
        ),
        AgentTelemetryUpdated(
          timestamp: at,
          agent: handle,
          telemetry: const AgentTelemetry(compactAtLimit: 5),
        ),
        AgentSummaryDelta(timestamp: at, agent: handle, text: 's'),
        AgentSummaryReasoningDelta(timestamp: at, agent: handle, text: 'r'),
        AgentCompactionStarted(
          timestamp: at,
          agent: handle,
          tokensBefore: 9,
          compactAt: 8,
          contextSize: 10,
        ),
        AgentCompactionCompleted(
          timestamp: at,
          agent: handle,
          outcome: const AgentCompactionSucceeded(
            summary: 'sum',
            tokensAfter: 2,
          ),
        ),
        AgentCompactionCompleted(
          timestamp: at,
          agent: handle,
          outcome: const AgentCompactionFailed(reason: 'sampleFailed'),
        ),
      ];

      expect(events.map((event) => event.timestamp).toSet(), {at});
      expect(
        events
            .whereType<AgentRuntimeEvent>()
            .map((event) => event.agent)
            .toSet(),
        {handle},
      );
      expect(
        (events.first as PoolStateChanged).snapshot.leases.single.handle,
        handle,
      );
    });
  });

  group('results', () {
    test('rejections carry a reason and an optional message', () {
      const reason = AgentRuntimeRejectionReason.busy;
      expect(const StartSubagentRejected(reason: reason).reason, reason);
      expect(const CancelRejected(reason: reason).message, isNull);
      expect(const SubmitToolResultsRejected(reason: reason).reason, reason);
      expect(const RunRejected(reason: reason, message: 'm').message, 'm');
      expect(const DisposeAgentRejected(reason: reason).reason, reason);
      expect(const DisposeProviderFailed(message: 'gone').message, 'gone');
    });

    test('a started subagent hands back its agent', () {
      final agent = _FakeAgent();
      expect(StartSubagentStarted(agent).agent, same(agent));
    });
  });

  group('transcript models', () {
    test('a block ref pairs an entry with a block', () {
      final ref = TranscriptBlockRef(entryId: entryId, blockId: blockId);
      expect(ref.entryId, entryId);
      expect(ref.blockId, blockId);
    });

    test('the lexer mints summary blocks', () {
      const lexer = TranscriptBlockLexer();
      expect(lexer.summary('folded').text, 'folded');
    });
  });
}
