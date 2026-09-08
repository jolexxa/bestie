import 'package:inference_protocol/src/models/inference_failure.dart';
import 'package:inference_protocol/src/models/inference_stop_reason.dart';
import 'package:inference_protocol/src/models/inference_tool_call.dart';
import 'package:meta/meta.dart';

/// One item of a streamed chat completion.
@immutable
sealed class InferenceEvent {
  const InferenceEvent();
}

final class InferenceTextDelta extends InferenceEvent {
  const InferenceTextDelta(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is InferenceTextDelta && other.text == text;

  @override
  int get hashCode => Object.hash(InferenceTextDelta, text);

  @override
  String toString() => 'InferenceTextDelta($text)';
}

final class InferenceReasoningDelta extends InferenceEvent {
  const InferenceReasoningDelta(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is InferenceReasoningDelta && other.text == text;

  @override
  int get hashCode => Object.hash(InferenceReasoningDelta, text);

  @override
  String toString() => 'InferenceReasoningDelta($text)';
}

/// The model opened a tool call whose arguments are still streaming. Emitted
/// once per call, ahead of the matching [InferenceToolCallEmitted].
final class InferenceToolCallStarted extends InferenceEvent {
  const InferenceToolCallStarted({required this.name});

  final String name;

  @override
  bool operator ==(Object other) =>
      other is InferenceToolCallStarted && other.name == name;

  @override
  int get hashCode => Object.hash(InferenceToolCallStarted, name);

  @override
  String toString() => 'InferenceToolCallStarted($name)';
}

/// A complete tool call; clients accumulate argument fragments before
/// emitting this.
final class InferenceToolCallEmitted extends InferenceEvent {
  const InferenceToolCallEmitted(this.call);

  final InferenceToolCall call;

  @override
  bool operator ==(Object other) =>
      other is InferenceToolCallEmitted && other.call == call;

  @override
  int get hashCode => call.hashCode;

  @override
  String toString() => 'InferenceToolCallEmitted($call)';
}

final class InferenceUsageReported extends InferenceEvent {
  const InferenceUsageReported({
    required this.promptTokens,
    required this.completionTokens,
    this.cost,
  });

  final int promptTokens;

  final int completionTokens;

  /// What the provider charged for this completion in its own currency
  /// units; null when it does not say.
  final double? cost;

  int get totalTokens => promptTokens + completionTokens;

  @override
  bool operator ==(Object other) =>
      other is InferenceUsageReported &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens &&
      other.cost == cost;

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens, cost);

  @override
  String toString() =>
      'InferenceUsageReported(prompt: $promptTokens, '
      'completion: $completionTokens, cost: $cost)';
}

final class InferenceCompletionFinished extends InferenceEvent {
  const InferenceCompletionFinished(this.reason);

  final InferenceStopReason reason;

  @override
  bool operator ==(Object other) =>
      other is InferenceCompletionFinished && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'InferenceCompletionFinished(${reason.name})';
}

final class InferenceCompletionFailed extends InferenceEvent {
  const InferenceCompletionFailed(this.failure);

  final InferenceFailure failure;

  @override
  bool operator ==(Object other) =>
      other is InferenceCompletionFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'InferenceCompletionFailed($failure)';
}
