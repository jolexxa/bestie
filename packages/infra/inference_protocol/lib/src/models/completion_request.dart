import 'package:inference_protocol/src/models/inference_message.dart';
import 'package:inference_protocol/src/models/inference_reasoning.dart';
import 'package:inference_protocol/src/models/inference_sampling.dart';
import 'package:inference_protocol/src/models/inference_tool.dart';
import 'package:meta/meta.dart';

/// Everything needed to ask a model for one streamed chat completion.
@immutable
final class CompletionRequest {
  const CompletionRequest({
    required this.model,
    required this.messages,
    this.tools = const [],
    this.sampling = const InferenceSampling(),
    this.reasoning = const InferenceReasoningDefault(),
    this.stopSequences = const [],
  });

  final String model;

  final List<InferenceMessage> messages;

  final List<InferenceTool> tools;

  final InferenceSampling sampling;

  final InferenceReasoning reasoning;

  final List<String> stopSequences;
}
