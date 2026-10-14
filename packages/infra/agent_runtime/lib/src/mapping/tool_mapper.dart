import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';

CompletionTool toCompletionTool(ToolDefinition definition) => CompletionTool(
  name: definition.name,
  description: definition.description,
  parameters: definition.parameters,
);

/// Adopts the provider's call id so the tool result can echo it back, or
/// mints one when the provider sent none.
ToolCall toToolCall(
  CompletionToolCall call, {
  required String Function() mint,
}) => ToolCallDefault(
  id: call.id.isEmpty ? mint() : call.id,
  name: call.name,
  arguments: call.arguments,
);
