import 'dart:ffi';
import 'dart:io';

import 'package:llama_cpp_dart/src/bindings/llama_cpp_bindings.dart';

/// One llama.cpp dynamic library and the generated bindings over it.
///
/// The runtime (`llama`) and `llama-common`, which exports the `best_fit`
/// predictor, are opened separately.
class LlamaCpp {
  /// Opens the dynamic library at [libraryPath].
  factory LlamaCpp.open({required String libraryPath}) =>
      LlamaCpp._(DynamicLibrary.open(libraryPath));

  LlamaCpp._(this.dylib) : bindings = LlamaCppBindings(dylib);

  /// The open dynamic library handle.
  final DynamicLibrary dylib;

  /// Generated FFI bindings.
  final LlamaCppBindings bindings;

  /// The runtime library's file name on [operatingSystem], which defaults to
  /// the host's.
  static String defaultLibraryFileName({String? operatingSystem}) =>
      switch (operatingSystem ?? Platform.operatingSystem) {
        'macos' => 'libllama.0.dylib',
        'linux' => 'libllama.so',
        'windows' => 'llama.dll',
        final other => throw UnsupportedError('Unsupported platform: $other'),
      };

  /// The llama-common library's file name on [operatingSystem], which
  /// defaults to the host's.
  static String defaultCommonLibraryFileName({String? operatingSystem}) =>
      switch (operatingSystem ?? Platform.operatingSystem) {
        'macos' => 'libllama-common.0.dylib',
        'linux' => 'libllama-common.so',
        'windows' => 'llama-common.dll',
        final other => throw UnsupportedError('Unsupported platform: $other'),
      };
}
