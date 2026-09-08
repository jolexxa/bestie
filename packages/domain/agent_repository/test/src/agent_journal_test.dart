import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:agent_repository/src/conversation/agent_journal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockConversationStore extends Mock implements ConversationStore {}

late _MockConversationStore _store;

AgentJournal _journal({String? conversationId}) => AgentJournal.fresh(
  agentId: 'primary',
  workingDirectory: '/work',
  store: _store,
  conversationId: conversationId,
);

final _time = DateTime.utc(2025);

MessageEntry _message(Role role, String text) => MessageEntry(
  id: 'entry-$text',
  timestamp: _time,
  responseId: 1,
  entry: TranscriptEntry(
    id: TranscriptEntryId.v7(),
    role: role,
    blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
  ),
);

void main() {
  setUpAll(
    () => registerFallbackValue(
      AgentSessionData(
        conversationId: 'c',
        agentId: 'primary',
        workingDirectory: '/work',
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2025),
        entries: const [],
      ),
    ),
  );

  setUp(() {
    _store = _MockConversationStore();
    when(() => _store.save(any())).thenAnswer((_) async {});
  });

  test(
    'creates empty and folds user and assistant messages into transcript rows',
    () {
      final transcript = _journal()
        ..append(_message(Role.user, 'hello'))
        ..append(_message(Role.assistant, 'hi'));

      expect(transcript.transcript.entries.map((entry) => entry.role), [
        Role.user,
        Role.assistant,
      ]);
      expect(
        transcript.timeline.whereType<MessageTimelineItem>().map(
          (item) => item.text,
        ),
        ['hello', 'hi'],
      );
    },
  );

  group('userMessageText', () {
    late AgentJournal transcript;

    setUp(() {
      transcript = _journal()
        ..append(_message(Role.user, 'hello'))
        ..append(_message(Role.assistant, 'hi'));
    });

    test('returns the text of a user message', () {
      expect(transcript.userMessageText('entry-hello'), 'hello');
    });

    test('is null for an assistant message', () {
      expect(transcript.userMessageText('entry-hi'), isNull);
    });

    test('is null for an unknown id', () {
      expect(transcript.userMessageText('nope'), isNull);
    });
  });

  group('truncateBefore', () {
    late AgentJournal transcript;

    setUp(() {
      transcript = _journal(conversationId: 'c-1')
        ..append(NoticeEntry(id: 'notice', timestamp: _time, text: 'hey'))
        ..append(_message(Role.user, 'first'))
        ..append(_message(Role.assistant, 'reply'))
        ..append(_message(Role.user, 'second'));
    });

    test('keeps the entries before the id and the same identity', () {
      expect(transcript.truncateBefore('entry-second'), isTrue);

      expect(transcript.conversationId, 'c-1');
      expect(transcript.agentId, 'primary');
      expect(transcript.workingDirectory, '/work');
      expect(transcript.entries.map((entry) => entry.id), [
        'notice',
        'entry-first',
        'entry-reply',
      ]);
    });

    test('empties the history when cutting before the first entry', () {
      expect(transcript.truncateBefore('notice'), isTrue);

      expect(transcript.isEmpty, isTrue);
    });

    test('leaves the history alone for an unknown id', () {
      expect(transcript.truncateBefore('nope'), isFalse);

      expect(transcript.entries, hasLength(4));
    });

    test('schedules a write for what is left', () async {
      transcript.truncateBefore('entry-second');
      await transcript.flush();

      final saved =
          verify(() => _store.save(captureAny())).captured.last
              as AgentSessionData;
      expect(saved.entries, hasLength(3));
    });
  });

  group('recordModelChange', () {
    ModelChangeEntry card(String id) => ModelChangeEntry(
      id: id,
      timestamp: _time,
      modelId: id,
      displayName: id,
      contextSize: 1,
      provider: 'p',
    );

    test('replaces a card already at the tail', () {
      final transcript = _journal()
        ..recordModelChange(card('first'))
        ..recordModelChange(card('second'));

      expect(transcript.entries.map((entry) => entry.id), ['second']);
    });

    test('keeps a card that follows anything else', () {
      final transcript = _journal()
        ..recordModelChange(card('first'))
        ..append(NoticeEntry(id: 'notice', timestamp: _time, text: 'hey'))
        ..recordModelChange(card('second'));

      expect(transcript.entries.map((entry) => entry.id), [
        'first',
        'notice',
        'second',
      ]);
    });
  });

  test('keeps UI-only entries out of the prompt transcript', () {
    // The backgrounded-job row belongs here: the model was already told the
    // command is still going, in the call's own response.
    final transcript = _journal()
      ..append(NoticeEntry(id: 'notice', timestamp: _time, text: 'welcome'))
      ..append(
        ModelChangeEntry(
          id: 'model',
          timestamp: _time,
          modelId: 'm',
          displayName: 'M',
          contextSize: 1,
          provider: 'p',
        ),
      )
      ..append(
        JobBackgroundedEntry(
          id: 'job',
          timestamp: _time,
          job: const JobInBackground(callId: 'call-1', toolName: 'bash'),
        ),
      );

    expect(transcript.transcript.entries, isEmpty);
    expect(transcript.timeline, hasLength(3));
  });

  test('folds delivered job reports into automated user context', () {
    final transcript = _journal()
      ..append(
        JobReportEntry(
          id: 'report',
          timestamp: _time,
          responseId: 2,
          reports: const [
            DeliveredJobReport(
              callId: 'call',
              toolName: 'shell',
              succeeded: true,
              body: 'done',
              outstanding: 1,
            ),
          ],
        ),
      );

    final entry = transcript.transcript.entries.single;
    expect(entry.role, Role.user);
    final text = (entry.blocks.single as TranscriptParagraphBlock).text;
    expect(text, contains('<job id="call"'));
    expect(text, contains('<pending>1 job still pending'));
  });

  test('memoizes a system summary checkpoint in the prompt transcript', () {
    final transcript = _journal()
      ..append(
        CompactionEntry(
          id: 'summary',
          timestamp: _time,
          tokensBefore: 10,
          summary: 'remember this',
        ),
      );

    final first = transcript.transcript.entries.single;
    final second = transcript.transcript.entries.single;
    expect(first.role, Role.system);
    expect(first, same(second));
    expect(first.blocks.single.toString(), contains('remember this'));
  });

  group('hasFoldableHistory', () {
    test('is false with nothing committed', () {
      expect(
        _journal().hasFoldableHistory,
        isFalse,
      );
    });

    test('ignores UI-only entries', () {
      final transcript = _journal()
        ..append(NoticeEntry(id: 'notice', timestamp: _time, text: 'welcome'));

      expect(transcript.hasFoldableHistory, isFalse);
    });

    test('is true once a message follows the latest compaction', () {
      final transcript = _journal()
        ..append(_message(Role.user, 'hello'))
        ..append(
          CompactionEntry(
            id: 'fold',
            timestamp: _time,
            summary: 'Said hello.',
            tokensBefore: 10,
          ),
        );
      expect(transcript.hasFoldableHistory, isFalse);

      transcript.append(_message(Role.user, 'more'));
      expect(transcript.hasFoldableHistory, isTrue);
    });
  });

  group('writing', () {
    test('collapses a burst of appends into one save', () async {
      final journal = _journal()
        ..append(_message(Role.user, 'one'))
        ..append(_message(Role.assistant, 'two'))
        ..append(_message(Role.user, 'three'));

      await journal.flush();

      final saved =
          verify(() => _store.save(captureAny())).captured.single
              as AgentSessionData;
      expect(saved.entries, hasLength(3));
    });

    test('never writes an empty history', () async {
      await _journal().flush();

      verifyNever(() => _store.save(any()));
    });

    test('a save behind another carries the newest history', () async {
      final firstWrite = Completer<void>();
      var calls = 0;
      when(() => _store.save(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) await firstWrite.future;
      });

      final journal = _journal()..append(_message(Role.user, 'one'));
      await pumpEventQueue();
      // The first save is in flight; these two land behind it as one write.
      journal
        ..append(_message(Role.assistant, 'two'))
        ..append(_message(Role.user, 'three'));
      firstWrite.complete();
      await journal.flush();

      final saved = verify(
        () => _store.save(captureAny()),
      ).captured.cast<AgentSessionData>();
      expect(saved, hasLength(2));
      expect(saved.last.entries, hasLength(3));
    });

    test('flush waits for the write in flight', () async {
      final write = Completer<void>();
      var landed = false;
      when(() => _store.save(any())).thenAnswer((_) async {
        await write.future;
        landed = true;
      });

      final journal = _journal()..append(_message(Role.user, 'one'));
      final flushed = journal.flush().then((_) => expect(landed, isTrue));
      write.complete();
      await flushed;
    });

    test('keeps writing after a save fails', () async {
      var calls = 0;
      when(() => _store.save(any())).thenAnswer((_) async {
        if (++calls == 1) throw StateError('disk full');
      });

      final journal = _journal()..append(_message(Role.user, 'one'));
      await journal.flush();

      journal.append(_message(Role.assistant, 'two'));
      await journal.flush();

      expect(calls, 2);
    });
  });
}
