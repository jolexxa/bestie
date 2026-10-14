import 'package:engine_protocol/engine_protocol.dart';
import 'package:engine_templates/engine_templates.dart';

/// One chat completion to run on the loaded model.
final class EngineCompletionRequest {
  const EngineCompletionRequest({
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
sealed class EngineCompletionStart {
  const EngineCompletionStart();
}

/// The completion is queued for the next step. Cancelling the subscription to
/// [events] cancels the completion.
final class EngineCompletionStarted extends EngineCompletionStart {
  const EngineCompletionStarted(this.events);

  final Stream<EngineCompletionEvent> events;
}

final class EngineCompletionRejected extends EngineCompletionStart {
  const EngineCompletionRejected({required this.reason, required this.message});

  final EngineCompletionRejection reason;

  final String message;
}

enum EngineCompletionRejection {
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
sealed class EngineCompletionEvent {
  const EngineCompletionEvent();
}

/// How much of the prompt the sequence holds so far, reported while it is
/// prefilled and once more when it is ready to generate.
final class EngineCompletionPrefillProgressed extends EngineCompletionEvent {
  const EngineCompletionPrefillProgressed({
    required this.total,
    required this.cached,
    required this.processed,
    required this.elapsed,
  });

  /// Prompt tokens the sequence must hold before generating.
  final int total;

  /// Prompt tokens already resident before this completion began.
  final int cached;

  /// Prompt tokens held so far, [cached] ones included.
  final int processed;

  /// Time since the completion started.
  final Duration elapsed;
}

final class EngineCompletionReasoningDelta extends EngineCompletionEvent {
  const EngineCompletionReasoningDelta(this.text, {required this.tokens});

  final String text;

  /// Tokens generated since the previous event that [text] completes.
  final int tokens;
}

final class EngineCompletionTextDelta extends EngineCompletionEvent {
  const EngineCompletionTextDelta(this.text, {required this.tokens});

  final String text;

  /// Tokens generated since the previous event that [text] completes.
  final int tokens;
}

/// A tool call the model made. A call the parser could not read keeps the
/// model's raw text as its arguments, so the caller's tool reports the error
/// back to the model.
final class EngineCompletionToolCalled extends EngineCompletionEvent {
  const EngineCompletionToolCalled({
    required this.id,
    required this.name,
    required this.argumentsJson,
    required this.tokens,
  });

  final String id;

  final String name;

  final String argumentsJson;

  /// Tokens generated since the previous event that this call completes.
  final int tokens;
}

/// The completion ended normally. Always the last event.
final class EngineCompletionFinished extends EngineCompletionEvent {
  const EngineCompletionFinished({required this.reason, required this.usage});

  final EngineCompletionStopReason reason;

  final EngineCompletionUsage usage;
}

/// The completion ended early. Always the last event.
final class EngineCompletionFailed extends EngineCompletionEvent {
  const EngineCompletionFailed({required this.failure, required this.message});

  final EngineCompletionFailure failure;

  final String message;
}

enum EngineCompletionStopReason { stop, length, toolCalls }

enum EngineCompletionFailure {
  /// Subagents claimed the context the prompt needed after it started.
  contextExceeded,

  /// The backend failed a step.
  engineFailed,

  /// The agent's lease was closed, or the runtime shut down.
  cancelled,
}

final class EngineCompletionUsage {
  const EngineCompletionUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.cachedTokens,
    required this.promptTime,
    required this.generationTime,
  });

  final int promptTokens;

  final int completionTokens;

  /// Prompt tokens already resident in the sequence, which were not
  /// prefilled again.
  final int cachedTokens;

  /// Time from the completion starting until its prompt was held.
  final Duration promptTime;

  /// Time from the prompt being held until the completion ended.
  final Duration generationTime;
}
