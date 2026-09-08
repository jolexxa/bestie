import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TranscriptEntry', () {
    test('exposes typed block views', () {
      final reasoning = TranscriptReasoningBlock(
        id: _blockId('0192f6e4-0000-7000-8000-000000000401'),
        text: 'plan',
      );
      final toolCall = TranscriptToolCallBlock(
        id: _blockId('0192f6e4-0000-7000-8000-000000000402'),
        toolCall: const ToolCallDefault(
          id: 'call-1',
          name: 'search',
          arguments: {},
        ),
      );
      final toolResponse = TranscriptToolCallResponseBlock(
        id: _blockId('0192f6e4-0000-7000-8000-000000000403'),
        response: const ToolCallSucceeded(
          callId: 'call-1',
          toolName: 'search',
          content: 'result',
        ),
      );
      final entry = TranscriptEntry(
        id: TranscriptEntryId(
          UuidValue.raw('0192f6e4-0000-7000-8000-000000000501'),
        ),
        role: Role.assistant,
        blocks: [
          TranscriptParagraphBlock(
            id: _blockId('0192f6e4-0000-7000-8000-000000000404'),
            text: 'text',
          ),
          reasoning,
          toolCall,
          toolResponse,
        ],
      );

      expect(entry.reasoningBlocks, [reasoning]);
      expect(entry.toolCallBlocks, [toolCall]);
      expect(entry.toolResponseBlocks, [toolResponse]);
    });
  });
}

TranscriptBlockId _blockId(String value) {
  return TranscriptBlockId(UuidValue.raw(value));
}
