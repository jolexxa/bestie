import 'package:inference/inference.dart';
import 'package:llm_model_templates/llm_model_templates.dart';

/// One chat completion to run on the loaded model.
final class CompletionRequest {
  const CompletionRequest({
    required this.messages,
    required this.reasoningMode,
    required this.sampling,
    this.agentId,
    this.tools = const [],
    this.maxTokens,
    this.stopSequences = const [],
  });

  /// The leased agent whose sequence runs the completion, or null to borrow a
  /// sequence for this request alone.
  final String? agentId;

  final List<PromptMessage> messages;

  final List<PromptTool> tools;

  /// The mode the profile's formatter renders, e.g. `off` or `high`.
  final String reasoningMode;

  final EngineSampling sampling;

  /// The most tokens to generate, or null to stop only at the end of
  /// generation or the agent's context limit.
  final int? maxTokens;

  /// Text that ends the completion where it first appears. The stop itself
  /// is left out of the answer.
  final List<String> stopSequences;
}

/// Whether a completion could start.
sealed class CompletionStart {
  const CompletionStart();
}

/// The completion is queued for the next step. Cancelling the subscription to
/// [events] cancels the completion.
final class CompletionStarted extends CompletionStart {
  const CompletionStarted(this.events);

  final Stream<CompletionEvent> events;
}

final class CompletionRejected extends CompletionStart {
  const CompletionRejected({required this.reason, required this.message});

  final CompletionRejection reason;

  final String message;
}

enum CompletionRejection {
  /// The request named an agent that holds no lease.
  unknownAgent,

  /// The agent is already running a completion.
  agentBusy,

  /// No sequence could be lent to a request that named no agent.
  noCapacity,

  /// The prompt leaves no room to generate within the agent's limit.
  promptTooLarge,

  /// The prompt could not be tokenized.
  promptUnreadable,

  /// The backend could not take the request.
  engineFailed,

  /// The runtime is shutting down.
  disposed,
}

/// Something a running completion produced.
sealed class CompletionEvent {
  const CompletionEvent();
}

final class CompletionReasoningDelta extends CompletionEvent {
  const CompletionReasoningDelta(this.text);

  final String text;
}

final class CompletionTextDelta extends CompletionEvent {
  const CompletionTextDelta(this.text);

  final String text;
}

/// A tool call the model made. A call the parser could not read keeps the
/// model's raw text as its arguments, so the caller's tool reports the error
/// back to the model.
final class CompletionToolCalled extends CompletionEvent {
  const CompletionToolCalled({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  final String id;

  final String name;

  final String argumentsJson;
}

/// The completion ended normally. Always the last event.
final class CompletionFinished extends CompletionEvent {
  const CompletionFinished({required this.reason, required this.usage});

  final CompletionStopReason reason;

  final CompletionUsage usage;
}

/// The completion ended early. Always the last event.
final class CompletionFailed extends CompletionEvent {
  const CompletionFailed({required this.failure, required this.message});

  final CompletionFailure failure;

  final String message;
}

enum CompletionStopReason { stop, length, toolCalls }

enum CompletionFailure {
  /// Subagents claimed the context the prompt needed after it started.
  contextExceeded,

  /// The backend failed a step.
  engineFailed,

  /// The agent's lease was closed, or the runtime shut down.
  cancelled,
}

final class CompletionUsage {
  const CompletionUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.cachedTokens,
  });

  final int promptTokens;

  final int completionTokens;

  /// Prompt tokens already resident in the sequence, which were not
  /// prefilled again.
  final int cachedTokens;
}
