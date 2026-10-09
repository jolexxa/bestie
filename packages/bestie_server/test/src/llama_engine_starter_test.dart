import 'dart:ffi';

import 'package:bestie_server/bestie_server.dart';
import 'package:inference_llama/inference_llama.dart';
import 'package:inference_server/inference_server.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

final class _MockLibraries extends Mock implements LlamaNativeLibraries {}

final class _MockBindings extends Mock implements LlamaCppBindings {}

final class _MockLoader extends Mock implements LlamaModelLoader {}

final class _MockLog extends Mock implements ServerLog {}

const _libraries = LlamaBackendLibraries(
  runtimeLibraryPath: '/missing/libllama.dylib',
  commonLibraryPath: '/missing/libllama-common.dylib',
);

void main() {
  late _MockLibraries natives;
  late _MockBindings bindings;
  late LlamaBackend backend;
  late _MockLog log;

  setUpAll(() {
    final library = DynamicLibrary.process();
    registerFallbackValue(library);
    registerFallbackValue(library.lookup);
  });

  setUp(() {
    natives = _MockLibraries();
    bindings = _MockBindings();
    log = _MockLog();
    when(() => natives.open(any())).thenReturn(DynamicLibrary.process());
    when(() => natives.bind(any())).thenReturn(bindings);
    backend = LlamaBackend.open(
      const LlamaBackendConfiguration(libraries: _libraries),
      libraries: natives,
    );
  });

  LlamaEngineStarter starter({
    LlamaSpawnModelLoaderResult? spawned,
  }) => LlamaEngineStarter(
    libraries: _libraries,
    threads: 4,
    openBackend: (configuration) {
      expect(configuration.libraries, same(_libraries));
      return LlamaBackendOpened(backend);
    },
    spawnLoader: (opened) async {
      expect(opened, same(backend));
      return spawned ?? LlamaSpawnModelLoaderSucceeded(_MockLoader());
    },
  );

  test('starts an engine on the opened backend', () async {
    final loader = _MockLoader();
    when(loader.close).thenAnswer((_) async => const LlamaModelLoaderClosed());

    final started = await starter(
      spawned: LlamaSpawnModelLoaderSucceeded(loader),
    ).start(log);
    await (started as ModelEngineStarted).engine.close();

    expect(started.engine, isA<LlamaModelEngine>());
    verify(loader.close).called(1);
    verify(bindings.llama_backend_free).called(1);
  });

  test('frees the backend when the model isolate will not start', () async {
    final started = await starter(
      spawned: const LlamaSpawnModelLoaderFailed(
        message: 'spawn refused',
        stackTrace: '',
      ),
    ).start(log);

    expect(
      started,
      isA<ModelEngineFailedToStart>().having(
        (failed) => failed.message,
        'message',
        contains('spawn refused'),
      ),
    );
    verify(bindings.llama_backend_free).called(1);
  });

  test('reports libraries that cannot be loaded', () async {
    final started = await const LlamaEngineStarter(
      libraries: _libraries,
      threads: 1,
    ).start(log);

    expect(
      started,
      isA<ModelEngineLibrariesMissing>().having(
        (missing) => missing.message,
        'message',
        contains('could not be loaded'),
      ),
    );
  });
}
