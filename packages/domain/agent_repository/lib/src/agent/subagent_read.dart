import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show estimatedCharactersPerToken;

/// One unit of a subagent read: what a page may stop between, and the cursor
/// naming it.
@model
final class SubagentReadBlock {
  /// [block] read as [text], costed against the runtime's own count when it
  /// recorded one.
  SubagentReadBlock.fromTranscriptBlock(TranscriptBlock block, this.text)
    : cursor = block.id.value.uuid,
      tokens =
          block.stat?.tokenCount ?? text.length ~/ estimatedCharactersPerToken;

  /// The persisted block id, in the string form a follow-up read passes back.
  final String cursor;

  final String text;

  /// What this block costs to read.
  final int tokens;
}

/// What reading a subagent produced.
sealed class SubagentRead {
  const SubagentRead();
}

/// A page of output, and the cursor the next one resumes from.
@model
final class SubagentReadPage extends SubagentRead {
  const SubagentReadPage({
    required this.text,
    required this.next,
    required this.remaining,
  });

  final String text;

  /// What a follow-up read resumes after; null once nothing is left.
  final String? next;

  /// Blocks this page did not reach.
  final int remaining;
}

/// The subagent is still working, so it has nothing settled to read.
@model
final class SubagentReadBusy extends SubagentRead {
  const SubagentReadBusy();
}

/// No subagent by that name ran in this conversation.
@model
final class SubagentReadUnknown extends SubagentRead {
  const SubagentReadUnknown();
}

/// There is nothing at or after where the read started.
@model
final class SubagentReadEnd extends SubagentRead {
  const SubagentReadEnd();
}

/// The supplied cursor names no block of this view.
@model
final class SubagentReadCursorLost extends SubagentRead {
  const SubagentReadCursorLost();
}

/// The next block alone is wider than the whole allowance.
@model
final class SubagentReadBlockTooWide extends SubagentRead {
  const SubagentReadBlockTooWide(this.chars);

  final int chars;
}

/// A subagent's output as blocks a read walks: what the reader may see, and
/// where a page may stop.
@model
final class SubagentReadView {
  const SubagentReadView(this.blocks);

  /// The final assistant message of [entries], block by block.
  factory SubagentReadView.answer(List<ConversationEntry> entries) {
    for (final entry in entries.reversed) {
      if (entry is! MessageEntry || entry.entry.role != Role.assistant) {
        continue;
      }
      return SubagentReadView([
        for (final block in entry.entry.blocks)
          if (block is TranscriptParagraphBlock && block.text.trim().isNotEmpty)
            SubagentReadBlock.fromTranscriptBlock(block, block.text),
      ]);
    }
    return const SubagentReadView([]);
  }

  /// Every persisted message of [entries], rendered block by block.
  factory SubagentReadView.transcript(List<ConversationEntry> entries) =>
      SubagentReadView([
        for (final entry in entries)
          if (entry is MessageEntry)
            for (final block in entry.entry.blocks)
              ?_rendered(entry.entry.role, block),
      ]);

  final List<SubagentReadBlock> blocks;

  /// What reading this view whole costs, in tokens.
  int get tokens => blocks.fold(0, (total, block) => total + block.tokens);

  /// Takes whole blocks after the [after] cursor, up to [maxChars].
  SubagentRead page({required int maxChars, String? after}) {
    var start = 0;
    if (after != null) {
      final at = blocks.indexWhere((block) => block.cursor == after);
      if (at < 0) return const SubagentReadCursorLost();
      start = at + 1;
    }
    if (start >= blocks.length) return const SubagentReadEnd();

    final buffer = StringBuffer();
    var used = 0;
    var end = start;
    while (end < blocks.length) {
      final text = blocks[end].text;
      final cost = used == 0 ? text.length : text.length + 2;
      if (used + cost > maxChars) break;
      if (used > 0) buffer.write('\n\n');
      buffer.write(text);
      used += cost;
      end++;
    }

    if (end == start) {
      return SubagentReadBlockTooWide(blocks[start].text.length);
    }

    final remaining = blocks.length - end;
    return SubagentReadPage(
      text: buffer.toString(),
      next: remaining > 0 ? blocks[end - 1].cursor : null,
      remaining: remaining,
    );
  }

  static SubagentReadBlock? _rendered(Role role, TranscriptBlock block) {
    final (label, body) = switch (block) {
      TranscriptParagraphBlock(:final text) => (role.name, text),
      TranscriptReasoningBlock(:final text) => ('${role.name} thinking', text),
      TranscriptSummaryBlock(:final text) => ('summary', text),
      TranscriptToolOutputBlock(:final text) => ('tool output', text),
      TranscriptToolCallBlock(:final toolCall) => (
        'tool call',
        '${toolCall.name} ${toolCall.arguments}',
      ),
      TranscriptToolCallResponseBlock(:final response) => (
        'tool result',
        response.modelText,
      ),
    };
    if (body.trim().isEmpty) return null;
    return SubagentReadBlock.fromTranscriptBlock(block, '[$label] $body');
  }
}
