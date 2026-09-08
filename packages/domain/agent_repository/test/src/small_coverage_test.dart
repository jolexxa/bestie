import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

/// Coverage for small leaf files: pure getters and value classes that the
/// wider repository suite doesn't exercise.
void main() {
  group('TimelineItem', () {
    test('default childSelectionCount is 0', () {
      final item = MessageTimelineItem(
        id: 'u0',
        role: Role.user,
        timestamp: DateTime.utc(2025),
        blocks: const [],
      );
      expect(item.childSelectionCount, 0);
    });
  });

  test('projects idle and in-progress conversation state fields', () {
    const idle = ConversationIdle(
      timelineItems: [],
      conversationPhase: ConversationPhase.idle,
    );
    const active = TurnInProgress(
      timelineItems: [],
      conversationPhase: ConversationPhase.turnInFlight,
      activity: TurnActivity.executingTools,
      reasoningSnippet: 'thinking',
    );

    expect(idle.failure, isNull);
    expect(active.activity, TurnActivity.executingTools);
    expect(active.reasoningSnippet, 'thinking');
  });

  test('keeps subagent and turn failure summaries explicit', () {
    const subagent = SubagentSummary(
      id: 'agent',
      title: 'research',
      status: SubagentStatus.completed,
    );
    const failure = TurnFailure(
      reason: AgentRunFailureReason.loopFailed,
      message: 'offline',
    );

    expect(subagent.status, SubagentStatus.completed);
    expect(failure.summary, 'loopFailed: offline');
  });
}
