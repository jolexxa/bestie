import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show
        TranscriptEntry,
        TranscriptToolCallBlock,
        TranscriptToolCallResponseBlock;
import 'package:tool_protocol/tool_protocol.dart'
    show
        ToolCall,
        ToolCallCanceled,
        ToolCallFailed,
        ToolCallResponse,
        ToolCallSucceeded,
        ToolDefinition;

/// Returns [entries] with each tool-call block stamped with its
/// state-appropriate activity-stub label template, resolved from the tool
/// definition via [definitionFor].
///
/// Stamping denormalizes the UI label onto the transcript, so a resumed
/// session renders the same label even if the originating tool later changes
/// or is removed.
List<TranscriptEntry> labelTurnEntries(
  List<TranscriptEntry> entries,
  ToolDefinition? Function(String name) definitionFor,
) {
  final results = <String, ToolCallResponse>{
    for (final te in entries)
      for (final b in te.blocks)
        if (b is TranscriptToolCallResponseBlock) b.response.callId: b.response,
  };
  return [
    for (final te in entries)
      te.copyWith(
        blocks: [
          for (final b in te.blocks)
            if (b is TranscriptToolCallBlock)
              b.copyWith(
                labelTemplate: _templateFor(
                  b.toolCall,
                  results[b.toolCall.id],
                  definitionFor,
                ),
              )
            else
              b,
        ],
      ),
  ];
}

String? _templateFor(
  ToolCall call,
  ToolCallResponse? result,
  ToolDefinition? Function(String name) definitionFor,
) {
  final def = definitionFor(call.name);
  if (def == null) return null;
  final template = switch (result) {
    ToolCallSucceeded() => def.onSuccess,
    ToolCallFailed() || ToolCallCanceled() => def.onError,
    null => def.onProgress,
  };
  return template.isEmpty ? null : template;
}
