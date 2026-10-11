import 'package:completion_protocol/src/models/agent_identity.dart';
import 'package:completion_protocol/src/models/completion_message.dart';
import 'package:completion_protocol/src/models/completion_reasoning.dart';
import 'package:completion_protocol/src/models/completion_sampling.dart';
import 'package:completion_protocol/src/models/completion_tool.dart';
import 'package:meta/meta.dart';

/// Everything needed to ask a model for one streamed chat completion.
@immutable
final class CompletionRequest {
  const CompletionRequest({
    required this.model,
    required this.messages,
    this.tools = const [],
    this.sampling = const CompletionSampling(),
    this.reasoning = const CompletionReasoningDefault(),
    this.stopSequences = const [],
    this.agent,
  });

  final String model;

  final List<CompletionMessage> messages;

  final List<CompletionTool> tools;

  final CompletionSampling sampling;

  final CompletionReasoning reasoning;

  final List<String> stopSequences;

  /// The agent asking, for endpoints that keep per-agent state.
  final AgentIdentity? agent;
}
