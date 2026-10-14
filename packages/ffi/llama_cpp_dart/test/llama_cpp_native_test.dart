import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final nativeDir = p.absolute('assets', 'native', _hostSubdir());
  _searchDependenciesIn(nativeDir);
  final runtimePath = p.join(nativeDir, LlamaCpp.defaultLibraryFileName());
  final commonPath = p.join(nativeDir, LlamaCpp.defaultCommonLibraryFileName());
  final skip = File(runtimePath).existsSync()
      ? null
      : 'llama.cpp libraries not staged (dart tool/download_llama_assets.dart)';

  group('staged llama.cpp libraries', () {
    test('export best_fit from llama-common', () {
      final common = LlamaCpp.open(libraryPath: commonPath).dylib;

      expect(common.providesSymbol('best_fit_predict'), isTrue);
      expect(common.providesSymbol('best_fit_max_ctx'), isTrue);
    }, skip: skip);

    test('match the bound model parameter layout', () {
      final runtime = LlamaCpp.open(libraryPath: runtimePath);

      final params = runtime.bindings.llama_model_default_params();

      expect(params.load_mode, llama_load_mode.LLAMA_LOAD_MODE_AUTO);
      expect(params.n_gpu_layers, isNot(0));
    }, skip: skip);
  });
}

String _hostSubdir() => switch (Abi.current()) {
  Abi.macosArm64 => p.join('macos', 'arm64'),
  Abi.linuxX64 => p.join('linux', 'x64'),
  Abi.windowsX64 => p.join('windows', 'x64'),
  final abi => p.join('unsupported', '$abi'),
};

/// Windows resolves a library's dependencies from the search path, not from
/// the library's own directory; the other platforms find them beside it.
void _searchDependenciesIn(String directory) {
  if (!Platform.isWindows) return;
  final setDllDirectory = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)
      >('SetDllDirectoryW');
  using((arena) => setDllDirectory(directory.toNativeUtf16(allocator: arena)));
}
