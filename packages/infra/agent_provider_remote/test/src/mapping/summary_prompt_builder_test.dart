import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/mapping/summary_prompt_builder.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  test('renders the window with reasoning kept only on the last turn', () {
    const builder = SummaryPromptBuilder();
    final prompt = builder.build(
      entries: [
        summaryEntry('Earlier.'),
        userEntry('hi'),
        assistantEntry(
          reasoning: 'dropped',
          text: 'Calling.',
          toolCalls: const [
            ToolCallDefault(id: 'call_1', name: 'echo', arguments: {}),
          ],
        ),
        toolEntry(
          const ToolCallSucceeded(
            callId: 'call_1',
            toolName: 'echo',
            content: 'ok',
          ),
        ),
        systemNoteEntry('Note.', toolOutput: ' Output.'),
        assistantEntry(reasoning: 'kept ', text: 'Done.'),
      ],
      content: compactionContent,
    );

    expect(
      prompt,
      '<conversation>\n'
      'system: Earlier.\n'
      'user: hi\n'
      'assistant: Calling.<tool_call name="echo" id="call_1" />\n'
      'tool: <tool_response name="echo" call_id="call_1">ok</tool_response>\n'
      'system: Note. Output.\n'
      'assistant: kept Done.\n'
      '</conversation>\n'
      '\n'
      'Use bullets.\n'
      'Begin your reply with "Summary:" and nothing before it.',
    );
  });
}
