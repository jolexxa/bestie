import 'dart:async';

import 'package:inference_server/src/model_engine.dart';
import 'package:inference_server/src/model_index_reader.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// The model currently serving completions, with the index entry it was
/// loaded from.
final class HostedModel {
  const HostedModel({required this.entry, required this.model});

  final ModelIndexEntry entry;

  final LoadedModel model;
}

/// Holds at most one loaded model. Loads and unloads run one at a time, in
/// the order they were asked for, and a load always unloads the previous
/// model first so two never share memory. One that fails never holds up
/// the ones behind it.
final class ModelHost {
  ModelHost({required ModelEngine engine, required ModelIndexReader index})
    : _engine = engine,
      _index = index;

  final ModelEngine _engine;
  final ModelIndexReader _index;
  final _statusChanges = StreamController<ModelStatus>.broadcast(sync: true);
  Future<void> _lane = Future.value();
  _HostState _state = const _Idle(ModelUnloaded());
  void Function()? _abandonLoad;
  var _disposed = false;

  ModelStatus get status => _state.status;

  Stream<ModelStatus> get statusChanges => _statusChanges.stream;

  HostedModel? get hosted => switch (_state) {
    _Serving(:final hosted) => hosted,
    _Idle() => null,
  };

  Future<ModelLoadOutcome> load(ModelLoadRequest request) =>
      _serially(() => _load(request));

  Future<void> unload() => _serially(_unload);

  /// Abandons a load in flight, unloads the model, and stops reporting
  /// status. The load in flight and the loads still waiting their turn are
  /// interrupted.
  Future<void> dispose() async {
    _disposed = true;
    _abandonLoad?.call();
    await unload();
    await _statusChanges.close();
  }

  Future<T> _serially<T>(Future<T> Function() operation) {
    final result = _lane.then((_) => operation());
    _lane = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<ModelLoadOutcome> _load(ModelLoadRequest request) async {
    if (request.maxAgents < 1) {
      return _invalid('max_agents must be at least 1.');
    }
    if (request.contextCap case final cap? when cap < 1) {
      return _invalid('context_cap must be at least 1.');
    }
    if (_disposed) return const ModelLoadInterrupted();
    final ModelIndexEntry entry;
    switch (await _index.read()) {
      case final ModelIndexRead read:
        final found = read.entryFor(request.localId);
        if (found == null) return _unknownModel(request.localId);
        entry = found;
      case ModelIndexMissing():
        return _unknownModel(request.localId);
      case ModelIndexMalformed(:final message):
        return ModelLoadRejected(
          reason: ModelLoadRejection.indexUnreadable,
          message: message,
        );
    }

    await _unload();
    _publish(_Idle(ModelFitting(localId: entry.localId)));
    return _follow(
      entry,
      ModelEngineRequest(
        entry: entry,
        maxAgents: request.maxAgents,
        contextCap: request.contextCap,
      ),
    );
  }

  /// Follows the engine's load until it settles or is abandoned.
  Future<ModelLoadOutcome> _follow(
    ModelIndexEntry entry,
    ModelEngineRequest request,
  ) {
    final outcome = Completer<ModelLoadOutcome>();
    late final StreamSubscription<ModelEngineEvent> events;
    void settle(ModelLoadOutcome Function() result) {
      if (outcome.isCompleted) return;
      _abandonLoad = null;
      unawaited(events.cancel());
      outcome.complete(result());
    }

    events = Stream.fromFuture(Future.sync(() => _engine.load(request)))
        .asyncExpand((events) => events)
        .listen(
          (event) => switch (event) {
            ModelEngineFitted() => _publish(
              _Idle(ModelLoading(localId: entry.localId, progress: 0)),
            ),
            ModelEngineProgressed(:final progress) => _progressed(
              entry,
              progress,
            ),
            ModelEngineLoaded(:final model) => settle(
              () => _ready(entry, model),
            ),
            ModelEngineFailed(:final reason) => settle(
              () => _failed(entry, reason),
            ),
          },
          onError: (Object error) => settle(() => _failed(entry, '$error')),
          onDone: () => settle(
            () => _failed(
              entry,
              'The engine stopped before the model loaded.',
            ),
          ),
        );
    _abandonLoad = () => settle(_interrupted);
    return outcome.future;
  }

  void _progressed(ModelIndexEntry entry, double progress) {
    if (_percent(progress) <= _percent(_loadingProgress)) return;
    _publish(_Idle(ModelLoading(localId: entry.localId, progress: progress)));
  }

  static ModelLoadOutcome _invalid(String message) => ModelLoadRejected(
    reason: ModelLoadRejection.invalidRequest,
    message: message,
  );

  ModelLoadOutcome _unknownModel(String localId) => ModelLoadRejected(
    reason: ModelLoadRejection.unknownModel,
    message: 'No installed model has the id $localId.',
  );

  ModelLoadOutcome _ready(ModelIndexEntry entry, LoadedModel model) {
    final ready = ModelReady(
      localId: entry.localId,
      contextSize: model.runtime.contextSize,
      maxAgents: model.runtime.maxAgents,
      deviceBytes: model.deviceBytes,
    );
    _publish(_Serving(ready, HostedModel(entry: entry, model: model)));
    return ModelLoadSucceeded(ready);
  }

  ModelLoadOutcome _interrupted() {
    _publish(const _Idle(ModelUnloaded()));
    return const ModelLoadInterrupted();
  }

  ModelLoadOutcome _failed(ModelIndexEntry entry, String reason) {
    _publish(_Idle(ModelFailed(localId: entry.localId, reason: reason)));
    return ModelLoadFailed(reason: reason);
  }

  Future<void> _unload() async {
    final hosted = this.hosted;
    if (hosted == null) return;
    _publish(const _Idle(ModelUnloaded()));
    await hosted.model.runtime.dispose();
    await hosted.model.unload();
  }

  double get _loadingProgress => switch (_state.status) {
    ModelLoading(:final progress) => progress,
    _ => 0,
  };

  /// Whole percent, so loading reports at most a hundred steps.
  static int _percent(double progress) => (progress * 100).floor();

  void _publish(_HostState state) {
    _state = state;
    if (!_statusChanges.isClosed) _statusChanges.add(state.status);
  }
}

/// What the host holds, and the status it reports for it.
sealed class _HostState {
  const _HostState(this.status);

  final ModelStatus status;
}

/// No model serves completions: none is loaded, one is on its way, or the
/// last one failed.
final class _Idle extends _HostState {
  const _Idle(super.status);
}

final class _Serving extends _HostState {
  const _Serving(ModelReady super.status, this.hosted);

  final HostedModel hosted;
}

sealed class ModelLoadOutcome {
  const ModelLoadOutcome();
}

final class ModelLoadSucceeded extends ModelLoadOutcome {
  const ModelLoadSucceeded(this.ready);

  final ModelReady ready;
}

/// The load was refused before anything was unloaded.
final class ModelLoadRejected extends ModelLoadOutcome {
  const ModelLoadRejected({required this.reason, required this.message});

  final ModelLoadRejection reason;

  final String message;
}

enum ModelLoadRejection { invalidRequest, unknownModel, indexUnreadable }

/// The previous model was unloaded, but this one could not be loaded.
final class ModelLoadFailed extends ModelLoadOutcome {
  const ModelLoadFailed({required this.reason});

  final String reason;
}

/// The host shut down before the model loaded.
final class ModelLoadInterrupted extends ModelLoadOutcome {
  const ModelLoadInterrupted();
}
