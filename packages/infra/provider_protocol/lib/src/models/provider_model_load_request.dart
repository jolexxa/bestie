import 'package:meta/meta.dart';

/// What a provider is told when one of its models is chosen to run.
@immutable
final class ProviderModelLoadRequest {
  const ProviderModelLoadRequest({
    required this.modelId,
    required this.contextWindow,
    required this.maxAgents,
  });

  final String modelId;

  /// The context the provider's listing gives the model.
  final int contextWindow;

  /// The most agents that will run on the model at once.
  final int maxAgents;

  @override
  bool operator ==(Object other) =>
      other is ProviderModelLoadRequest &&
      other.modelId == modelId &&
      other.contextWindow == contextWindow &&
      other.maxAgents == maxAgents;

  @override
  int get hashCode => Object.hash(modelId, contextWindow, maxAgents);
}
