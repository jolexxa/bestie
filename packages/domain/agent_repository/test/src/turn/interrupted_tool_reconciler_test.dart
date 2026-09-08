import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/turn/interrupted_tool_reconciler.dart';
import 'package:test/test.dart';

TranscriptEntry _call(String id, {String name = 'search'}) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.assistant,
  blocks: [
    TranscriptToolCallBlock(
      id: TranscriptBlockId.v7(),
      toolCall: ToolCallDefault(id: id, name: name, arguments: const {}),
    ),
  ],
);

TranscriptEntry _response(ToolCallResponse response) => TranscriptEntry(
  id: TranscriptEntryId.v7(),
  role: Role.tool,
  name: response.toolName,
  blocks: [
    TranscriptToolCallResponseBlock(
      id: TranscriptBlockId.v7(),
      response: response,
    ),
  ],
);

List<ToolCallResponse> _responses(List<TranscriptEntry> entries) => [
  for (final entry in entries)
    for (final block in entry.blocks)
      if (block is TranscriptToolCallResponseBlock) block.response,
];

void main() {
  List<TranscriptEntry> reconcile(List<TranscriptEntry> entries) =>
      reconcileInterruptedToolCalls(
        entries,
        nextEntryId: TranscriptEntryId.v7,
        nextBlockId: TranscriptBlockId.v7,
      );

  test('pairs an unanswered call with a canceled response', () {
    final response = _responses(reconcile([_call('call')])).single;

    expect(response, isA<ToolCallCanceled>());
    expect(response.callId, 'call');
    expect(response.toolName, 'search');
  });

  test('leaves an already answered call unchanged', () {
    final entries = [
      _call('call'),
      _response(
        const ToolCallSucceeded(
          callId: 'call',
          toolName: 'search',
          content: 'ok',
        ),
      ),
    ];

    expect(reconcile(entries), same(entries));
  });

  test('only synthesizes responses for unpaired calls', () {
    final responses = _responses(
      reconcile([
        _call('one'),
        _call('two'),
        _response(
          const ToolCallSucceeded(
            callId: 'one',
            toolName: 'search',
            content: 'ok',
          ),
        ),
      ]),
    );

    expect({for (final response in responses) response.callId}, {'one', 'two'});
    expect(
      responses.singleWhere((response) => response.callId == 'two'),
      isA<ToolCallCanceled>(),
    );
  });
}
