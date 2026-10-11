import 'package:meta/meta.dart';

/// How the runtime drives its model.
@immutable
final class AgentRuntimeOptions {
  const AgentRuntimeOptions({
    required this.modelId,
    required this.contextWindow,
    this.maxAgents = 4,
    this.maxOutputTokens,
    this.summaryMaxOutputTokens = 2048,
  });

  final String modelId;

  /// The model's context length in tokens; drives compaction.
  final int contextWindow;

  final int maxAgents;

  /// Cap on completion tokens per step, or null to let the server decide.
  final int? maxOutputTokens;

  /// Cap on completion tokens when summarizing for compaction.
  final int summaryMaxOutputTokens;
}
