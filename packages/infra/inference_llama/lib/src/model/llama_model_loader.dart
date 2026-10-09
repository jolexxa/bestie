import 'dart:async';
import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context.dart';
import 'package:inference_llama/src/context/llama_context_engine.dart';
import 'package:inference_llama/src/model_isolate/llama_model_events.dart';
import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/model_isolate/llama_model_worker.dart';
import 'package:inference_llama/src/models.dart';
import 'package:inference_llama/src/native/llama_backend.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:isolate_worker/isolate_worker.dart';

/// Loads model weights in a dedicated model isolate and hands back models
/// whose contexts run in this isolate.
class LlamaModelLoader {
  /// Creates a loader over a running [worker]. [client] is this isolate's
  /// native client, which tokenizes and builds contexts.
  LlamaModelLoader({
    required LlamaModelWorker worker,
    required LlamaClientApi client,
  }) : _worker = worker,
       _client = client;

  /// Spawns the model isolate for [backend]'s configuration and builds a
  /// loader that uses [backend] in this isolate.
  static Future<LlamaSpawnModelLoaderResult> spawn(
    LlamaBackend backend, {
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
  }) async {
    final created = await LlamaModelIsolateWorker.spawn(
      configuration: backend.configuration,
      isolateSpawner: isolateSpawner,
    );
    return switch (created) {
      LlamaModelWorkerCreateSucceeded(:final worker) =>
        LlamaSpawnModelLoaderSucceeded(
          LlamaModelLoader(worker: worker, client: backend.client),
        ),
      LlamaModelWorkerCreateFailed(:final message, :final stackTrace) =>
        LlamaSpawnModelLoaderFailed(message: message, stackTrace: stackTrace),
    };
  }

  final LlamaModelWorker _worker;
  final LlamaClientApi _client;
  final _live = <LlamaModel>{};
  var _nextRequestId = 0;
  var _closed = false;

  /// Loads [request]'s weights, reporting load completion in `[0, 1]` to
  /// [onProgress].
  Future<LlamaLoadModelResult> load(
    LlamaModelLoadRequest request, {
    void Function(double fraction)? onProgress,
  }) async {
    final requestId = _nextRequestId++;
    final subscription = _worker.events
        .where((event) => event.requestId == requestId)
        .listen((event) {
          switch (event) {
            case LlamaModelLoadProgressed(:final fraction):
              onProgress?.call(fraction);
          }
        });
    try {
      final response = await _worker.send(
        LoadLlamaModel(
          requestId: requestId,
          path: request.path,
          options: request.options,
        ),
      );
      return _loaded(response);
    } finally {
      await subscription.cancel();
    }
  }

  /// Reads per-device memory info.
  Future<LlamaDeviceInfoResult> getDeviceInfo() async {
    final response = await _worker.send(const GetLlamaDeviceInfo());
    return switch (response) {
      GetLlamaDeviceInfoResponded(
        response: GetLlamaDeviceInfoSucceeded(:final devices),
      ) =>
        LlamaDeviceInfoSucceeded(devices),
      GetLlamaDeviceInfoResponded(
        response: GetLlamaDeviceInfoFailed(:final message, :final stackTrace),
      ) =>
        LlamaDeviceInfoFailed(message: message, stackTrace: stackTrace),
      _ => const LlamaDeviceInfoFailed(
        message: _unexpectedResponse,
        stackTrace: '',
      ),
    };
  }

  /// Predicts the largest fitting context size.
  Future<LlamaFitMaxContextResult> fitMaxContext(
    LlamaFitMaxContextRequest request,
  ) async {
    final response = await _worker.send(
      FitMaxLlamaModel(
        path: request.path,
        options: request.options,
        contextOptions: request.contextOptions,
        minContextSize: request.minContextSize,
        maxContextSize: request.maxContextSize,
        headroomBytesByDevice: request.headroomBytesByDevice,
      ),
    );
    return switch (response) {
      FitMaxLlamaModelResponded(
        response: FitMaxLlamaModelSucceeded(:final result),
      ) =>
        LlamaFitMaxContextSucceeded(result),
      FitMaxLlamaModelResponded(
        response: FitMaxLlamaModelFailed(:final message, :final stackTrace),
      ) =>
        LlamaFitMaxContextFailed(message: message, stackTrace: stackTrace),
      _ => const LlamaFitMaxContextFailed(
        message: _unexpectedResponse,
        stackTrace: '',
      ),
    };
  }

  /// Frees whatever the model isolate still holds and shuts it down.
  ///
  /// Refused while any model this loader handed out is undisposed: its
  /// contexts may still be reading the weights.
  Future<LlamaModelLoaderCloseResult> close() async {
    if (_closed) return const LlamaModelLoaderClosed();
    if (_live.isNotEmpty) {
      return LlamaModelLoaderCloseRefused(liveModels: _live.length);
    }
    _closed = true;
    await _worker.send(const DisposeAllLlamaModels());
    await _worker.close();
    return const LlamaModelLoaderClosed();
  }

  LlamaLoadModelResult _loaded(LlamaModelResponse response) {
    switch (response) {
      case LoadLlamaModelResponded(
        response: LoadLlamaModelSucceeded(:final modelId, :final modelAddress),
      ):
        final model = LlamaModel._(
          worker: _worker,
          client: _client,
          live: _live,
          modelId: modelId,
          handle: _client.modelHandleFromPointer(modelAddress),
        );
        _live.add(model);
        return LlamaLoadModelSucceeded(model);
      case LoadLlamaModelResponded(
        response: LoadLlamaModelFailed(:final message, :final stackTrace),
      ):
        return LlamaLoadModelFailed(message: message, stackTrace: stackTrace);
      default:
        return const LlamaLoadModelFailed(
          message: _unexpectedResponse,
          stackTrace: '',
        );
    }
  }
}

const _unexpectedResponse = 'Unexpected model worker response.';

/// Weights loaded in the model isolate, used from this one.
class LlamaModel implements Model {
  LlamaModel._({
    required LlamaModelWorker worker,
    required LlamaClientApi client,
    required Set<LlamaModel> live,
    required int modelId,
    required LlamaModelHandle handle,
  }) : _worker = worker,
       _client = client,
       _live = live,
       _modelId = modelId,
       _handle = handle,
       tokenizer = LlamaTokenization(client: client, model: handle);

  final LlamaModelWorker _worker;
  final LlamaClientApi _client;
  final Set<LlamaModel> _live;
  final int _modelId;
  final LlamaModelHandle _handle;
  var _disposed = false;

  @override
  final LlamaTokenization tokenizer;

  Future<LlamaCreateContextResult> createContext(
    LlamaCreateContextRequest request,
  ) async {
    if (_disposed) {
      return const LlamaCreateContextFailed(
        message: 'LlamaModel is disposed.',
        stackTrace: '',
      );
    }
    try {
      switch (_client.createContext(_handle, request.options)) {
        case LlamaClientCreateContextSucceeded(:final context):
          final envelope = _client.readEnvelope(context);
          return LlamaCreateContextSucceeded(
            LlamaContext(
              engine: LlamaContextEngine(
                client: _client,
                model: _handle,
                context: context,
                envelope: envelope,
              ),
              envelope: envelope,
            ),
          );
        case LlamaClientCreateContextFailed(:final message, :final stackTrace):
          return LlamaCreateContextFailed(
            message: message,
            stackTrace: stackTrace,
          );
      }
    } on Object catch (error, stackTrace) {
      return LlamaCreateContextFailed(
        message: '$error',
        stackTrace: '$stackTrace',
      );
    }
  }

  @override
  Future<DisposeModelResult> dispose() async {
    if (_disposed) return const ModelDisposed();
    final response = await _worker.send(DisposeLlamaModel(_modelId));
    switch (response) {
      case DisposeLlamaModelResponded(response: DisposeLlamaModelSucceeded()):
        _disposed = true;
        _live.remove(this);
        return const ModelDisposed();
      case DisposeLlamaModelResponded(
        response: DisposeLlamaModelFailed(:final message, :final stackTrace),
      ):
        return DisposeModelFailed(message: message, stackTrace: stackTrace);
      default:
        return const DisposeModelFailed(
          message: _unexpectedResponse,
          stackTrace: '',
        );
    }
  }
}

final class LlamaTokenization implements Detokenizer {
  const LlamaTokenization({
    required LlamaClientApi client,
    required LlamaModelHandle model,
  }) : _client = client,
       _model = model;

  final LlamaClientApi _client;
  final LlamaModelHandle _model;

  @override
  TokenizeResult tokenize(TokenizeRequest request) {
    final response = _client.tokenize(
      _model,
      request.text,
      addSpecial: request.addSpecial,
      parseSpecial: request.parseSpecial,
    );
    return switch (response) {
      LlamaClientTokenizeSucceeded(:final tokens) => TokenizeSucceeded(
        Int64List.fromList(tokens),
      ),
      LlamaClientTokenizeFailed(:final message, :final stackTrace) =>
        TokenizeFailed(message: message, stackTrace: stackTrace),
    };
  }

  @override
  DetokenizeResult detokenize(DetokenizeRequest request) {
    return DetokenizeSucceeded(_client.tokenToBytes(_model, request.token));
  }
}

sealed class LlamaSpawnModelLoaderResult {
  const LlamaSpawnModelLoaderResult();
}

final class LlamaSpawnModelLoaderSucceeded extends LlamaSpawnModelLoaderResult {
  const LlamaSpawnModelLoaderSucceeded(this.loader);

  final LlamaModelLoader loader;
}

final class LlamaSpawnModelLoaderFailed extends LlamaSpawnModelLoaderResult {
  const LlamaSpawnModelLoaderFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

sealed class LlamaModelLoaderCloseResult {
  const LlamaModelLoaderCloseResult();
}

/// The model isolate is gone and every model it held is freed.
final class LlamaModelLoaderClosed extends LlamaModelLoaderCloseResult {
  const LlamaModelLoaderClosed();
}

/// Models handed out by the loader are still undisposed; nothing was closed.
final class LlamaModelLoaderCloseRefused extends LlamaModelLoaderCloseResult {
  const LlamaModelLoaderCloseRefused({required this.liveModels});

  final int liveModels;
}

sealed class LlamaLoadModelResult {
  const LlamaLoadModelResult();
}

final class LlamaLoadModelSucceeded extends LlamaLoadModelResult {
  const LlamaLoadModelSucceeded(this.model);

  final LlamaModel model;
}

final class LlamaLoadModelFailed extends LlamaLoadModelResult {
  const LlamaLoadModelFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
