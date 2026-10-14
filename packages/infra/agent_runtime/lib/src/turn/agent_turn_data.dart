import 'dart:convert';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:clock/clock.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:meta/meta.dart';
import 'package:tool_protocol/tool_protocol.dart' show CallIdMinter;

/// Token usage reported by the last completion.
@immutable
final class AgentUsage {
  const AgentUsage({
    required this.promptTokens,
    required this.completionTokens,
  });

  final int promptTokens;
  final int completionTokens;

  int get total => promptTokens + completionTokens;

  @override
  bool operator ==(Object other) =>
      other is AgentUsage &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens;

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens);

  @override
  String toString() =>
      'AgentUsage(prompt: $promptTokens, completion: $completionTokens)';
}

enum _OpenBlockKind { reasoning, text }

/// The assistant entry being streamed for one step.
final class StepFrame {
  StepFrame({required this.entryId});

  final TranscriptEntryId entryId;
  final List<TranscriptBlock> blocks = [];

  /// How much output each of [blocks] holds, in characters.
  final List<int> _outputLengths = [];

  /// The tokens the provider counted for each of [blocks], when it counts.
  final List<int> _countedTokens = [];
  var _counted = false;
  final List<ToolCall> toolCalls = [];
  CompletionStopReason? stop;
  _OpenBlockKind? _openKind;
  late TranscriptBlockId _openId;
  late DateTime _openStartedAt;
  DateTime? _lastEndedAt;
  final StringBuffer _openText = StringBuffer();

  bool get hasContent => blocks.isNotEmpty;

  /// Appends [text] to the open block of the matching kind, or opens a new
  /// one, and returns the block it landed in.
  TranscriptBlockId appendText(
    String text, {
    required bool reasoning,
    required DateTime at,
    int? tokens,
  }) {
    final kind = reasoning ? _OpenBlockKind.reasoning : _OpenBlockKind.text;
    if (_openKind != kind) {
      _openKind = kind;
      _openId = TranscriptBlockId.v7();
      _openStartedAt = _lastEndedAt ?? at;
      _openText.clear();
      blocks.add(_openBlock(at));
      _outputLengths.add(0);
      _countedTokens.add(0);
    }
    _openText.write(text);
    _lastEndedAt = at;
    blocks[blocks.length - 1] = _openBlock(at);
    _outputLengths[_outputLengths.length - 1] = _openText.length;
    _count(tokens);
    return _openId;
  }

  TranscriptBlock _openBlock(DateTime endedAt) {
    final id = _openId;
    final text = _openText.toString();
    final stat = BlockStat(startedAt: _openStartedAt, endedAt: endedAt);
    return _openKind == _OpenBlockKind.reasoning
        ? TranscriptReasoningBlock(id: id, text: text, stat: stat)
        : TranscriptParagraphBlock(id: id, text: text, stat: stat);
  }

  /// Records a complete tool call and returns its block; the next text
  /// delta opens a fresh block.
  TranscriptBlockId addToolCall(
    ToolCall toolCall, {
    required DateTime at,
    int? tokens,
  }) {
    _openKind = null;
    final id = TranscriptBlockId.v7();
    blocks.add(
      TranscriptToolCallBlock(
        id: id,
        toolCall: toolCall,
        stat: BlockStat(startedAt: _lastEndedAt ?? at, endedAt: at),
      ),
    );
    _lastEndedAt = at;
    _outputLengths.add(
      toolCall.name.length + jsonEncode(toolCall.arguments).length,
    );
    _countedTokens.add(0);
    _count(tokens);
    toolCalls.add(toolCall);
    return id;
  }

  void _count(int? tokens) {
    if (tokens == null) return;
    _counted = true;
    _countedTokens.last += tokens;
  }

  /// Gives every block's stat its part of the step's tokens. When the
  /// provider counted the tokens behind each delta, every block carries
  /// exactly those. Otherwise the [completionTokens] the step decoded are
  /// shared by how much of the output each block holds; when the provider
  /// counts [reasoningTokens], reasoning blocks share exactly those and the
  /// rest share what is left, so reasoning the provider never streamed lands
  /// on no block.
  void shareTokens(int completionTokens, {int? reasoningTokens}) {
    if (_counted) return _setTokenCounts(_countedTokens);
    final reasoning = reasoningTokens ?? 0;
    final countedApart = [
      for (final block in blocks)
        reasoning > 0 && block is TranscriptReasoningBlock,
    ];
    final reasoningShares = splitProportionally(reasoning, [
      for (var index = 0; index < blocks.length; index++)
        if (countedApart[index]) _outputLengths[index] else 0,
    ]);
    final outputShares = splitProportionally(completionTokens - reasoning, [
      for (var index = 0; index < blocks.length; index++)
        if (countedApart[index]) 0 else _outputLengths[index],
    ]);
    _setTokenCounts([
      for (var index = 0; index < blocks.length; index++)
        reasoningShares[index] + outputShares[index],
    ]);
  }

  void _setTokenCounts(List<int> counts) {
    for (var index = 0; index < blocks.length; index++) {
      blocks[index] = blocks[index].copyWith.stat!(tokenCount: counts[index]);
    }
  }

  TranscriptEntry toEntry() =>
      TranscriptEntry(id: entryId, role: Role.assistant, blocks: blocks);

  String get report => blocks
      .whereType<TranscriptParagraphBlock>()
      .map((block) => block.text)
      .join();
}

/// The summary being streamed for one compaction.
final class CompactionFrame {
  CompactionFrame({required this.tokensBefore, required this.priorSummary});

  final int tokensBefore;
  final String? priorSummary;
  final StringBuffer summary = StringBuffer();
  CompactionPromptContent? content;
  AgentUsage? summaryUsage;
  bool finished = false;
}

/// Everything one agent turn knows, shared across its states.
final class AgentTurnData {
  AgentTurnData({
    required this.handle,
    required this.config,
    required this.goal,
    required this.transcript,
    required this.modelId,
    required this.contextWindow,
    required this.summaryMaxOutputTokens,
    this.maxOutputTokens,
    this.usage,
  }) {
    callIdMinter.seedAll(_existingCallIds());
  }

  final AgentHandle handle;
  final AgentConfig config;
  final TurnGoal goal;
  final String modelId;
  final int contextWindow;
  final int? maxOutputTokens;
  final int summaryMaxOutputTokens;
  late final CallIdMinter callIdMinter = CallIdMinter(now: () => clock.now());

  Transcript transcript;
  AgentUsage? usage;
  int completionId = 0;
  int generatedTokensTotal = 0;
  StepFrame? step;
  CompactionFrame? compaction;
  String? report;

  int get compactAt => (contextWindow * config.compactionRatio).floor();

  bool get needsCompaction {
    final current = usage;
    return current != null &&
        current.total >= compactAt &&
        transcript.hasFoldableEntries;
  }

  AgentTelemetry telemetry() => AgentTelemetry(
    compactAtLimit: compactAt,
    generatedTokens: generatedTokensTotal,
  );

  void append(List<TranscriptEntry> entries) {
    transcript = Transcript(
      id: transcript.id,
      revision: transcript.revision + entries.length,
      entries: [...transcript.entries, ...entries],
    );
  }

  static final _mintedCallId = RegExp(r'^[0-9a-z]{6}$');

  Iterable<String> _existingCallIds() sync* {
    for (final entry in transcript.entries) {
      for (final block in entry.toolCallBlocks) {
        final id = block.toolCall.id;
        if (_mintedCallId.hasMatch(id)) yield id;
      }
    }
  }
}
