import 'package:tool_protocol/tool_protocol.dart';

/// Extracts tool calls from raw text content.
///
/// Reasoning/visible-text separation is handled by the stream tokenizer via
/// tags.
abstract interface class ToolCallExtractor {
  List<ToolCall> extract(String text);
}
