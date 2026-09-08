import 'package:agent_provider_protocol/src/models/role.dart';
import 'package:agent_provider_protocol/src/transcript/models/block_stat.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_block.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_entry.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:agent_provider_protocol/src/transcript/transcript_id_factories.dart';
import 'package:characters/characters.dart';

enum TranscriptTextBlockKind { paragraph, reasoning, toolOutput }

/// A contiguous run of streamed characters and the instant it arrived.
final class DeltaSpan {
  DeltaSpan({required this.start, required this.end, required this.timestamp});

  final int start;
  final int end;
  final DateTime timestamp;

  /// Tokens the model decoded to produce this run.
  int tokens = 0;
}

final class TranscriptBlockLexer {
  const TranscriptBlockLexer({
    this.maxBlockLength = 1000,
    TranscriptBlockIdFactory? idFactory,
  }) : assert(maxBlockLength > 0, 'maxBlockLength must be positive.'),
       _idFactory = idFactory ?? TranscriptBlockId.v7;

  final int maxBlockLength;
  final TranscriptBlockIdFactory _idFactory;

  List<TranscriptParagraphBlock> paragraphs(
    String text, {
    List<DeltaSpan>? spans,
  }) => _build(
    text,
    spans,
    (text, stat) =>
        TranscriptParagraphBlock(id: _idFactory(), text: text, stat: stat),
  );

  List<TranscriptReasoningBlock> reasoning(
    String text, {
    List<DeltaSpan>? spans,
  }) => _build(
    text,
    spans,
    (text, stat) =>
        TranscriptReasoningBlock(id: _idFactory(), text: text, stat: stat),
  );

  List<TranscriptToolOutputBlock> toolOutput(String text) => [
    for (final blockText in _lexText(text))
      TranscriptToolOutputBlock(id: _idFactory(), text: blockText),
  ];

  TranscriptSummaryBlock summary(String text) =>
      TranscriptSummaryBlock(id: _idFactory(), text: text);

  List<TranscriptBlock> lex({
    required String text,
    required TranscriptTextBlockKind kind,
  }) {
    return switch (kind) {
      TranscriptTextBlockKind.paragraph => paragraphs(text),
      TranscriptTextBlockKind.reasoning => reasoning(text),
      TranscriptTextBlockKind.toolOutput => toolOutput(text),
    };
  }

  /// Re-lexes an assistant [entry]'s streamed paragraph and reasoning blocks
  /// into canonical line blocks. Other roles come back untouched.
  TranscriptEntry lexEntry(TranscriptEntry entry) {
    if (entry.role != Role.assistant) return entry;
    var changed = false;
    final blocks = <TranscriptBlock>[];
    for (final block in entry.blocks) {
      final split = _lexBlock(block);
      if (split == null || split.length <= 1) {
        blocks.add(block);
        continue;
      }
      changed = true;
      blocks.addAll(split);
    }
    if (!changed) return entry;
    return TranscriptEntry(
      id: entry.id,
      role: entry.role,
      name: entry.name,
      blocks: blocks,
    );
  }

  List<TranscriptBlock>? _lexBlock(TranscriptBlock block) {
    return switch (block) {
      TranscriptParagraphBlock(:final text, :final stat) => [
        for (final lexed in paragraphs(text))
          TranscriptParagraphBlock(id: lexed.id, text: lexed.text, stat: stat),
      ],
      TranscriptReasoningBlock(:final text, :final stat) => [
        for (final lexed in reasoning(text))
          TranscriptReasoningBlock(id: lexed.id, text: lexed.text, stat: stat),
      ],
      _ => null,
    };
  }

  List<T> _build<T>(
    String text,
    List<DeltaSpan>? spans,
    T Function(String text, BlockStat? stat) make,
  ) {
    final blocks = <T>[];
    var offset = 0;
    for (final blockText in _lexText(text)) {
      final start = offset;
      offset += blockText.length;
      blocks.add(make(blockText, _statFor(spans, start, offset)));
    }
    return blocks;
  }

  BlockStat? _statFor(List<DeltaSpan>? spans, int start, int end) {
    if (spans == null) return null;
    DateTime? startedAt;
    DateTime? endedAt;
    var tokens = 0;
    for (final span in spans) {
      if (span.end <= start || span.start >= end) continue;
      startedAt ??= span.timestamp;
      endedAt = span.timestamp;
      if (span.start >= start) tokens += span.tokens;
    }
    if (startedAt == null || endedAt == null) return null;
    return BlockStat(
      startedAt: startedAt,
      endedAt: endedAt,
      tokenCount: tokens > 0 ? tokens : null,
    );
  }

  List<String> _lexText(String text) {
    if (text.isEmpty) return const [];

    final merged = <String>[];
    for (final line in _linesWithTerminators(text)) {
      if (_isOnlyNewlines(line) && merged.isNotEmpty) {
        merged[merged.length - 1] = '${merged.last}$line';
      } else {
        merged.add(line);
      }
    }

    return [
      for (final block in merged)
        for (final chunk in _splitAtMaxLength(block)) chunk,
    ];
  }

  Iterable<String> _linesWithTerminators(String text) sync* {
    var start = 0;
    while (start < text.length) {
      var end = start;
      while (end < text.length) {
        final unit = text.codeUnitAt(end);
        if (unit == 0x0A || unit == 0x0D) break;
        end++;
      }

      if (end == text.length) {
        yield text.substring(start);
        break;
      }

      if (text.codeUnitAt(end) == 0x0D &&
          end + 1 < text.length &&
          text.codeUnitAt(end + 1) == 0x0A) {
        end += 2;
      } else {
        end++;
      }

      yield text.substring(start, end);
      start = end;
    }
  }

  bool _isOnlyNewlines(String text) {
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit != 0x0A && unit != 0x0D) return false;
    }
    return true;
  }

  Iterable<String> _splitAtMaxLength(String text) sync* {
    final buffer = StringBuffer();
    var length = 0;

    for (final character in text.characters) {
      if (length == maxBlockLength) {
        yield buffer.toString();
        buffer.clear();
        length = 0;
      }

      buffer.write(character);
      length++;
    }

    if (length > 0) {
      yield buffer.toString();
    }
  }
}
