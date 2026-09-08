import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Keeps the sampling knobs an OpenAI-compatible server understands and
/// drops the llama-only ones.
InferenceSampling toInferenceSampling(
  SamplingOptions options, {
  int? maxOutputTokens,
}) => InferenceSampling(
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
InferenceReasoning toInferenceReasoning(String mode) {
  final name = mode.trim();
  if (name == 'off') return const InferenceReasoningDisabled();
  if (name == 'on') return const InferenceReasoningEnabled();
  final effort = InferenceEffort.values
      .where((candidate) => candidate.name == name)
      .firstOrNull;
  return effort == null
      ? const InferenceReasoningDefault()
      : InferenceReasoningEffort(effort);
}
