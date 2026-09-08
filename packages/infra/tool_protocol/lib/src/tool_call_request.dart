import 'dart:async';

import 'package:clock/clock.dart';
import 'package:tool_protocol/src/models/tool_call.dart';
import 'package:tool_protocol/src/models/tool_call_response.dart';
import 'package:tool_protocol/src/models/tool_definition.dart';

/// A tool call handed upward to be answered.
class ToolCallRequest {
  ToolCallRequest(
    this.call, {
    required this.definition,
    required this.conversationId,
    required this.agentId,
    required this.outputPath,
    required this.maxOutputChars,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? clock.now();

  /// The call to fulfil.
  final ToolCall call;

  /// What the model was told this tool is.
  ///
  /// Carried rather than looked up, so answering a call needs no registry.
  final ToolDefinition definition;

  /// Conversation that owns this call and any feature-owned output.
  final String conversationId;

  /// Agent whose turn emitted the call.
  final String agentId;

  /// Where the tool may store output for this call.
  final String outputPath;

  /// Tool call response cap.
  final int maxOutputChars;

  /// When this call was handed upward.
  final DateTime createdAt;

  /// Milliseconds since [createdAt], including queueing.
  int get elapsedMs => clock.now().difference(createdAt).inMilliseconds;

  final Completer<ToolCallResponse> _completer = Completer<ToolCallResponse>();

  /// Resolves once someone above answers.
  Future<ToolCallResponse> get response => _completer.future;

  /// Whether this request has already been answered.
  bool get isAnswered => _completer.isCompleted;

  /// Answers with [response]. The first answer wins; later ones are dropped.
  void settle(ToolCallResponse response) {
    if (_completer.isCompleted) return;
    _completer.complete(response);
  }
}
