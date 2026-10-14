import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';

/// Keeps the sampling knobs an OpenAI-compatible server understands and
/// drops the llama-only ones.
CompletionSampling toCompletionSampling(
  SamplingOptions options, {
  int? maxOutputTokens,
}) => CompletionSampling(
  temperature: options.temperature,
  topP: options.topP,
  frequencyPenalty: options.penaltyFreq,
  presencePenalty: options.penaltyPresent,
  seed: options.seed == 0 ? null : options.seed,
  maxOutputTokens: maxOutputTokens,
);

/// Maps a reasoning mode name from the agent config to a request setting:
/// `auto` says nothing, `off` and `on` toggle, an effort name asks for that
/// effort, and anything unknown falls back to `auto`.
CompletionReasoning toCompletionReasoning(String mode) {
  final name = mode.trim();
  if (name == 'off') return const CompletionReasoningDisabled();
  if (name == 'on') return const CompletionReasoningEnabled();
  final effort = CompletionEffort.values
      .where((candidate) => candidate.name == name)
      .firstOrNull;
  return effort == null
      ? const CompletionReasoningDefault()
      : CompletionReasoningEffort(effort);
}
