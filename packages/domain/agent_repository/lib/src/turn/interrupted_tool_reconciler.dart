import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        Role,
        TranscriptBlockId,
        TranscriptEntry,
        TranscriptEntryId,
        TranscriptToolCallBlock,
        TranscriptToolCallResponseBlock;
import 'package:tool_protocol/tool_protocol.dart' show ToolCallCanceled;

/// Returns [entries] with a synthetic canceled response appended for
/// every tool call that has no paired result.
List<TranscriptEntry> reconcileInterruptedToolCalls(
  List<TranscriptEntry> entries, {
  required TranscriptEntryId Function() nextEntryId,
  required TranscriptBlockId Function() nextBlockId,
}) {
  final resolved = <String>{
    for (final entry in entries)
      for (final block in entry.blocks)
        if (block is TranscriptToolCallResponseBlock) block.response.callId,
  };
  final unpaired = [
    for (final entry in entries)
      for (final block in entry.blocks)
        if (block is TranscriptToolCallBlock &&
            !resolved.contains(block.toolCall.id))
          block.toolCall,
  ];
  if (unpaired.isEmpty) return entries;
  return [
    ...entries,
    for (final call in unpaired)
      TranscriptEntry(
        id: nextEntryId(),
        role: Role.tool,
        name: call.name,
        blocks: [
          TranscriptToolCallResponseBlock(
            id: nextBlockId(),
            response: ToolCallCanceled(
              callId: call.id,
              toolName: call.name,
              message: 'The tool call was interrupted.',
            ),
          ),
        ],
      ),
  ];
}
