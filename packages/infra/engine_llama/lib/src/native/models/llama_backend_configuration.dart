/// Native llama.cpp backend library paths.
final class LlamaBackendLibraries {
  /// Creates llama.cpp backend paths.
  const LlamaBackendLibraries({
    required this.runtimeLibraryPath,
    required this.commonLibraryPath,
    this.additionalSymbolLibraryPlatformPaths = const [],
  });

  /// Path to the llama.cpp runtime library.
  final String runtimeLibraryPath;

  /// Path to the llama.cpp common support library.
  final String commonLibraryPath;

  /// Extra library files to fold into the backend's symbol lookup because this
  /// platform's loader will not resolve them through the runtime handle.
  ///
  /// Posix platforms won't need this since they auto-resolve.
  final List<String> additionalSymbolLibraryPlatformPaths;
}

/// Configuration for creating a llama.cpp model loader.
final class LlamaBackendConfiguration {
  /// Creates llama.cpp backend configuration.
  const LlamaBackendConfiguration({
    required this.libraries,
    this.disableMetalResidency = true,
  });

  /// Native libraries used by this backend.
  final LlamaBackendLibraries libraries;

  /// When true (default), sets `GGML_METAL_NO_RESIDENCY=1` before backend init.
  /// llama.cpp's Metal residency sets wire model weights and do not release
  /// them promptly on unload, which stacks memory across model hot-swaps and
  /// OOMs Apple Silicon machines. Set false only to reproduce that behavior.
  final bool disableMetalResidency;
}
