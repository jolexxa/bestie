import 'package:inference_protocol/src/models/inference_tool_call.dart';
import 'package:meta/meta.dart';

/// One entry of the conversation sent to the model.
@immutable
sealed class InferenceMessage {
  const InferenceMessage();
}

final class InferenceSystemMessage extends InferenceMessage {
  const InferenceSystemMessage(this.text);

  final String text;
}

final class InferenceUserMessage extends InferenceMessage {
  const InferenceUserMessage(this.text);

  final String text;
}

final class InferenceAssistantMessage extends InferenceMessage {
  const InferenceAssistantMessage({
    required this.text,
    this.reasoning,
    this.toolCalls = const [],
    this.providerReasoning,
  });

  final String text;

  /// Visible reasoning text the model produced before answering.
  final String? reasoning;

  final List<InferenceToolCall> toolCalls;

  /// Opaque provider reasoning blocks (e.g. OpenRouter `reasoning_details`)
  /// echoed back verbatim so multi-step tool loops keep their context.
  final List<Map<String, Object?>>? providerReasoning;
}

final class InferenceToolResultMessage extends InferenceMessage {
  const InferenceToolResultMessage({
    required this.toolCallId,
    required this.name,
    required this.content,
    this.isError = false,
  });

  final String toolCallId;

  final String name;

  final String content;

  final bool isError;
}
