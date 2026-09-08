import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:clock/clock.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:meta/meta.dart';
import 'package:tool_protocol/tool_protocol.dart' show CallIdMinter;

/// Token usage reported by the last completion.
@immutable
final class RemoteUsage {
  const RemoteUsage({
    required this.promptTokens,
    required this.completionTokens,
  });

  final int promptTokens;
  final int completionTokens;

  int get total => promptTokens + completionTokens;

  @override
  bool operator ==(Object other) =>
      other is RemoteUsage &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens;

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens);

  @override
  String toString() =>
      'RemoteUsage(prompt: $promptTokens, completion: $completionTokens)';
}

enum _OpenBlockKind { reasoning, text }

/// The assistant entry being streamed for one step.
final class StepFrame {
  StepFrame({required this.entryId});

  final TranscriptEntryId entryId;
  final List<TranscriptBlock> blocks = [];
  final List<ToolCall> toolCalls = [];
  InferenceStopReason? stop;
  _OpenBlockKind? _openKind;
  late TranscriptBlockId _openId;
  late DateTime _openStartedAt;
  final StringBuffer _openText = StringBuffer();

  bool get hasContent => blocks.isNotEmpty;

  /// Appends [text] to the open block of the matching kind, or opens a new
  /// one, and returns the block it landed in.
  TranscriptBlockId appendText(
    String text, {
    required bool reasoning,
    required DateTime at,
  }) {
    final kind = reasoning ? _OpenBlockKind.reasoning : _OpenBlockKind.text;
    if (_openKind != kind) {
      _openKind = kind;
      _openId = TranscriptBlockId.v7();
      _openStartedAt = at;
      _openText.clear();
      blocks.add(_openBlock(at));
    }
    _openText.write(text);
    blocks[blocks.length - 1] = _openBlock(at);
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
  TranscriptBlockId addToolCall(ToolCall toolCall, {required DateTime at}) {
    _openKind = null;
    final id = TranscriptBlockId.v7();
    blocks.add(
      TranscriptToolCallBlock(
        id: id,
        toolCall: toolCall,
        stat: BlockStat(startedAt: at, endedAt: at),
      ),
    );
    toolCalls.add(toolCall);
    return id;
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
  RemoteUsage? summaryUsage;
  bool finished = false;
}

/// Everything one remote turn knows, shared across its states.
final class RemoteTurnData {
  RemoteTurnData({
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
  RemoteUsage? usage;
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
