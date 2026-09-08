import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// Where the model behind a card sits in its lifecycle.
@model
enum ModelCardPhase { loading, ready, failed }

/// Denormalized model snapshot shown as a card in the chat timeline —
/// either a persisted model change or the live status of a model coming up.
@model
@immutable
class ModelSnapshot {
  const ModelSnapshot({
    required this.modelId,
    required this.displayName,
    required this.contextSize,
    required this.provider,
    required this.phase,
    this.progress,
    this.error,
  });

  /// A model served by a hosted provider, ready to run.
  const ModelSnapshot.remote({
    required String modelId,
    required String displayName,
    required int contextSize,
    required String provider,
  }) : this(
         modelId: modelId,
         displayName: displayName,
         contextSize: contextSize,
         provider: provider,
         phase: ModelCardPhase.ready,
       );

  final String modelId;
  final String displayName;

  /// Context size (tokens) the model runs under.
  final int contextSize;

  /// Who serves the model (e.g. `"OpenRouter"`, `"llama.cpp"`).
  final String provider;

  final ModelCardPhase phase;

  /// Progress in `0..1` while [phase] is [ModelCardPhase.loading], when known.
  final double? progress;

  /// What went wrong when [phase] is [ModelCardPhase.failed].
  final String? error;

  @override
  bool operator ==(Object other) =>
      other is ModelSnapshot &&
      other.modelId == modelId &&
      other.displayName == displayName &&
      other.contextSize == contextSize &&
      other.provider == provider &&
      other.phase == phase &&
      other.progress == progress &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    modelId,
    displayName,
    contextSize,
    provider,
    phase,
    progress,
    error,
  );

  @override
  String toString() =>
      'ModelSnapshot(modelId: $modelId, displayName: $displayName, '
      'contextSize: $contextSize, provider: $provider, phase: $phase, '
      'progress: $progress, error: $error)';
}
