import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'agent_test_support.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockConversationStore store;
  late MockProvider provider;
  late MockAgent primary;
  late StreamController<AgentRuntimeEvent> events;
  late AgentRepository repository;

  setUp(() {
    store = MockConversationStore();
    when(() => store.save(any())).thenAnswer((_) async {});
    when(
      () => store.load(any(), agentId: any(named: 'agentId')),
    ).thenAnswer((_) async => null);
    events = StreamController<AgentRuntimeEvent>.broadcast();
    provider = MockProvider();
    primary = MockAgent();
    when(() => provider.pool).thenAnswer((_) => const Stream.empty());
    when(() => provider.spend).thenAnswer((_) => const Stream.empty());
    when(() => primary.handle).thenReturn(agentHandle);
    when(() => primary.kind).thenReturn(AgentKind.primary);
    when(() => primary.events).thenAnswer((_) => events.stream);
    when(
      () => primary.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(primary.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startPrimary(config: any(named: 'config')),
    ).thenAnswer((_) async => StartPrimaryStarted(primary));
    repository = AgentRepository(
      workingDirectory: '/work',
      configuration: testAgentConfiguration,
      toolDefinitions: offering(),
      subagentToolDefinitions: offering(),
      conversationStore: store,
      subagentSystemPromptBuilder: const FixedSubagentSystemPromptBuilder(
        'subagent prompt',
      ),
      compactionPromptContentBuilder: const FixedCompactionPromptContentBuilder(
        testCompactionPromptContent,
      ),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await events.close();
  });

  Future<SubagentRead> read({
    String id = 'call',
    String? after,
    bool wholeTranscript = false,
    int maxChars = testMaxToolCallCharacters,
  }) => repository.readSubagent(
    id: id,
    wholeTranscript: wholeTranscript,
    maxChars: maxChars,
    after: after,
  );

  SubagentReadPage pageOf(SubagentRead read) => read is SubagentReadPage
      ? read
      : fail('Expected a page, got ${read.runtimeType}.');

  void storeEntries(List<ConversationEntry> entries) {
    when(() => store.load(any(), agentId: 'call')).thenAnswer(
      (_) async => AgentSessionData(
        conversationId: repository.primary.transcript.conversationId,
        agentId: 'call',
        workingDirectory: '/work',
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2025),
        entries: entries,
      ),
    );
  }

  /// Stores an assistant answer of [texts] under `call`, and hands back the
  /// cursor of each of its blocks in order.
  List<String> storeAnswer(List<String> texts) {
    final blocks = [
      for (final text in texts)
        TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text),
    ];
    storeEntries([
      MessageEntry(
        id: 'e-answer',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: TranscriptEntry(
          id: TranscriptEntryId.v7(),
          role: Role.assistant,
          blocks: blocks,
        ),
      ),
    ]);
    return [for (final block in blocks) block.id.value.uuid];
  }

  test('reports a subagent that never ran in this conversation', () async {
    expect(await read(), isA<SubagentReadUnknown>());
  });

  test('reports a subagent that is still working', () async {
    final subagent = MockAgent();
    final subagentEvents = StreamController<AgentRuntimeEvent>.broadcast();
    addTearDown(subagentEvents.close);
    when(() => subagent.handle).thenReturn(subagentHandle);
    when(() => subagent.kind).thenReturn(AgentKind.subagent);
    when(() => subagent.events).thenAnswer((_) => subagentEvents.stream);
    when(
      () => subagent.run(
        any(),
        config: any(named: 'config'),
        goal: any(named: 'goal'),
      ),
    ).thenAnswer((_) async => const RunAccepted());
    when(subagent.cancel).thenAnswer((_) async => const CancelAccepted());
    when(
      () => provider.startSubagent(
        config: any(named: 'config'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => StartSubagentStarted(subagent));
    when(
      () => provider.disposeAgent(subagent),
    ).thenAnswer((_) async => const DisposeAgentDisposed());

    await repository.bindProvider(provider, contextSize: 1024);
    await repository.startSubagent(
      callId: 'call',
      prompt: 'Investigate',
      label: 'Subagent',
    );
    await pump();

    expect(await read(), isA<SubagentReadBusy>());
    verifyNever(() => store.load(any(), agentId: 'call'));
  });

  test('reads the stored answer once the roster has been cleared', () async {
    storeAnswer(['The answer.']);
    await repository.clearSettledSubagents();

    expect(pageOf(await read()).text, 'The answer.');
    expect(repository.subagents, isEmpty);
  });

  test('reads the conversation the primary is in', () async {
    storeAnswer(['The answer.']);

    await read();

    verify(
      () => store.load(
        repository.primary.transcript.conversationId,
        agentId: 'call',
      ),
    ).called(1);
  });

  test('names no cursor when the whole answer fits', () async {
    storeAnswer(['One paragraph.', 'And another.']);

    final page = pageOf(await read());

    expect(page.text, 'One paragraph.\n\nAnd another.');
    expect(page.next, isNull);
    expect(page.remaining, 0);
  });

  test('walks a long answer to the end without repeating a block', () async {
    final texts = ['a' * 60, 'b' * 60, 'c' * 60];
    final cursors = storeAnswer(texts);

    final pages = <SubagentReadPage>[];
    String? after;
    for (var reads = 0; reads < texts.length; reads++) {
      final page = pageOf(await read(after: after, maxChars: 100));
      pages.add(page);
      after = page.next;
    }

    expect(pages.map((page) => page.text), texts);
    expect(pages.map((page) => page.next), [cursors[0], cursors[1], null]);
    expect(pages.map((page) => page.remaining), [2, 1, 0]);
  });

  test('reports the end once a cursor has reached it', () async {
    final cursors = storeAnswer(['Only one.']);

    expect(await read(after: cursors.single), isA<SubagentReadEnd>());
  });

  test('reports a cursor that names nothing', () async {
    storeAnswer(['The answer.']);

    expect(await read(after: 'not-a-cursor'), isA<SubagentReadCursorLost>());
  });

  test('reports a block wider than the whole allowance', () async {
    storeAnswer(['x' * 400]);

    expect(
      await read(maxChars: 300),
      isA<SubagentReadBlockTooWide>().having(
        (read) => read.chars,
        'chars',
        400,
      ),
    );
  });

  test('reports the end when a subagent produced no answer', () async {
    storeEntries(const []);

    expect(await read(), isA<SubagentReadEnd>());
  });

  test('reads the working history when asked for the transcript', () async {
    storeEntries([
      MessageEntry(
        id: 'e-user',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: userTE('Investigate'),
      ),
      MessageEntry(
        id: 'e-call',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: TranscriptEntry(
          id: TranscriptEntryId.v7(),
          role: Role.assistant,
          blocks: [
            TranscriptToolCallBlock(
              id: TranscriptBlockId.v7(),
              toolCall: const ToolCallDefault(
                id: 'inner',
                name: 'read_file',
                arguments: {'path': 'main.dart'},
              ),
            ),
            TranscriptToolCallResponseBlock(
              id: TranscriptBlockId.v7(),
              response: const ToolCallSucceeded(
                callId: 'inner',
                toolName: 'read_file',
                content: 'void main() {}',
              ),
            ),
          ],
        ),
      ),
      MessageEntry(
        id: 'e-answer',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: asstTE('It is a main function.'),
      ),
    ]);

    final page = pageOf(await read(wholeTranscript: true));

    expect(page.text, contains('[user] Investigate'));
    expect(page.text, contains('[tool call] read_file'));
    expect(page.text, contains('[tool result] void main() {}'));
    expect(page.text, contains('[assistant] It is a main function.'));
  });

  test('reads only the final answer by default', () async {
    storeEntries([
      MessageEntry(
        id: 'e-user',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: userTE('Investigate'),
      ),
      MessageEntry(
        id: 'e-answer',
        timestamp: DateTime.utc(2025),
        responseId: 0,
        entry: asstTE('It is a main function.'),
      ),
    ]);

    expect(pageOf(await read()).text, 'It is a main function.');
  });
}
