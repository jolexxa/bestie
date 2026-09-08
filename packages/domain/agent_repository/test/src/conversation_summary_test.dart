import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

import 'agent/agent_test_support.dart';

void main() {
  group('ConversationSummary.fromSessionData', () {
    test('carries the conversation facts through', () {
      final summary = ConversationSummary.fromSessionData(
        data([msgUser('hi')], id: 'c-3'),
      );

      expect(summary.id, 'c-3');
      expect(summary.workingDirectory, '/elsewhere');
      expect(summary.createdAt, DateTime.utc(2025));
      expect(summary.updatedAt, DateTime.utc(2025));
    });

    test('names the first thing the user said', () {
      final summary = ConversationSummary.fromSessionData(
        data([
          msgAsst('welcome'),
          msgUser('  first question  '),
          msgUser('second question'),
        ]),
      );

      expect(summary.firstUserMessage, 'first question');
      expect(summary.hasUserMessage, isTrue);
    });

    test('has no user message when the user never spoke', () {
      final summary = ConversationSummary.fromSessionData(
        data([msgAsst('hello?')]),
      );

      expect(summary.firstUserMessage, isEmpty);
      expect(summary.hasUserMessage, isFalse);
    });

    test('search text is the lowercased prose plus compaction summaries', () {
      final summary = ConversationSummary.fromSessionData(
        AgentSessionData(
          conversationId: 'c-1',
          agentId: primaryAgentSessionId,
          workingDirectory: '/work',
          createdAt: DateTime.utc(2025),
          updatedAt: DateTime.utc(2025),
          entries: [
            NoticeEntry(
              id: 'n',
              timestamp: DateTime.utc(2025),
              text: 'Model ready',
            ),
            msgUser('Fix the Widget'),
            msgAsst('Done, the WIDGET is fixed'),
            CompactionEntry(
              id: 'c',
              timestamp: DateTime.utc(2025),
              summary: 'Earlier: Refactored parsing',
              tokensBefore: 10,
            ),
          ],
        ),
      );

      expect(
        summary.searchText,
        'fix the widget\n'
        'done, the widget is fixed\n'
        'earlier: refactored parsing',
      );
    });

    test('skips the rows that are only ever shown, jobs included', () {
      final summary = ConversationSummary.fromSessionData(
        AgentSessionData(
          conversationId: 'c-1',
          agentId: primaryAgentSessionId,
          workingDirectory: '/work',
          createdAt: DateTime.utc(2025),
          updatedAt: DateTime.utc(2025),
          entries: [
            JobReportEntry(
              id: 'r',
              timestamp: DateTime.utc(2025),
              responseId: 1,
              reports: const [],
            ),
            JobBackgroundedEntry(
              id: 'b',
              timestamp: DateTime.utc(2025),
              job: const JobInBackground(callId: 'call', toolName: 'shell'),
            ),
            msgUser('Only this counts'),
          ],
        ),
      );

      expect(summary.firstUserMessage, 'Only this counts');
      expect(summary.searchText, 'only this counts');
    });
  });
}
