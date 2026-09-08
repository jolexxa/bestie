import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/turn/tool_label_denormalizer.dart';
import 'package:test/test.dart';

const _definition = ToolDefinition(
  name: 'read_file',
  description: 'Reads.',
  parameters: {},
  onProgress: 'Reading',
  onSuccess: 'Read',
  onError: 'Failed',
);

TranscriptEntry _entry(List<TranscriptBlock> blocks) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.assistant,
  blocks: blocks,
);

TranscriptToolCallBlock _call() => TranscriptToolCallBlock(
  id: TranscriptBlockId.v7(),
  toolCall: const ToolCallDefault(
    id: 'call',
    name: 'read_file',
    arguments: {},
  ),
);

TranscriptEntry _response(ToolCallResponse response) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.tool,
  blocks: [
    TranscriptToolCallResponseBlock(
      id: TranscriptBlockId.v7(),
      response: response,
    ),
  ],
);

String? _label(List<TranscriptEntry> entries) => labelTurnEntries(
  entries,
  (name) => name == _definition.name ? _definition : null,
).first.blocks.whereType<TranscriptToolCallBlock>().single.labelTemplate;

void main() {
  test(
    'uses progress before a response, success after success, '
    'and error after failure',
    () {
      expect(
        _label([
          _entry([_call()]),
        ]),
        'Reading',
      );
      expect(
        _label([
          _entry([_call()]),
          _response(
            const ToolCallSucceeded(
              callId: 'call',
              toolName: 'read_file',
              content: 'ok',
            ),
          ),
        ]),
        'Read',
      );
      expect(
        _label([
          _entry([_call()]),
          _response(
            const ToolCallFailed(
              callId: 'call',
              toolName: 'read_file',
              message: 'no',
            ),
          ),
        ]),
        'Failed',
      );
    },
  );

  test('uses error for cancellation and matches responses by call id', () {
    expect(
      _label([
        _entry([_call()]),
        _response(
          const ToolCallCanceled(
            callId: 'call',
            toolName: 'read_file',
            message: 'stop',
          ),
        ),
      ]),
      'Failed',
    );
    expect(
      _label([
        _entry([_call()]),
        _response(
          const ToolCallSucceeded(
            callId: 'other',
            toolName: 'read_file',
            content: 'ok',
          ),
        ),
      ]),
      'Reading',
    );
  });
}
