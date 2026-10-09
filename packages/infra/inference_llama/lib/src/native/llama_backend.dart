import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:inference_llama/src/native/best_fit_client.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:inference_llama/src/native/models/llama_backend_configuration.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:posix_dart/posix_dart.dart';
import 'package:win32_dart/win32_dart.dart';

/// Resolves a native symbol by name.
typedef LlamaSymbolLookup =
    Pointer<T> Function<T extends NativeType>(String symbolName);

/// The process-level native operations an isolate's backend is built from.
abstract interface class LlamaNativeLibraries {
  /// Lets libraries opened afterwards find the libraries they import in
  /// [directory]. POSIX libraries carry their own search path; a Windows DLL
  /// otherwise looks beside the executable and on `PATH` only.
  void searchDependenciesIn(String directory);

  /// Opens the dynamic library at [path].
  DynamicLibrary open(String path);

  /// Releases a library opened by [open].
  void close(DynamicLibrary library);

  /// Generated bindings over [lookup].
  LlamaCppBindings bind(LlamaSymbolLookup lookup);

  /// Keeps Metal from wiring model weights into residency sets, which are
  /// not released promptly on unload and stack memory across model swaps.
  void disableMetalResidency();
}

/// The real dynamic loader.
// coverage:ignore-start
final class SystemLlamaNativeLibraries implements LlamaNativeLibraries {
  const SystemLlamaNativeLibraries();

  @override
  void searchDependenciesIn(String directory) {
    if (!Platform.isWindows) return;
    final kernel32 = WindowsBindings(DynamicLibrary.open('kernel32.dll'));
    switch (DllSearchPath(kernel32).use(directory)) {
      case DllSearchPathSucceeded():
        return;
      case DllSearchPathFailed(:final failure):
        throw StateError(
          'Could not search $directory for DLLs: ${failure.message}',
        );
    }
  }

  @override
  DynamicLibrary open(String path) => DynamicLibrary.open(path);

  @override
  void close(DynamicLibrary library) => library.close();

  @override
  LlamaCppBindings bind(LlamaSymbolLookup lookup) =>
      LlamaCppBindings.fromLookup(lookup);

  @override
  void disableMetalResidency() {
    // ggml reads this once, when the Metal device first initializes.
    if (Platform.isMacOS) PosixEnv.setenv('GGML_METAL_NO_RESIDENCY', '1');
  }
}
// coverage:ignore-end

/// One isolate's llama.cpp backend: the opened libraries, their bindings,
/// and the clients built over them.
///
/// Build exactly one per isolate, at that isolate's composition root, and
/// pass it to whatever needs native access.
final class LlamaBackend {
  LlamaBackend._({
    required this.configuration,
    required this.bindings,
    required this.client,
    required this.bestFit,
    required LlamaNativeLibraries libraries,
    required List<DynamicLibrary> opened,
  }) : _libraries = libraries,
       _opened = opened;

  /// Opens the runtime and common libraries, registers the ggml backends
  /// that sit beside the runtime library, and initializes llama.cpp.
  factory LlamaBackend.open(
    LlamaBackendConfiguration configuration, {
    LlamaNativeLibraries libraries = const SystemLlamaNativeLibraries(),
  }) {
    if (configuration.disableMetalResidency) {
      libraries.disableMetalResidency();
    }
    final paths = configuration.libraries;
    final libraryDirectory = p.dirname(paths.runtimeLibraryPath);
    libraries.searchDependenciesIn(libraryDirectory);
    final runtime = [
      libraries.open(paths.runtimeLibraryPath),
      for (final path in paths.additionalSymbolLibraryPlatformPaths)
        libraries.open(path),
    ];
    final common = libraries.open(paths.commonLibraryPath);
    final bindings = libraries.bind(_composeLookup(runtime));
    final directory = libraryDirectory
        .toNativeUtf8(allocator: calloc)
        .cast<Char>();
    try {
      bindings.ggml_backend_load_all_from_path(directory);
    } finally {
      calloc.free(directory);
    }
    bindings.llama_backend_init();
    return LlamaBackend._(
      configuration: configuration,
      bindings: bindings,
      client: LlamaClient(bindings: bindings),
      bestFit: BestFitClient(
        llamaBindings: bindings,
        commonBindings: libraries.bind(common.lookup),
      ),
      libraries: libraries,
      opened: [...runtime, common],
    );
  }

  /// Opens the backend as [LlamaBackend.open] does, answering why when the
  /// libraries cannot be loaded instead of throwing.
  static LlamaBackendOpenResult tryOpen(
    LlamaBackendConfiguration configuration, {
    LlamaNativeLibraries libraries = const SystemLlamaNativeLibraries(),
  }) {
    try {
      return LlamaBackendOpened(
        LlamaBackend.open(configuration, libraries: libraries),
      );
    } on Object catch (error) {
      return LlamaBackendUnavailable(message: '$error');
    }
  }

  /// What this backend was opened from.
  final LlamaBackendConfiguration configuration;

  /// Bindings over the runtime library.
  final LlamaCppBindings bindings;

  /// Model, context and decode operations.
  final LlamaClientApi client;

  /// Fit prediction.
  final BestFitApi bestFit;

  final LlamaNativeLibraries _libraries;
  final List<DynamicLibrary> _opened;
  var _disposed = false;

  /// Frees llama.cpp and closes every library. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    bindings.llama_backend_free();
    _opened.forEach(_libraries.close);
  }

  // On POSIX the runtime handle already resolves ggml symbols through its
  // dependency graph, so the list is just the runtime library. On Windows the
  // runtime handle only exposes its own exports, so each symbol resolves
  // against the first library that provides it, falling back to the runtime
  // library so a genuine miss names it.
  static LlamaSymbolLookup _composeLookup(List<DynamicLibrary> libraries) {
    if (libraries.length == 1) return libraries.single.lookup;
    return <T extends NativeType>(String symbolName) {
      final provider = libraries.firstWhere(
        (library) => library.providesSymbol(symbolName),
        orElse: () => libraries.first,
      );
      return provider.lookup<T>(symbolName);
    };
  }
}

sealed class LlamaBackendOpenResult {
  const LlamaBackendOpenResult();
}

final class LlamaBackendOpened extends LlamaBackendOpenResult {
  const LlamaBackendOpened(this.backend);

  final LlamaBackend backend;
}

/// The native libraries are missing or could not be loaded.
final class LlamaBackendUnavailable extends LlamaBackendOpenResult {
  const LlamaBackendUnavailable({required this.message});

  final String message;
}
