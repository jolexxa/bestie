import 'package:agent_repository/agent_repository.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

AgentSessionData _data(
  String conversationId, {
  String agentId = 'primary',
  List<ConversationEntry> entries = const [],
}) => AgentSessionData(
  conversationId: conversationId,
  agentId: agentId,
  workingDirectory: '/work',
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025),
  entries: entries,
);

MessageEntry _userEntry(String text) => MessageEntry(
  id: 'msg-1',
  timestamp: DateTime.utc(2025),
  responseId: 1,
  entry: TranscriptEntry(
    id: TranscriptEntryId.v7(),
    role: Role.user,
    blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
  ),
);

void main() {
  group('ConversationStore', () {
    late FileSystem fs;
    late ConversationStore store;
    const conversationsDir = '/conversations';

    setUp(() {
      fs = MemoryFileSystem.test();
      store = ConversationStore(
        conversationsDir: conversationsDir,
        fileSystem: fs,
      );
    });

    test('save and load round-trip', () async {
      final data = _data('1000', entries: [_userEntry('hi')]);

      await store.save(data);
      final loaded = await store.load('1000', agentId: 'primary');

      expect(loaded, isNotNull);
      expect(loaded!.conversationId, '1000');
      expect(loaded.entries, hasLength(1));
      final entry = loaded.entries.single as MessageEntry;
      expect(entry.entry.role, Role.user);
    });

    test('keeps every agent of one conversation side by side', () async {
      await store.save(_data('1000', entries: [_userEntry('ask')]));
      await store.save(
        _data('1000', agentId: 'call-7', entries: [_userEntry('delegated')]),
      );

      final primary = await store.load('1000', agentId: 'primary');
      final subagent = await store.load('1000', agentId: 'call-7');

      expect(
        (primary!.entries.single as MessageEntry).entry.blocks,
        hasLength(1),
      );
      expect(primary.agentId, 'primary');
      expect(subagent!.agentId, 'call-7');
    });

    test('replaces an earlier save and leaves no scratch file', () async {
      await store.save(_data('1000', entries: [_userEntry('first')]));
      await store.save(_data('1000', entries: [_userEntry('second')]));

      final loaded = await store.load('1000', agentId: 'primary');
      expect(loaded!.entries, hasLength(1));
      expect(
        fs
            .directory('$conversationsDir/1000/primary')
            .listSync()
            .map(
              (entity) => entity.basename,
            ),
        ['session.json'],
      );
    });

    test('load returns null for missing conversation', () async {
      final result = await store.load('nonexistent', agentId: 'primary');
      expect(result, isNull);
    });

    test('load returns null for an agent that never ran', () async {
      await store.save(_data('1000'));

      expect(await store.load('1000', agentId: 'call-7'), isNull);
    });

    test(
      'summaries describe every conversation with a primary session',
      () async {
        await store.save(_data('100', entries: [_userEntry('first')]));
        await store.save(_data('100', agentId: 'call-1'));
        await store.save(_data('200', agentId: 'call-only'));
        await store.save(_data('300'));

        final summaries = await store.summaries();

        expect(
          summaries.map((summary) => summary.id),
          unorderedEquals(['100', '300']),
        );
        expect(
          summaries
              .singleWhere((summary) => summary.id == '100')
              .firstUserMessage,
          'first',
        );
      },
    );

    test('summaries skip a primary session that cannot be decoded', () async {
      await store.save(_data('100'));
      fs.file('$conversationsDir/666/primary/session.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"nope": true}');
      fs.file('$conversationsDir/777/primary/session.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('not json');

      final summaries = await store.summaries();

      expect(summaries.map((summary) => summary.id), ['100']);
    });

    test('summaries are empty when the directory does not exist', () async {
      final missingStore = ConversationStore(
        conversationsDir: '/nope',
        fileSystem: fs,
      );
      expect(await missingStore.summaries(), isEmpty);
    });

    test('delete removes every agent and their tool output', () async {
      await store.save(_data('500'));
      await store.save(_data('500', agentId: 'call-7'));
      final spill = fs.file(
        store.toolOutputPath(
          conversationId: '500',
          agentId: 'call-7',
          callId: 'call-9',
        ),
      );
      await spill.create(recursive: true);

      await store.delete('500');

      expect(await store.load('500', agentId: 'primary'), isNull);
      expect(await store.load('500', agentId: 'call-7'), isNull);
      expect(spill.existsSync(), isFalse);
    });

    test('delete is no-op for missing conversation', () async {
      // Should not throw.
      await store.delete('nonexistent');
    });

    test('tool output lands under the agent that made the call', () {
      expect(
        store.toolOutputPath(
          conversationId: '1000',
          agentId: 'call-7',
          callId: 'call-9',
        ),
        fs.path.join(conversationsDir, '1000', 'call-7', 'tools', 'call-9'),
      );
    });
  });
}
