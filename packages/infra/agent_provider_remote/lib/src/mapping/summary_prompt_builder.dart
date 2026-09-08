import 'package:agent_provider_protocol/agent_provider_protocol.dart';

/// Renders the transcript window as the material the summarizer folds.
final class SummaryPromptBuilder {
  const SummaryPromptBuilder();

  String build({
    required List<TranscriptEntry> entries,
    required CompactionPromptContent content,
  }) {
    final buffer = StringBuffer()..writeln('<conversation>');
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final isLatestTurn = index == entries.length - 1;
      buffer.writeln(
        '${entry.role.name}: '
        '${_entryText(entry, keepReasoning: isLatestTurn)}',
      );
    }
    buffer
      ..writeln('</conversation>')
      ..writeln()
      ..write(content.format);
    final opening = content.prefill.trim();
    if (opening.isNotEmpty) {
      buffer
        ..writeln()
        ..write('Begin your reply with "$opening" and nothing before it.');
    }
    return buffer.toString();
  }

  static String _entryText(
    TranscriptEntry entry, {
    required bool keepReasoning,
  }) => entry.blocks
      .map((block) => _blockText(block, keepReasoning: keepReasoning))
      .where((text) => text.isNotEmpty)
      .join();

  static String _blockText(
    TranscriptBlock block, {
    required bool keepReasoning,
  }) => switch (block) {
    TranscriptParagraphBlock(:final text) => text,
    TranscriptToolOutputBlock(:final text) => text,
    TranscriptReasoningBlock(:final text) => keepReasoning ? text : '',
    TranscriptSummaryBlock(:final text) => text,
    TranscriptToolCallBlock(:final toolCall) =>
      '<tool_call name="${toolCall.name}" id="${toolCall.id}" />',
    TranscriptToolCallResponseBlock(:final response) =>
      '<tool_response name="${response.toolName}" '
          'call_id="${response.callId}">${response.modelText}'
          '</tool_response>',
  };
}
