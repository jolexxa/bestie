import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_block.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('BlockStat', () {
    final t0 = DateTime.utc(2025);
    final t1 = t0.add(const Duration(milliseconds: 500));

    test('derives elapsedMs and tokensPerSecond', () {
      final stat = BlockStat(startedAt: t0, endedAt: t1, tokenCount: 25);

      expect(stat.elapsedMs, 500);
      expect(stat.tokensPerSecond, 50);
    });

    test('tokensPerSecond is null without tokens or elapsed time', () {
      expect(BlockStat(startedAt: t0, endedAt: t1).tokensPerSecond, isNull);
      expect(
        BlockStat(startedAt: t0, endedAt: t0, tokenCount: 5).tokensPerSecond,
        isNull,
      );
    });

    test('round-trips on a transcript block', () {
      final block = TranscriptParagraphBlock(
        id: TranscriptBlockId(
          UuidValue.raw('0192f6e4-0000-7000-8000-000000000601'),
        ),
        text: 'hello',
        stat: BlockStat(startedAt: t0, endedAt: t1, tokenCount: 3),
      );

      final decoded = TranscriptBlockMapper.fromJson(block.toJson());

      expect(decoded, block);
    });

    test('reads blocks persisted without a stat', () {
      final block = TranscriptParagraphBlock(
        id: TranscriptBlockId(
          UuidValue.raw('0192f6e4-0000-7000-8000-000000000602'),
        ),
        text: 'hello',
      );

      final json = block.toJson();
      final decoded = TranscriptBlockMapper.fromJson(json);

      expect(decoded.stat, isNull);
    });
  });
}
