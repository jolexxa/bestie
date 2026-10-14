import 'package:meta/meta.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_model.dart';

/// A model on its way to serving completions.
final class ProviderModelLoad {
  const ProviderModelLoad({required this.progress, required this.result});

  /// A load that is over before it starts, as for hosted models.
  ProviderModelLoad.settled(ProviderModelLoadResult settled)
    : progress = const Stream.empty(),
      result = Future.value(settled);

  /// How far along the load is. Ends when [result] completes.
  final Stream<ProviderModelLoadProgress> progress;

  /// How the load ended. Never completes with an error.
  final Future<ProviderModelLoadResult> result;
}

/// How far a model is from serving.
@immutable
sealed class ProviderModelLoadProgress {
  const ProviderModelLoadProgress();
}

/// Working out how much context fits before loading begins.
final class ProviderModelMeasuring extends ProviderModelLoadProgress {
  const ProviderModelMeasuring();

  @override
  bool operator ==(Object other) => other is ProviderModelMeasuring;

  @override
  int get hashCode => (ProviderModelMeasuring).hashCode;
}

/// Loading the model, [fraction] of the way from 0 to 1.
final class ProviderModelLoading extends ProviderModelLoadProgress {
  const ProviderModelLoading(this.fraction);

  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is ProviderModelLoading && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;
}

/// How getting a model ready ended.
sealed class ProviderModelLoadResult {
  const ProviderModelLoadResult();
}

/// The model serves completions.
final class ProviderModelLoaded extends ProviderModelLoadResult {
  const ProviderModelLoaded(this.model);

  final ProviderModel model;
}

/// The model cannot serve completions.
final class ProviderModelLoadFailed extends ProviderModelLoadResult {
  const ProviderModelLoadFailed(this.failure);

  final ProviderFailure failure;
}
