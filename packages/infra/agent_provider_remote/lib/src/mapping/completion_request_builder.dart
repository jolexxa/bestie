import 'package:agent_provider_remote/src/mapping/sampling_mapper.dart';
import 'package:agent_provider_remote/src/mapping/summary_prompt_builder.dart';
import 'package:agent_provider_remote/src/mapping/tool_mapper.dart';
import 'package:agent_provider_remote/src/mapping/transcript_message_mapper.dart';
import 'package:agent_provider_remote/src/turn/remote_turn_data.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Builds the two requests a turn makes: a step and a compaction summary.
final class CompletionRequestBuilder {
  const CompletionRequestBuilder();

  static const _messages = TranscriptMessageMapper();
  static const _summaryPrompt = SummaryPromptBuilder();

  CompletionRequest step(RemoteTurnData data) => CompletionRequest(
    model: data.modelId,
    messages: _messages.map(
      transcript: data.transcript,
      systemPrompt: data.config.systemPrompt,
      from: data.transcript.lastCheckpoint,
    ),
    tools: [for (final tool in data.config.tools) toInferenceTool(tool)],
    sampling: toInferenceSampling(
      data.config.sampling,
      maxOutputTokens: data.maxOutputTokens,
    ),
    reasoning: toInferenceReasoning(data.config.reasoningMode),
  );

  CompletionRequest summary(RemoteTurnData data) {
    final content = data.compaction!.content!;
    return CompletionRequest(
      model: data.modelId,
      messages: [
        InferenceSystemMessage(content.instruction),
        InferenceUserMessage(
          _summaryPrompt.build(
            entries: data.transcript.entries
                .skip(data.transcript.lastCheckpoint)
                .toList(),
            content: content,
          ),
        ),
      ],
      sampling: toInferenceSampling(
        data.config.sampling,
        maxOutputTokens: data.summaryMaxOutputTokens,
      ),
      reasoning: toInferenceReasoning(data.config.compactionReasoningMode),
    );
  }
}
