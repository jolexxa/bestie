import 'dart:ffi';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final nativeDir = p.join('assets', 'native', _hostSubdir());
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
  Abi.macosArm64 => 'macos/arm64',
  Abi.linuxX64 => 'linux/x64',
  Abi.windowsX64 => 'windows/x64',
  final abi => 'unsupported/$abi',
};
