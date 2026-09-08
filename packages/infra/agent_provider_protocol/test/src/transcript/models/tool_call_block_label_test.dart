import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_block.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

TranscriptBlockId _id(String suffix) => TranscriptBlockId(
  UuidValue.raw('0192f6e4-0000-7000-8000-0000000007$suffix'),
);

void main() {
  group('TranscriptToolCallBlock.labelTemplate', () {
    test('round-trips the denormalized template', () {
      final block = TranscriptToolCallBlock(
        id: _id('01'),
        toolCall: const ToolCallDefault(
          id: 'tc1',
          name: 'read_file',
          arguments: {'path': '/a/notes.txt'},
        ),
        labelTemplate: r'Read ${path:basename}',
      );

      final decoded = TranscriptBlockMapper.fromJson(block.toJson());

      expect(decoded, block);
      expect(
        (decoded as TranscriptToolCallBlock).labelTemplate,
        r'Read ${path:basename}',
      );
    });

    test('reads legacy blocks persisted without a template', () {
      final block = TranscriptToolCallBlock(
        id: _id('02'),
        toolCall: const ToolCallDefault(
          id: 'tc1',
          name: 'read_file',
          arguments: {},
        ),
      );

      final decoded =
          TranscriptBlockMapper.fromJson(block.toJson())
              as TranscriptToolCallBlock;

      expect(decoded.labelTemplate, isNull);
    });
  });
}
