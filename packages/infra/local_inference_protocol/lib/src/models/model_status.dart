import 'package:dart_mappable/dart_mappable.dart';

part 'model_status.mapper.dart';

/// Where the server is in getting a model ready to serve.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'state')
sealed class ModelStatus with ModelStatusMappable {
  const ModelStatus();
}

/// No model is loaded.
@MappableClass(discriminatorValue: 'unloaded')
final class ModelUnloaded extends ModelStatus with ModelUnloadedMappable {
  const ModelUnloaded();
}

/// The server is working out how much context fits on the device.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'fitting')
final class ModelFitting extends ModelStatus with ModelFittingMappable {
  const ModelFitting({required this.localId});

  final String localId;
}

/// The weights are being loaded.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'loading')
final class ModelLoading extends ModelStatus with ModelLoadingMappable {
  const ModelLoading({required this.localId, required this.progress});

  final String localId;

  /// From 0 to 1.
  final double progress;
}

/// The model serves completions.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'ready')
final class ModelReady extends ModelStatus with ModelReadyMappable {
  const ModelReady({
    required this.localId,
    required this.contextSize,
    required this.maxAgents,
    required this.deviceBytes,
  });

  final String localId;

  /// The context the fit settled on, shared by every agent.
  final int contextSize;

  final int maxAgents;

  /// Device memory the loaded model occupies.
  final int deviceBytes;
}

/// The last load did not finish.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'failed')
final class ModelFailed extends ModelStatus with ModelFailedMappable {
  const ModelFailed({required this.localId, required this.reason});

  final String localId;

  final String reason;
}

/// The body of a request to load a model.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class ModelLoadRequest with ModelLoadRequestMappable {
  const ModelLoadRequest({
    required this.localId,
    required this.maxAgents,
    this.contextCap,
  });

  /// The model's id in the model index.
  final String localId;

  final int maxAgents;

  /// The most context to fit, or null to fit as much as the device allows.
  final int? contextCap;
}
