import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Transcript id hooks', () {
    test('decode uuid strings into typed ids', () {
      const transcriptId = '0192f6e4-0000-7000-8000-000000000601';
      const entryId = '0192f6e4-0000-7000-8000-000000000602';
      const blockId = '0192f6e4-0000-7000-8000-000000000603';

      expect(
        (const TranscriptIdHook().beforeDecode(transcriptId) as TranscriptId)
            .value
            .uuid,
        transcriptId,
      );
      expect(
        (const TranscriptEntryIdHook().beforeDecode(entryId)
                as TranscriptEntryId)
            .value
            .uuid,
        entryId,
      );
      expect(
        (const TranscriptBlockIdHook().beforeDecode(blockId)
                as TranscriptBlockId)
            .value
            .uuid,
        blockId,
      );
      expect(const TranscriptIdHook().beforeDecode(7), 7);
    });

    test('encode typed ids into uuid strings', () {
      const transcriptId = '0192f6e4-0000-7000-8000-000000000611';
      const entryId = '0192f6e4-0000-7000-8000-000000000612';
      const blockId = '0192f6e4-0000-7000-8000-000000000613';

      expect(
        const TranscriptIdHook().beforeEncode(
          TranscriptId(UuidValue.raw(transcriptId)),
        ),
        transcriptId,
      );
      expect(
        const TranscriptEntryIdHook().beforeEncode(
          TranscriptEntryId(UuidValue.raw(entryId)),
        ),
        entryId,
      );
      expect(
        const TranscriptBlockIdHook().beforeEncode(
          TranscriptBlockId(UuidValue.raw(blockId)),
        ),
        blockId,
      );
      expect(const TranscriptIdHook().beforeEncode(7), 7);
    });
  });
}
