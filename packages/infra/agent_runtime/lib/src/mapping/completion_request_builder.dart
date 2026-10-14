import 'package:agent_runtime/src/mapping/agent_identity_mapper.dart';
import 'package:agent_runtime/src/mapping/sampling_mapper.dart';
import 'package:agent_runtime/src/mapping/summary_prompt_builder.dart';
import 'package:agent_runtime/src/mapping/tool_mapper.dart';
import 'package:agent_runtime/src/mapping/transcript_message_mapper.dart';
import 'package:agent_runtime/src/turn/agent_turn_data.dart';
import 'package:completion_protocol/completion_protocol.dart';

/// Builds the two requests a turn makes: a step and a compaction summary.
final class CompletionRequestBuilder {
  const CompletionRequestBuilder();

  static const _messages = TranscriptMessageMapper();
  static const _summaryPrompt = SummaryPromptBuilder();

  CompletionRequest step(AgentTurnData data) => CompletionRequest(
    model: data.modelId,
    messages: _messages.map(
      transcript: data.transcript,
      systemPrompt: data.config.systemPrompt,
      from: data.transcript.lastCheckpoint,
    ),
    tools: [for (final tool in data.config.tools) toCompletionTool(tool)],
    sampling: toCompletionSampling(
      data.config.sampling,
      maxOutputTokens: data.maxOutputTokens,
    ),
    reasoning: toCompletionReasoning(data.config.reasoningMode),
    agent: toAgentIdentity(data.handle),
  );

  CompletionRequest summary(AgentTurnData data) {
    final content = data.compaction!.content!;
    return CompletionRequest(
      model: data.modelId,
      messages: [
        CompletionSystemMessage(content.instruction),
        CompletionUserMessage(
          _summaryPrompt.build(
            entries: data.transcript.entries
                .skip(data.transcript.lastCheckpoint)
                .toList(),
            content: content,
          ),
        ),
      ],
      sampling: toCompletionSampling(
        data.config.sampling,
        maxOutputTokens: data.summaryMaxOutputTokens,
      ),
      reasoning: toCompletionReasoning(data.config.compactionReasoningMode),
      agent: toAgentIdentity(data.handle),
    );
  }
}
