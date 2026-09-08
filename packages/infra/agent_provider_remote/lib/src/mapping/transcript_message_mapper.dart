import 'dart:convert';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Projects the transcript window after the latest summary checkpoint into
/// the messages a chat completion expects.
final class TranscriptMessageMapper {
  const TranscriptMessageMapper();

  List<InferenceMessage> map({
    required Transcript transcript,
    required String systemPrompt,
    required int from,
  }) {
    final window = transcript.entries.skip(from).toList();
    final systemText = _joinText(
      window
          .where((entry) => entry.role == Role.system)
          .expand((entry) => entry.blocks)
          .map(_plainText),
    );
    final synthesizedSystemPrompt = _appendText(systemPrompt, systemText);
    final messages = <InferenceMessage>[
      if (synthesizedSystemPrompt.isNotEmpty)
        InferenceSystemMessage(synthesizedSystemPrompt),
    ];
    for (final entry in window) {
      switch (entry.role) {
        case Role.system:
          final summary = _joinText(
            entry.blocks.whereType<TranscriptSummaryBlock>().map(
              (block) => block.text,
            ),
          );
          if (summary.isNotEmpty) {
            messages.add(InferenceUserMessage(_framedSummary(summary)));
          }
        case Role.user:
          messages.add(
            InferenceUserMessage(_joinText(entry.blocks.map(_plainText))),
          );
        case Role.assistant:
          messages.add(_assistantMessage(entry));
        case Role.tool:
          messages.add(_toolMessage(entry));
      }
    }
    return messages;
  }

  InferenceAssistantMessage _assistantMessage(TranscriptEntry entry) =>
      InferenceAssistantMessage(
        text: _joinText(entry.blocks.map(_plainText)),
        reasoning: _joinText(
          entry.reasoningBlocks.map((block) => block.text),
        ).nullIfEmpty,
        toolCalls: [
          for (final block in entry.toolCallBlocks)
            InferenceToolCall(
              id: block.toolCall.id,
              name: block.toolCall.name,
              arguments: block.toolCall.arguments,
              rawArguments: jsonEncode(block.toolCall.arguments),
            ),
        ],
      );

  InferenceToolResultMessage _toolMessage(TranscriptEntry entry) {
    final response = entry.toolResponseBlocks.firstOrNull?.response;
    if (response == null) {
      return const InferenceToolResultMessage(
        toolCallId: '',
        name: '',
        content: 'Tool response was unavailable.',
        isError: true,
      );
    }
    return InferenceToolResultMessage(
      toolCallId: response.callId,
      name: response.toolName,
      content: response.modelText,
      isError: response is ToolCallFailed || response is ToolCallCanceled,
    );
  }

  static String _plainText(TranscriptBlock block) => switch (block) {
    TranscriptParagraphBlock(:final text) => text,
    TranscriptToolOutputBlock(:final text) => text,
    _ => '',
  };

  static String _framedSummary(String summary) =>
      'The conversation history before this point was compacted into the '
      'following summary:\n\n<summary>\n$summary\n</summary>';

  static String _joinText(Iterable<String> parts) =>
      parts.where((text) => text.isNotEmpty).join();

  static String _appendText(String first, String second) {
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    return '$first\n\n$second';
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
