import 'package:inference_llama/src/model_isolate/llama_model_dispatcher.dart';
import 'package:inference_llama/src/model_isolate/llama_model_events.dart';
import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/native/llama_backend.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:isolate_worker/isolate_worker.dart';

/// The channel to the isolate that owns loaded model weights.
abstract interface class LlamaModelWorker {
  Future<LlamaModelResponse> send(LlamaModelRequest request);

  /// Progress reported by in-flight requests, tagged with their request id.
  Stream<LlamaModelEvent> get events;

  Future<void> close();
}

final class LlamaModelIsolateWorker implements LlamaModelWorker {
  const LlamaModelIsolateWorker(this._worker);

  final IsolateWorker<LlamaModelRequest, LlamaModelResponse> _worker;

  /// Spawns the model isolate, which opens its own backend from
  /// [configuration] on its first request.
  static Future<LlamaModelWorkerCreateResult> spawn({
    required LlamaBackendConfiguration configuration,
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
  }) async {
    final result =
        await IsolateWorker.spawn<LlamaModelRequest, LlamaModelResponse>(
          commandHandler: LlamaModelCommandHandler(configuration).call,
          isolateSpawner: isolateSpawner,
          debugName: 'llama-model',
        );

    return switch (result) {
      IsolateSpawnSucceeded(:final worker) => LlamaModelWorkerCreateSucceeded(
        LlamaModelIsolateWorker(worker),
      ),
      IsolateSpawnFailed(:final message, :final stackTrace) =>
        LlamaModelWorkerCreateFailed(message: message, stackTrace: stackTrace),
    };
  }

  @override
  Stream<LlamaModelEvent> get events =>
      _worker.events.where((event) => event is LlamaModelEvent).cast();

  @override
  Future<LlamaModelResponse> send(LlamaModelRequest request) async {
    final result = await _worker.send(request);
    return switch (result) {
      IsolateSucceeded(:final value) => value,
      IsolateFailed(:final message, :final stackTrace) =>
        failedLlamaModelResponse(request, message, stackTrace),
    };
  }

  @override
  Future<void> close() => _worker.close();
}

/// The model isolate's entry point: its composition root builds the
/// isolate's backend and dispatcher on the first request.
final class LlamaModelCommandHandler {
  LlamaModelCommandHandler(this._configuration);

  final LlamaBackendConfiguration _configuration;
  LlamaModelDispatcher? _dispatcher;

  Future<LlamaModelResponse> call(
    LlamaModelRequest request, [
    IsolateRequestContext context = IsolateRequestContext.none,
  ]) async {
    return _ensureDispatcher().handle(request, events: context.events);
  }

  // FFI boundary: opens the real libraries inside the model isolate.
  // coverage:ignore-start
  LlamaModelDispatcher _ensureDispatcher() {
    return _dispatcher ??= () {
      final backend = LlamaBackend.open(_configuration);
      return LlamaModelDispatcher(
        client: backend.client,
        fit: backend.bestFit,
      );
    }();
  }

  // coverage:ignore-end
}

sealed class LlamaModelWorkerCreateResult {
  const LlamaModelWorkerCreateResult();
}

final class LlamaModelWorkerCreateSucceeded
    extends LlamaModelWorkerCreateResult {
  const LlamaModelWorkerCreateSucceeded(this.worker);

  final LlamaModelWorker worker;
}

final class LlamaModelWorkerCreateFailed extends LlamaModelWorkerCreateResult {
  const LlamaModelWorkerCreateFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
