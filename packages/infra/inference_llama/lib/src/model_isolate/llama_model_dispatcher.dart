import 'package:inference_llama/src/model_isolate/llama_model_events.dart';
import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/native/best_fit_client.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:isolate_worker/isolate_worker.dart';

/// Owns the weights loaded in the model isolate and answers its requests.
///
/// Identical loads share one native model, reference-counted until the last
/// holder disposes it.
final class LlamaModelDispatcher {
  LlamaModelDispatcher({
    required LlamaClientApi client,
    required BestFitApi fit,
  }) : _client = client,
       _fit = fit;

  final LlamaClientApi _client;
  final BestFitApi _fit;
  final Map<int, _LoadedModel> _models = {};
  final Map<String, int> _modelIdsByKey = {};
  var _nextModelId = 1;

  /// Answers [request], reporting progress to [events]. A native failure
  /// becomes the request's failed response.
  LlamaModelResponse handle(
    LlamaModelRequest request, {
    required IsolateEventSink events,
  }) {
    try {
      return switch (request) {
        LoadLlamaModel() => LoadLlamaModelResponded(_load(request, events)),
        DisposeLlamaModel() => DisposeLlamaModelResponded(_dispose(request)),
        DisposeAllLlamaModels() => DisposeAllLlamaModelsResponded(
          _disposeAll(),
        ),
        GetLlamaDeviceInfo() => GetLlamaDeviceInfoResponded(
          GetLlamaDeviceInfoSucceeded(_client.getDeviceInfo()),
        ),
        FitMaxLlamaModel() => FitMaxLlamaModelResponded(_fitMax(request)),
      };
    } on Object catch (error, stackTrace) {
      return failedLlamaModelResponse(request, '$error', '$stackTrace');
    }
  }

  FitMaxLlamaModelResponse _fitMax(FitMaxLlamaModel request) {
    return FitMaxLlamaModelSucceeded(
      _fit.fitMaxContext(
        modelPath: request.path,
        modelOptions: request.options,
        contextOptions: request.contextOptions,
        minContextSize: request.minContextSize,
        maxContextSize: request.maxContextSize,
        headroomBytesByDevice: request.headroomBytesByDevice,
      ),
    );
  }

  LoadLlamaModelResponse _load(
    LoadLlamaModel request,
    IsolateEventSink events,
  ) {
    void progressed(double fraction) => events.emit(
      LlamaModelLoadProgressed(
        requestId: request.requestId,
        fraction: fraction,
      ),
    );

    final key = _identityKey(request.path, request.options);
    final existingId = _modelIdsByKey[key];
    if (existingId != null) {
      final existing = _models[existingId]!..refCount += 1;
      progressed(1);
      return LoadLlamaModelSucceeded(
        modelId: existingId,
        modelAddress: existing.handle.pointerAddress,
      );
    }

    var last = 0.0;
    progressed(0);
    final result = _client.loadModel(
      modelPath: request.path,
      modelOptions: request.options,
      onProgress: (progress) {
        final clamped = progress.clamp(0.0, 1.0);
        if (clamped <= last || clamped >= 1.0) return;
        last = clamped;
        progressed(clamped);
      },
    );
    switch (result) {
      case LlamaClientLoadModelSucceeded(:final handle):
        progressed(1);
        final modelId = _nextModelId++;
        _models[modelId] = _LoadedModel(handle: handle, key: key);
        _modelIdsByKey[key] = modelId;
        return LoadLlamaModelSucceeded(
          modelId: modelId,
          modelAddress: handle.pointerAddress,
        );
      case LlamaClientLoadModelFailed(:final message, :final stackTrace):
        return LoadLlamaModelFailed(message: message, stackTrace: stackTrace);
    }
  }

  DisposeLlamaModelResponse _dispose(DisposeLlamaModel request) {
    final model = _models[request.modelId];
    if (model == null) return const DisposeLlamaModelSucceeded();
    if (model.refCount > 1) {
      model.refCount -= 1;
      return const DisposeLlamaModelSucceeded();
    }
    _free(request.modelId, model);
    return const DisposeLlamaModelSucceeded();
  }

  DisposeAllLlamaModelsResponse _disposeAll() {
    final held = _models.entries.toList();
    for (final entry in held) {
      _free(entry.key, entry.value);
    }
    return DisposeAllLlamaModelsSucceeded(disposedCount: held.length);
  }

  // Frees before forgetting, so a throwing free leaves the model held and a
  // retry can still reach it.
  void _free(int modelId, _LoadedModel model) {
    _client.disposeModel(model.handle);
    _models.remove(modelId);
    _modelIdsByKey.remove(model.key);
  }

  static String _identityKey(String path, LlamaModelOptions options) =>
      '$path|${options.nGpuLayers}|${options.mainGpu}|${options.numa}'
      '|${options.loadMode}|${options.checkTensors}';
}

final class _LoadedModel {
  _LoadedModel({required this.handle, required this.key});

  final LlamaModelHandle handle;
  final String key;
  int refCount = 1;
}
