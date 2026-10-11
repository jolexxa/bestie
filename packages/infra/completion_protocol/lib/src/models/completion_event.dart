import 'package:completion_protocol/src/models/completion_failure.dart';
import 'package:completion_protocol/src/models/completion_stop_reason.dart';
import 'package:completion_protocol/src/models/completion_tool_call.dart';
import 'package:meta/meta.dart';

/// One item of a streamed chat completion.
@immutable
sealed class CompletionEvent {
  const CompletionEvent();
}

final class CompletionTextDelta extends CompletionEvent {
  const CompletionTextDelta(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is CompletionTextDelta && other.text == text;

  @override
  int get hashCode => Object.hash(CompletionTextDelta, text);

  @override
  String toString() => 'CompletionTextDelta($text)';
}

final class CompletionReasoningDelta extends CompletionEvent {
  const CompletionReasoningDelta(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is CompletionReasoningDelta && other.text == text;

  @override
  int get hashCode => Object.hash(CompletionReasoningDelta, text);

  @override
  String toString() => 'CompletionReasoningDelta($text)';
}

/// The model opened a tool call whose arguments are still streaming. Emitted
/// once per call, ahead of the matching [CompletionToolCallEmitted].
final class CompletionToolCallStarted extends CompletionEvent {
  const CompletionToolCallStarted({required this.name});

  final String name;

  @override
  bool operator ==(Object other) =>
      other is CompletionToolCallStarted && other.name == name;

  @override
  int get hashCode => Object.hash(CompletionToolCallStarted, name);

  @override
  String toString() => 'CompletionToolCallStarted($name)';
}

/// A complete tool call; clients accumulate argument fragments before
/// emitting this.
final class CompletionToolCallEmitted extends CompletionEvent {
  const CompletionToolCallEmitted(this.call);

  final CompletionToolCall call;

  @override
  bool operator ==(Object other) =>
      other is CompletionToolCallEmitted && other.call == call;

  @override
  int get hashCode => call.hashCode;

  @override
  String toString() => 'CompletionToolCallEmitted($call)';
}

final class CompletionUsageReported extends CompletionEvent {
  const CompletionUsageReported({
    required this.promptTokens,
    required this.completionTokens,
    this.reasoningTokens,
    this.cost,
  });

  final int promptTokens;

  final int completionTokens;

  /// How many of [completionTokens] went to reasoning, streamed or not;
  /// null when the provider does not say.
  final int? reasoningTokens;

  /// What the provider charged for this completion in its own currency
  /// units; null when it does not say.
  final double? cost;

  int get totalTokens => promptTokens + completionTokens;

  @override
  bool operator ==(Object other) =>
      other is CompletionUsageReported &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens &&
      other.reasoningTokens == reasoningTokens &&
      other.cost == cost;

  @override
  int get hashCode =>
      Object.hash(promptTokens, completionTokens, reasoningTokens, cost);

  @override
  String toString() =>
      'CompletionUsageReported(prompt: $promptTokens, '
      'completion: $completionTokens, reasoning: $reasoningTokens, '
      'cost: $cost)';
}

final class CompletionFinished extends CompletionEvent {
  const CompletionFinished(this.reason);

  final CompletionStopReason reason;

  @override
  bool operator ==(Object other) =>
      other is CompletionFinished && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'CompletionFinished(${reason.name})';
}

final class CompletionFailed extends CompletionEvent {
  const CompletionFailed(this.failure);

  final CompletionFailure failure;

  @override
  bool operator ==(Object other) =>
      other is CompletionFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'CompletionFailed($failure)';
}
