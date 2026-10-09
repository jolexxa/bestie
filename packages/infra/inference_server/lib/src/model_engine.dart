import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference_server/src/server_log.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// Builds the engine that loads models, wherever it runs.
// ignore: one_member_abstracts
abstract interface class ModelEngineStarter {
  /// Opens the native backend and whatever the engine needs, reporting to
  /// [log].
  Future<ModelEngineStart> start(ServerLog log);
}

/// Whether an engine could be started.
sealed class ModelEngineStart {
  const ModelEngineStart();
}

final class ModelEngineStarted extends ModelEngineStart {
  const ModelEngineStarted(this.engine);

  final ModelEngine engine;
}

/// No engine could be started.
sealed class ModelEngineUnavailable extends ModelEngineStart {
  const ModelEngineUnavailable({required this.message});

  final String message;
}

/// The native libraries are missing or could not be loaded.
final class ModelEngineLibrariesMissing extends ModelEngineUnavailable {
  const ModelEngineLibrariesMissing({required super.message});
}

/// The libraries loaded, but the engine around them did not start.
final class ModelEngineFailedToStart extends ModelEngineUnavailable {
  const ModelEngineFailedToStart({required super.message});
}

/// Turns a model file into a running completion runtime.
abstract interface class ModelEngine {
  /// Sizes the context to the devices, loads the model, and builds its
  /// runtime, reporting each stage. The stream ends after a loaded or failed
  /// event. Cancelling the subscription abandons the load, and a model that
  /// loads anyway is unloaded.
  Stream<ModelEngineEvent> load(ModelEngineRequest request);

  /// Frees what the engine holds natively. Every loaded model must be
  /// unloaded first.
  Future<void> close();
}

final class ModelEngineRequest {
  const ModelEngineRequest({
    required this.entry,
    required this.maxAgents,
    this.contextCap,
  });

  final ModelIndexEntry entry;

  final int maxAgents;

  /// The largest context to fit, or null to fit up to the trained length.
  final int? contextCap;
}

sealed class ModelEngineEvent {
  const ModelEngineEvent();
}

/// Anything a load reports besides the loaded model itself.
sealed class ModelEngineStep extends ModelEngineEvent {
  const ModelEngineStep();
}

/// The context size the devices can hold was chosen.
final class ModelEngineFitted extends ModelEngineStep {
  const ModelEngineFitted({required this.contextSize});

  final int contextSize;
}

/// The model's weights are loading.
final class ModelEngineProgressed extends ModelEngineStep {
  const ModelEngineProgressed({required this.progress});

  /// From 0 to 1.
  final double progress;
}

final class ModelEngineLoaded extends ModelEngineEvent {
  const ModelEngineLoaded({required this.model});

  final LoadedModel model;
}

final class ModelEngineFailed extends ModelEngineStep {
  const ModelEngineFailed({required this.reason});

  final String reason;
}

/// A model held in memory with a runtime serving completions on it.
abstract interface class LoadedModel {
  CompletionRuntime get runtime;

  /// Device memory the model and its context were predicted to use.
  int get deviceBytes;

  /// Frees the context and the model. The runtime must already be disposed.
  Future<void> unload();
}
