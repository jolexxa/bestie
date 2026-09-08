import 'package:agent_provider_protocol/src/models/role.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_block.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transcript_entry.mapper.dart';

@MappableClass()
final class TranscriptEntry with TranscriptEntryMappable {
  const TranscriptEntry({
    required this.id,
    required this.role,
    required this.blocks,
    this.name,
  });

  final TranscriptEntryId id;
  final Role role;
  final List<TranscriptBlock> blocks;
  final String? name;

  Iterable<TranscriptReasoningBlock> get reasoningBlocks =>
      blocks.whereType<TranscriptReasoningBlock>();

  Iterable<TranscriptToolCallBlock> get toolCallBlocks =>
      blocks.whereType<TranscriptToolCallBlock>();

  Iterable<TranscriptToolCallResponseBlock> get toolResponseBlocks =>
      blocks.whereType<TranscriptToolCallResponseBlock>();
}
