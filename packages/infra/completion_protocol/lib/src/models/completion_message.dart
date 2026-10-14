import 'package:completion_protocol/src/models/completion_tool_call.dart';
import 'package:meta/meta.dart';

/// One entry of the conversation sent to the model.
@immutable
sealed class CompletionMessage {
  const CompletionMessage();
}

final class CompletionSystemMessage extends CompletionMessage {
  const CompletionSystemMessage(this.text);

  final String text;
}

final class CompletionUserMessage extends CompletionMessage {
  const CompletionUserMessage(this.text);

  final String text;
}

final class CompletionAssistantMessage extends CompletionMessage {
  const CompletionAssistantMessage({
    required this.text,
    this.reasoning,
    this.toolCalls = const [],
  });

  final String text;

  /// Visible reasoning text the model produced before answering.
  final String? reasoning;

  final List<CompletionToolCall> toolCalls;
}

final class CompletionToolResultMessage extends CompletionMessage {
  const CompletionToolResultMessage({
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
