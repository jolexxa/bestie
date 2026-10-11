import 'package:agent_runtime/src/mapping/transcript_message_mapper.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  const mapper = TranscriptMessageMapper();

  List<CompletionMessage> map(
    List<TranscriptEntry> entries, {
    String systemPrompt = 'Be brief.',
    int from = 0,
  }) => mapper.map(
    transcript: transcriptOf(entries),
    systemPrompt: systemPrompt,
    from: from,
  );

  test('folds system entries into the system prompt', () {
    final messages = map([
      systemNoteEntry('Note.', toolOutput: ' Output.'),
      userEntry('hi'),
    ]);

    expect(messages, hasLength(2));
    expect(
      (messages[0] as CompletionSystemMessage).text,
      'Be brief.\n\nNote. Output.',
    );
    expect((messages[1] as CompletionUserMessage).text, 'hi');
  });

  test('uses system entry text alone when there is no system prompt', () {
    final messages = map([systemNoteEntry('Note.')], systemPrompt: '');

    expect((messages.single as CompletionSystemMessage).text, 'Note.');
  });

  test('omits the system message when nothing fills it', () {
    final messages = map([userEntry('hi')], systemPrompt: '');

    expect(messages.single, isA<CompletionUserMessage>());
  });

  test('frames a summary checkpoint as a user message', () {
    final messages = map([
      summaryEntry('We talked.'),
      summaryEntry(''),
      userEntry('next'),
    ]);

    expect(messages, hasLength(3));
    expect(
      (messages[1] as CompletionUserMessage).text,
      'The conversation history before this point was compacted into the '
      'following summary:\n\n<summary>\nWe talked.\n</summary>',
    );
    expect((messages[2] as CompletionUserMessage).text, 'next');
  });

  test('maps assistant entries with reasoning and tool calls', () {
    final messages = map([
      assistantEntry(
        text: 'Calling.',
        reasoning: 'Hmm.',
        toolCalls: const [
          ToolCallDefault(
            id: 'call_1',
            name: 'echo',
            arguments: {'text': 'hi'},
          ),
        ],
      ),
      assistantEntry(text: 'Plain.'),
    ]);

    final withTools = messages[1] as CompletionAssistantMessage;
    expect(withTools.text, 'Calling.');
    expect(withTools.reasoning, 'Hmm.');
    expect(withTools.toolCalls, const [
      CompletionToolCall(
        id: 'call_1',
        name: 'echo',
        arguments: {'text': 'hi'},
        rawArguments: '{"text":"hi"}',
      ),
    ]);
    final plain = messages[2] as CompletionAssistantMessage;
    expect(plain.reasoning, isNull);
    expect(plain.toolCalls, isEmpty);
  });

  test('maps tool entries from their response', () {
    final messages = map([
      toolEntry(
        const ToolCallSucceeded(callId: 'a', toolName: 'echo', content: 'ok'),
      ),
      toolEntry(
        const ToolCallFailed(callId: 'b', toolName: 'echo', message: 'boom'),
      ),
      toolEntry(
        const ToolCallCanceled(callId: 'c', toolName: 'echo', message: 'bye'),
      ),
      TranscriptEntry(
        id: TranscriptEntryId.v7(),
        role: Role.tool,
        blocks: const [],
      ),
    ]);

    expect(
      messages.skip(1),
      const [
        CompletionToolResultMessage(
          toolCallId: 'a',
          name: 'echo',
          content: 'ok',
        ),
        CompletionToolResultMessage(
          toolCallId: 'b',
          name: 'echo',
          content: 'boom',
          isError: true,
        ),
        CompletionToolResultMessage(
          toolCallId: 'c',
          name: 'echo',
          content: 'bye',
          isError: true,
        ),
        CompletionToolResultMessage(
          toolCallId: '',
          name: '',
          content: 'Tool response was unavailable.',
          isError: true,
        ),
      ].map(_matchesToolResult),
    );
  });

  test('starts at the requested entry', () {
    final messages = map([
      userEntry('old'),
      assistantEntry(text: 'older'),
      userEntry('new'),
    ], from: 2);

    expect(messages, hasLength(2));
    expect((messages[1] as CompletionUserMessage).text, 'new');
  });
}

Matcher _matchesToolResult(CompletionToolResultMessage expected) =>
    isA<CompletionToolResultMessage>()
        .having(
          (message) => message.toolCallId,
          'toolCallId',
          expected.toolCallId,
        )
        .having((message) => message.name, 'name', expected.name)
        .having((message) => message.content, 'content', expected.content)
        .having((message) => message.isError, 'isError', expected.isError);
