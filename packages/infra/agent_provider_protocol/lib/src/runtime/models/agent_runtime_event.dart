import 'package:agent_provider_protocol/src/runtime/models/agent_handle.dart';
import 'package:agent_provider_protocol/src/runtime/models/agent_run_failure_reason.dart';
import 'package:agent_provider_protocol/src/runtime/models/context_pool_snapshot.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_entry.dart';
import 'package:agent_provider_protocol/src/transcript/models/transcript_id.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Anything the runtime emits on its flat event stream, stamped inside the
/// agent isolate.
abstract class RuntimeEvent {
  const RuntimeEvent({required this.timestamp});

  /// The instant this event was produced, stamped inside the agent isolate.
  final DateTime timestamp;
}

/// An agent runtime event.
abstract class AgentRuntimeEvent extends RuntimeEvent {
  const AgentRuntimeEvent({required super.timestamp});

  /// The agent this event belongs to.
  AgentHandle get agent;
}

/// A runtime event owned by no single agent.
abstract class GlobalRuntimeEvent extends RuntimeEvent {
  const GlobalRuntimeEvent({required super.timestamp});
}

/// The shared KV pool's occupancy changed. Carries a whole snapshot rather than
/// a delta so any observer reads the current truth without replaying history.
final class PoolStateChanged extends GlobalRuntimeEvent {
  const PoolStateChanged({required super.timestamp, required this.snapshot});

  final ContextPoolSnapshot snapshot;
}

abstract class AgentProviderEvent extends AgentRuntimeEvent {
  const AgentProviderEvent({required super.timestamp});
}

final class AgentStarted extends AgentProviderEvent {
  const AgentStarted({
    required super.timestamp,
    required this.agent,
    required this.transcript,
  });

  final AgentHandle agent;
  final Transcript transcript;
}

/// Decode is about to begin for the step whose deltas will carry [entryId].
final class AgentStepStarted extends AgentProviderEvent {
  const AgentStepStarted({
    required super.timestamp,
    required this.agent,
    required this.entryId,
  });

  final AgentHandle agent;
  final TranscriptEntryId entryId;
}

abstract class AgentDeltaEvent extends AgentProviderEvent {
  const AgentDeltaEvent({
    required super.timestamp,
    required this.agent,
    required this.entryId,
    required this.blockId,
  });

  final AgentHandle agent;
  final TranscriptEntryId entryId;
  final TranscriptBlockId blockId;
}

final class AgentTextDelta extends AgentDeltaEvent {
  const AgentTextDelta({
    required super.timestamp,
    required super.agent,
    required super.entryId,
    required super.blockId,
    required this.text,
  });

  final String text;
}

final class AgentReasoningDelta extends AgentDeltaEvent {
  const AgentReasoningDelta({
    required super.timestamp,
    required super.agent,
    required super.entryId,
    required super.blockId,
    required this.text,
  });

  final String text;
}

/// The model opened a tool call in the step being streamed. Its arguments are
/// still arriving, so no block exists for it yet; [AgentToolCallEmitted]
/// follows once the call is whole.
final class AgentToolCallStarted extends AgentProviderEvent {
  const AgentToolCallStarted({
    required super.timestamp,
    required this.agent,
    required this.name,
  });

  final AgentHandle agent;
  final String name;
}

/// A complete tool call landed in the step being streamed.
final class AgentToolCallEmitted extends AgentDeltaEvent {
  const AgentToolCallEmitted({
    required super.timestamp,
    required super.agent,
    required super.entryId,
    required super.blockId,
    required this.toolCall,
  });

  final ToolCall toolCall;
}

final class AgentNeedsToolResults extends AgentProviderEvent {
  const AgentNeedsToolResults({
    required super.timestamp,
    required this.agent,
    required this.entry,
    required this.toolCalls,
  });

  final AgentHandle agent;
  final TranscriptEntry entry;
  final List<ToolCall> toolCalls;
}

/// The agent's compaction has triggered and decode is paused at its claim
/// boundary while it waits for the compaction prompt to come back.
final class AgentNeedsCompactionPrompt extends AgentProviderEvent {
  const AgentNeedsCompactionPrompt({
    required super.timestamp,
    required this.agent,
  });

  final AgentHandle agent;
}

final class AgentToolResponseApplied extends AgentDeltaEvent {
  const AgentToolResponseApplied({
    required super.timestamp,
    required super.agent,
    required super.entryId,
    required super.blockId,
    required this.response,
  });

  final ToolCallResponse response;
}

final class AgentUpdated extends AgentProviderEvent {
  const AgentUpdated({
    required super.timestamp,
    required this.agent,
    required this.transcript,
  });

  final AgentHandle agent;
  final Transcript transcript;
}

final class AgentCompleted extends AgentProviderEvent {
  const AgentCompleted({
    required super.timestamp,
    required this.agent,
    required this.transcript,
    this.report,
  });

  final AgentHandle agent;
  final Transcript transcript;
  final String? report;
}

final class AgentCancelled extends AgentProviderEvent {
  const AgentCancelled({
    required super.timestamp,
    required this.agent,
    required this.transcript,
  });

  final AgentHandle agent;
  final Transcript transcript;
}

final class AgentEnded extends AgentProviderEvent {
  const AgentEnded({required super.timestamp, required this.agent});

  final AgentHandle agent;
}

final class AgentFailed extends AgentProviderEvent {
  const AgentFailed({
    required super.timestamp,
    required this.agent,
    required this.reason,
    this.message,
  });

  final AgentHandle agent;
  final AgentRunFailureReason reason;
  final String? message;
}

/// What one agent's usage check saw, sampled on its own decode clock when it
/// asks the scheduler where it stands.
final class AgentTelemetry {
  const AgentTelemetry({
    required this.compactAtLimit,
    this.generatedTokens = 0,
  });

  /// The token threshold at which this agent's next turn compacts.
  final int compactAtLimit;

  /// Tokens this agent has decoded this turn.
  final int generatedTokens;
}

final class AgentTelemetryUpdated extends AgentProviderEvent {
  const AgentTelemetryUpdated({
    required super.timestamp,
    required this.agent,
    required this.telemetry,
  });

  final AgentHandle agent;
  final AgentTelemetry telemetry;
}

final class AgentSummaryDelta extends AgentProviderEvent {
  const AgentSummaryDelta({
    required super.timestamp,
    required this.agent,
    required this.text,
  });

  final AgentHandle agent;
  final String text;
}

final class AgentSummaryReasoningDelta extends AgentProviderEvent {
  const AgentSummaryReasoningDelta({
    required super.timestamp,
    required this.agent,
    required this.text,
  });

  final AgentHandle agent;
  final String text;
}

final class AgentCompactionStarted extends AgentProviderEvent {
  const AgentCompactionStarted({
    required super.timestamp,
    required this.agent,
    required this.tokensBefore,
    required this.compactAt,
    required this.contextSize,
  });

  final AgentHandle agent;

  /// Used tokens at the moment compaction was triggered — the prefix cost that
  /// this pass folds into rolling memory.
  final int tokensBefore;

  /// The token threshold that triggered this compaction.
  final int compactAt;

  /// Full context window size.
  final int contextSize;
}

/// The outcome of a compaction pass: rolled a new summary into memory, or
/// didn't.
sealed class AgentCompactionOutcome {
  const AgentCompactionOutcome();
}

final class AgentCompactionSucceeded extends AgentCompactionOutcome {
  const AgentCompactionSucceeded({
    required this.summary,
    required this.tokensAfter,
  });

  final String summary;

  /// Token count of the rolling context after folding the summary in.
  final int tokensAfter;
}

final class AgentCompactionFailed extends AgentCompactionOutcome {
  const AgentCompactionFailed({required this.reason, this.message});

  /// A short, stable failure slug (e.g. "sampleFailed", "rateLimited").
  final String reason;
  final String? message;
}

final class AgentCompactionCompleted extends AgentProviderEvent {
  const AgentCompactionCompleted({
    required super.timestamp,
    required this.agent,
    required this.outcome,
  });

  final AgentHandle agent;
  final AgentCompactionOutcome outcome;
}

/// One slice of a turn's prompt reaching the model: how far along it got.
///
/// Providers that prefill locally report this as their prompt lands; hosted
/// providers never emit it.
class AgentPrefillProgress extends AgentRuntimeEvent {
  const AgentPrefillProgress({
    required super.timestamp,
    required this.agent,
    required this.completed,
    required this.total,
  });

  @override
  final AgentHandle agent;

  /// The position this turn's prompt now reaches.
  final int completed;

  /// Total prompt tokens to prefill for this turn.
  final int total;
}
