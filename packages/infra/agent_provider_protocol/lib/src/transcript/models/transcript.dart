import 'package:agent_provider_protocol/src/transcript/models/transcript_block.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_entry.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transcript.mapper.dart';

@MappableClass()
final class Transcript with TranscriptMappable {
  const Transcript({
    required this.id,
    required this.revision,
    required this.entries,
  });

  final TranscriptId id;
  final int revision;
  final List<TranscriptEntry> entries;

  /// Index of the entry holding the latest summary checkpoint, else 0.
  int get lastCheckpoint {
    for (var index = entries.length - 1; index >= 0; index--) {
      if (_isCheckpoint(entries[index])) return index;
    }
    return 0;
  }

  /// The text of the latest summary checkpoint, if there is one.
  String? get priorSummary {
    if (entries.isEmpty) return null;
    final entry = entries[lastCheckpoint];
    return entry.blocks.whereType<TranscriptSummaryBlock>().firstOrNull?.text;
  }

  /// Whether anything after the latest checkpoint could be folded away.
  bool get hasFoldableEntries =>
      entries.skip(lastCheckpoint).any(_isNotCheckpoint);

  static bool _isCheckpoint(TranscriptEntry entry) =>
      entry.blocks.any((block) => block is TranscriptSummaryBlock);

  static bool _isNotCheckpoint(TranscriptEntry entry) => !_isCheckpoint(entry);
}
