import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart';

sealed class RemoteTurnInput {
  const RemoteTurnInput();
}

/// Begin the first step of the turn.
final class StepRequested extends RemoteTurnInput {
  const StepRequested();
}

/// One event from the completion stream tagged [completionId].
final class InferenceEventReceived extends RemoteTurnInput {
  const InferenceEventReceived({
    required this.completionId,
    required this.event,
  });

  final int completionId;
  final InferenceEvent event;
}

final class CompletionStreamEnded extends RemoteTurnInput {
  const CompletionStreamEnded({required this.completionId});

  final int completionId;
}

final class CompletionStreamErrored extends RemoteTurnInput {
  const CompletionStreamErrored({
    required this.completionId,
    required this.error,
  });

  final int completionId;
  final Object error;
}

final class ToolResultsSubmitted extends RemoteTurnInput {
  const ToolResultsSubmitted({required this.entries});

  final List<TranscriptEntry> entries;
}

final class CompactionPromptSubmitted extends RemoteTurnInput {
  const CompactionPromptSubmitted({required this.content});

  final CompactionPromptContent content;
}

final class CancelRequested extends RemoteTurnInput {
  const CancelRequested();
}
