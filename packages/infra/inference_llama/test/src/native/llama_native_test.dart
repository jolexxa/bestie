import 'dart:ffi';
import 'dart:io';

import 'package:inference_llama/src/model_isolate/llama_model_protocol.dart';
import 'package:inference_llama/src/model_isolate/llama_model_worker.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final nativeDir = p.absolute(
    '..',
    '..',
    'ffi',
    'llama_cpp_dart',
    'assets',
    'native',
    _host(),
  );
  final runtimePath = p.join(nativeDir, LlamaCpp.defaultLibraryFileName());
  final skip = File(runtimePath).existsSync()
      ? null
      : 'llama.cpp libraries not staged (dart tool/download_llama_assets.dart)';

  group('staged llama.cpp libraries', () {
    late LlamaModelCommandHandler handler;

    setUp(() {
      handler = LlamaModelCommandHandler(
        LlamaBackendConfiguration(
          libraries: LlamaBackendLibraries(
            runtimeLibraryPath: runtimePath,
            commonLibraryPath: p.join(
              nativeDir,
              LlamaCpp.defaultCommonLibraryFileName(),
            ),
            additionalSymbolLibraryPlatformPaths: [
              if (Platform.isWindows) ...[
                p.join(nativeDir, 'ggml.dll'),
                p.join(nativeDir, 'ggml-base.dll'),
              ],
            ],
          ),
        ),
      );
    });

    test('report the devices the backend registered', () async {
      final response =
          await handler(const GetLlamaDeviceInfo())
              as GetLlamaDeviceInfoResponded;

      expect(
        (response.response as GetLlamaDeviceInfoSucceeded).devices,
        isNotEmpty,
      );
    }, skip: skip);

    test('predict through best_fit and report a missing model', () async {
      final response =
          await handler(
                const FitMaxLlamaModel(
                  path: '/bestie/no/such/model.gguf',
                  contextOptions: LlamaContextOptions(
                    contextSize: 4096,
                    nBatch: 512,
                    nThreads: 1,
                    nThreadsBatch: 1,
                  ),
                  minContextSize: 512,
                  maxContextSize: 4096,
                  headroomBytesByDevice: [0],
                ),
              )
              as FitMaxLlamaModelResponded;

      final result = (response.response as FitMaxLlamaModelSucceeded).result;
      expect(result.status, BestFitStatus.error);
      expect(result.fits, isFalse);
    }, skip: skip);
  });
}

String _host() => switch (Abi.current()) {
  Abi.macosArm64 => p.join('macos', 'arm64'),
  Abi.linuxX64 => p.join('linux', 'x64'),
  Abi.windowsX64 => p.join('windows', 'x64'),
  final abi => p.join('unsupported', '$abi'),
};
