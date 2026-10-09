import 'package:tool_protocol/tool_protocol.dart';

enum ModelStopReason { stop, length, toolCalls, error, cancelled, maxSteps }

sealed class ModelOutput {
  const ModelOutput();
}

final class ModelTextDelta extends ModelOutput {
  const ModelTextDelta(this.text);
  final String text;
}

final class ModelReasoningDelta extends ModelOutput {
  const ModelReasoningDelta(this.text);
  final String text;
}

final class ModelToolCallOutput extends ModelOutput {
  const ModelToolCallOutput(this.call);
  final ToolCall call;
}

/// A tool call the model attempted but the parser could not extract.
final class ModelToolCallUnparsed extends ModelOutput {
  const ModelToolCallUnparsed({required this.rawText, this.name});
  final String rawText;
  final String? name;
}

final class ModelTokensGenerated extends ModelOutput {
  const ModelTokensGenerated(this.count);
  final int count;
}

final class ModelStepFinished extends ModelOutput {
  const ModelStepFinished(this.reason);
  final ModelStopReason reason;
}
