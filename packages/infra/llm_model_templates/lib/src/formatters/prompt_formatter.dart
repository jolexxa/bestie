import 'package:llm_model_templates/src/formatters/prompt_tool.dart';
import 'package:llm_model_templates/src/stream/stream_parser.dart';
import 'package:tool_protocol/tool_protocol.dart';

sealed class PromptMessage {
  const PromptMessage();
}

final class PromptSystemMessage extends PromptMessage {
  const PromptSystemMessage(this.content);

  final String content;
}

final class PromptDeveloperMessage extends PromptMessage {
  const PromptDeveloperMessage(this.content);

  final String content;
}

final class PromptUserMessage extends PromptMessage {
  const PromptUserMessage(this.content);

  final String content;
}

final class PromptAssistantMessage extends PromptMessage {
  const PromptAssistantMessage({
    this.content = '',
    this.reasoning,
    this.toolCalls = const [],
  });

  final String content;
  final String? reasoning;
  final List<ToolCall> toolCalls;
}

final class PromptToolMessage extends PromptMessage {
  const PromptToolMessage({
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

abstract class PromptFormatter {
  const PromptFormatter();

  String format({
    required List<PromptMessage> messages,
    required List<PromptTool> tools,
    required String reasoningMode,
    String? assistantPrefill,
  });

  /// Whether [format] ends the prompt inside an already-opened reasoning
  /// block for this mode, so the model's output stream begins mid-reasoning
  /// and never emits the opening think tag itself.
  bool prefillsReasoning(String reasoningMode) => false;

  List<String> get stopSequences;
  bool get addBos;
}

final class ModelProfile {
  const ModelProfile({
    required this.formatter,
    required this.streamParser,
    this.tags = const [],
  });

  final PromptFormatter formatter;
  final StreamParser streamParser;

  /// Tag strings used by stream assemblers to force chunk boundaries.
  final List<String> tags;
}
