import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// What a session's turns run under: the prompt and the per-turn sampling and
/// reasoning choices. Remembered from the last user turn so internally
/// started turns (report delivery, on-demand compaction) run the same way.
@model
@immutable
final class TurnOptions {
  const TurnOptions({
    required this.systemPrompt,
    required this.sampling,
    required this.reasoningMode,
    required this.compactionReasoningMode,
  });

  /// The options an agent is minted with before any user turn has run.
  const TurnOptions.baseline(String systemPrompt)
    : this(
        systemPrompt: systemPrompt,
        sampling: const SamplingOptions(seed: 0),
        reasoningMode: 'auto',
        compactionReasoningMode: 'auto',
      );

  final String systemPrompt;
  final SamplingOptions sampling;
  final String reasoningMode;
  final String compactionReasoningMode;

  AgentConfig toAgentConfig({
    required double compactionRatio,
    required List<ToolDefinition> tools,
  }) => AgentConfig(
    systemPrompt: systemPrompt,
    sampling: sampling,
    reasoningMode: reasoningMode,
    compactionReasoningMode: compactionReasoningMode,
    compactionRatio: compactionRatio,
    tools: tools,
  );

  @override
  bool operator ==(Object other) =>
      other is TurnOptions &&
      other.systemPrompt == systemPrompt &&
      other.sampling == sampling &&
      other.reasoningMode == reasoningMode &&
      other.compactionReasoningMode == compactionReasoningMode;

  @override
  int get hashCode => Object.hash(
    systemPrompt,
    sampling,
    reasoningMode,
    compactionReasoningMode,
  );
}
