import 'package:bestie_server/src/llama_model_engine.dart';
import 'package:inference_llama/inference_llama.dart';
import 'package:inference_server/inference_server.dart';
import 'package:intentions/intentions.dart';

/// Opens llama.cpp and spawns its model isolate, wherever it is started.
/// It holds only plain data and top-level functions, so it can be sent to
/// the isolate the engine runs in.
@dataSource
final class LlamaEngineStarter implements ModelEngineStarter {
  const LlamaEngineStarter({
    required this.libraries,
    required this.threads,
    this.openBackend = LlamaBackend.tryOpen,
    this.spawnLoader = LlamaModelLoader.spawn,
  });

  final LlamaBackendLibraries libraries;

  /// Threads each model computes with.
  final int threads;

  final LlamaBackendOpenResult Function(LlamaBackendConfiguration) openBackend;

  final Future<LlamaSpawnModelLoaderResult> Function(LlamaBackend backend)
  spawnLoader;

  @override
  Future<ModelEngineStart> start(ServerLog log) async {
    switch (openBackend(LlamaBackendConfiguration(libraries: libraries))) {
      case LlamaBackendUnavailable(:final message):
        return ModelEngineLibrariesMissing(
          message: 'The llama.cpp libraries could not be loaded: $message',
        );
      case LlamaBackendOpened(:final backend):
        switch (await spawnLoader(backend)) {
          case LlamaSpawnModelLoaderSucceeded(:final loader):
            return ModelEngineStarted(
              LlamaModelEngine(
                loader: loader,
                threads: threads,
                log: log,
                closeNative: () async => backend.dispose(),
              ),
            );
          case LlamaSpawnModelLoaderFailed(:final message):
            backend.dispose();
            return ModelEngineFailedToStart(
              message: 'Could not start the model isolate: $message',
            );
        }
    }
  }
}
