import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Transcript', () {
    test('an empty transcript has no checkpoint and nothing to fold', () {
      final transcript = _transcriptOf([]);

      expect(transcript.lastCheckpoint, 0);
      expect(transcript.priorSummary, isNull);
      expect(transcript.hasFoldableEntries, isFalse);
    });

    test('entries without a checkpoint are foldable from the start', () {
      final transcript = _transcriptOf([_userEntry('hi')]);

      expect(transcript.lastCheckpoint, 0);
      expect(transcript.priorSummary, isNull);
      expect(transcript.hasFoldableEntries, isTrue);
    });

    test('the latest checkpoint wins and carries the prior summary', () {
      final transcript = _transcriptOf([
        _userEntry('old'),
        _summaryEntry('First.'),
        _userEntry('mid'),
        _summaryEntry('Second.'),
      ]);

      expect(transcript.lastCheckpoint, 3);
      expect(transcript.priorSummary, 'Second.');
      expect(transcript.hasFoldableEntries, isFalse);
    });

    test('entries after the latest checkpoint are foldable', () {
      final transcript = _transcriptOf([
        _userEntry('old'),
        _summaryEntry('Earlier.'),
        _userEntry('new'),
      ]);

      expect(transcript.lastCheckpoint, 1);
      expect(transcript.priorSummary, 'Earlier.');
      expect(transcript.hasFoldableEntries, isTrue);
    });
  });
}

Transcript _transcriptOf(List<TranscriptEntry> entries) => Transcript(
  id: TranscriptId.v7(),
  revision: entries.length,
  entries: entries,
);

TranscriptEntry _userEntry(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.user,
  blocks: [TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text)],
);

TranscriptEntry _summaryEntry(String text) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.system,
  blocks: [TranscriptSummaryBlock(id: TranscriptBlockId.v7(), text: text)],
);
