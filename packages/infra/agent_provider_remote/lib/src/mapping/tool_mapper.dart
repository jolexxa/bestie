import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart';

InferenceTool toInferenceTool(ToolDefinition definition) => InferenceTool(
  name: definition.name,
  description: definition.description,
  parameters: definition.parameters,
);

/// Adopts the provider's call id so the tool result can echo it back, or
/// mints one when the provider sent none.
ToolCall toToolCall(
  InferenceToolCall call, {
  required String Function() mint,
}) => ToolCallDefault(
  id: call.id.isEmpty ? mint() : call.id,
  name: call.name,
  arguments: call.arguments,
);
