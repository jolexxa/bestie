import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/src/conversation_picker.dart';
import 'package:test/test.dart';

ConversationSummary _summary(
  String id, {
  String workingDirectory = '/home/j/proj',
  String firstUserMessage = 'hello',
  String searchText = 'hello',
  DateTime? updatedAt,
}) => ConversationSummary(
  id: id,
  workingDirectory: workingDirectory,
  createdAt: DateTime.utc(2026),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 5, 14, 12),
  firstUserMessage: firstUserMessage,
  searchText: searchText,
);

ConversationPicker _picker(
  List<ConversationSummary> summaries, {
  String currentConversationId = 'current',
}) => ConversationPicker(
  summaries: Future.value(summaries),
  homeDirectory: '/home/j',
  currentConversationId: currentConversationId,
);

void main() {
  group('ConversationPicker', () {
    test('lists newest first, without the current or empty ones', () async {
      final options = await _picker([
        _summary('old', updatedAt: DateTime.utc(2026)),
        _summary('current'),
        _summary('silent', firstUserMessage: '', searchText: ''),
        _summary('new', updatedAt: DateTime.utc(2026, 8)),
      ]).search('').first;

      expect(options.map((option) => option.value), ['new', 'old']);
    });

    test('labels a row with its shortened directory and local time', () async {
      final when = DateTime(2026, 9, 5, 14, 7);
      final options = await _picker([
        _summary('a', updatedAt: when),
        _summary('b', workingDirectory: '/home/j', updatedAt: when),
        _summary('c', workingDirectory: '/opt/x', updatedAt: when),
        _summary('d', workingDirectory: '/home/jane', updatedAt: when),
      ]).search('').first;

      expect(options.map((option) => option.label), [
        '~/proj · 2026-09-05 14:07',
        '~ · 2026-09-05 14:07',
        '/opt/x · 2026-09-05 14:07',
        '/home/jane · 2026-09-05 14:07',
      ]);
    });

    test('details a row with the first user message on one line', () async {
      final long = List.filled(30, 'word').join(' ');
      final options = await _picker([
        _summary('a', firstUserMessage: '  fix\n\tthe   bug  '),
        _summary('b', firstUserMessage: long),
      ]).search('').first;

      expect(options[0].detail, 'fix the bug');
      expect(options[1].detail, hasLength(ConversationPicker.snippetLength));
      expect(options[1].detail, endsWith('…'));
    });

    test('every term must appear in the row or the prose', () async {
      final picker = _picker([
        _summary(
          'a',
          workingDirectory: '/home/j/godot',
          firstUserMessage: 'Port the thing',
          searchText: 'port the thing\nsure, the widget is ported',
        ),
        _summary(
          'b',
          workingDirectory: '/home/j/other',
          firstUserMessage: 'Unrelated',
          searchText: 'unrelated\nfine',
        ),
      ]);

      Future<List<String>> ids(String query) async =>
          (await picker.search(query).first)
              .map((option) => option.value)
              .toList();

      expect(await ids('WIDGET'), ['a']);
      expect(await ids('godot widget'), ['a']);
      expect(await ids('godot fine'), isEmpty);
      expect(await ids('2026-09'), ['a', 'b']);
      expect(await ids('  '), ['a', 'b']);
    });
  });
}
