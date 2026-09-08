import 'package:agent_provider_protocol/src/transcript/models/block_stat.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:tool_protocol/tool_protocol.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transcript_block.mapper.dart';

@MappableClass(discriminatorKey: 'type')
sealed class TranscriptBlock with TranscriptBlockMappable {
  const TranscriptBlock({required this.id, this.stat});

  final TranscriptBlockId id;

  /// Timing and token facts for this block, when known.
  final BlockStat? stat;
}

@MappableClass(discriminatorValue: 'paragraph')
final class TranscriptParagraphBlock extends TranscriptBlock
    with TranscriptParagraphBlockMappable {
  const TranscriptParagraphBlock({
    required super.id,
    required this.text,
    super.stat,
  });

  final String text;
}

@MappableClass(discriminatorValue: 'tool_output')
final class TranscriptToolOutputBlock extends TranscriptBlock
    with TranscriptToolOutputBlockMappable {
  const TranscriptToolOutputBlock({
    required super.id,
    required this.text,
    super.stat,
  });

  final String text;
}

@MappableClass(discriminatorValue: 'reasoning')
final class TranscriptReasoningBlock extends TranscriptBlock
    with TranscriptReasoningBlockMappable {
  const TranscriptReasoningBlock({
    required super.id,
    required this.text,
    super.stat,
  });

  final String text;
}

@MappableClass(discriminatorValue: 'tool_call')
final class TranscriptToolCallBlock extends TranscriptBlock
    with TranscriptToolCallBlockMappable {
  const TranscriptToolCallBlock({
    required super.id,
    required this.toolCall,
    super.stat,
    this.labelTemplate,
  });

  final ToolCall toolCall;

  /// Denormalized activity-stub label template for the call's terminal state,
  /// resolved from the tool definition at commit. Null for legacy blocks and
  /// non-tool calls.
  final String? labelTemplate;
}

@MappableClass(discriminatorValue: 'tool_response')
final class TranscriptToolCallResponseBlock extends TranscriptBlock
    with TranscriptToolCallResponseBlockMappable {
  const TranscriptToolCallResponseBlock({
    required super.id,
    required this.response,
    super.stat,
  });

  final ToolCallResponse response;
}

@MappableClass(discriminatorValue: 'summary')
final class TranscriptSummaryBlock extends TranscriptBlock
    with TranscriptSummaryBlockMappable {
  const TranscriptSummaryBlock({
    required super.id,
    required this.text,
    super.stat,
  });

  final String text;
}
