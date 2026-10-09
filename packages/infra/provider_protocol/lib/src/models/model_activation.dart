import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart'
    show InferenceEndpoint, InferenceProtocolId;
import 'package:meta/meta.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';

/// What a provider is told when one of its models is chosen to run.
@immutable
final class ModelActivationRequest {
  const ModelActivationRequest({
    required this.modelId,
    required this.contextWindow,
    required this.maxAgents,
    this.protocol = InferenceProtocolId.openAiCompat,
  });

  final String modelId;

  /// The context the provider's listing gives the model.
  final int contextWindow;

  /// The most agents that will run on the model at once.
  final int maxAgents;

  /// The protocol completions on the activated model will speak.
  final InferenceProtocolId protocol;

  @override
  bool operator ==(Object other) =>
      other is ModelActivationRequest &&
      other.modelId == modelId &&
      other.contextWindow == contextWindow &&
      other.maxAgents == maxAgents &&
      other.protocol == protocol;

  @override
  int get hashCode => Object.hash(modelId, contextWindow, maxAgents, protocol);
}

/// A model on its way to serving completions.
final class ModelActivation {
  ModelActivation({
    required this.progress,
    required this.result,
    Future<void>? lost,
  }) : lost = lost ?? Completer<void>().future;

  /// How much of the model is ready, from 0 to 1, for providers that load
  /// models before serving them. Ends when [result] completes.
  final Stream<double> progress;

  /// How the activation ended. Never completes with an error.
  final Future<ModelActivationResult> result;

  /// Completes once the activated model stops being served, as when the
  /// server it ran on went away, so it must be activated again. Never
  /// completes for models that are always served, and never with an error.
  final Future<void> lost;
}

/// How getting a model ready ended.
sealed class ModelActivationResult {
  const ModelActivationResult();
}

/// The model serves completions.
@immutable
final class ModelActivated extends ModelActivationResult {
  const ModelActivated({required this.contextWindow, required this.endpoint});

  /// The context the model actually runs with, shared by every agent.
  final int contextWindow;

  /// Where completions on the model are served, in the requested protocol.
  final InferenceEndpoint endpoint;

  @override
  bool operator ==(Object other) =>
      other is ModelActivated &&
      other.contextWindow == contextWindow &&
      other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(contextWindow, endpoint);
}

/// The model cannot serve completions.
@immutable
final class ModelActivationFailed extends ModelActivationResult {
  const ModelActivationFailed(this.failure);

  final ProviderFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ModelActivationFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
