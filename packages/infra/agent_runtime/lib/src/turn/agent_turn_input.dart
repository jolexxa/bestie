import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';

sealed class AgentTurnInput {
  const AgentTurnInput();
}

/// Begin the first step of the turn.
final class StepRequested extends AgentTurnInput {
  const StepRequested();
}

/// One event from the completion stream tagged [completionId].
final class CompletionEventReceived extends AgentTurnInput {
  const CompletionEventReceived({
    required this.completionId,
    required this.event,
  });

  final int completionId;
  final CompletionEvent event;
}

final class CompletionStreamEnded extends AgentTurnInput {
  const CompletionStreamEnded({required this.completionId});

  final int completionId;
}

final class CompletionStreamErrored extends AgentTurnInput {
  const CompletionStreamErrored({
    required this.completionId,
    required this.error,
  });

  final int completionId;
  final Object error;
}

final class ToolResultsSubmitted extends AgentTurnInput {
  const ToolResultsSubmitted({required this.entries});

  final List<TranscriptEntry> entries;
}

final class CompactionPromptSubmitted extends AgentTurnInput {
  const CompactionPromptSubmitted({required this.content});

  final CompactionPromptContent content;
}

final class CancelRequested extends AgentTurnInput {
  const CancelRequested();
}
