import 'package:llm_model_templates/src/formatters/prompt_formatter.dart';
import 'package:tool_protocol/tool_protocol.dart';

extension PromptMessageFormatting on PromptMessage {
  String get content => switch (this) {
    PromptSystemMessage(:final content) => content,
    PromptDeveloperMessage(:final content) => content,
    PromptUserMessage(:final content) => content,
    PromptAssistantMessage(:final content) => content,
    PromptToolMessage(:final content) => content,
  };

  String get chatMlRole => switch (this) {
    PromptAssistantMessage() => 'assistant',
    PromptToolMessage() => 'tool',
    PromptSystemMessage() || PromptDeveloperMessage() => 'system',
    PromptUserMessage() => 'user',
  };

  String? get reasoning => switch (this) {
    PromptAssistantMessage(:final reasoning) => reasoning,
    _ => null,
  };

  List<ToolCall> get toolCalls => switch (this) {
    PromptAssistantMessage(:final toolCalls) => toolCalls,
    _ => const [],
  };

  String? get toolCallId => switch (this) {
    PromptToolMessage(:final toolCallId) => toolCallId,
    _ => null,
  };

  String? get name => switch (this) {
    PromptToolMessage(:final name) => name,
    _ => null,
  };

  bool get isSystemLike =>
      this is PromptSystemMessage || this is PromptDeveloperMessage;
}
