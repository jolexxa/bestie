import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:test/test.dart';

void main() {
  group('LlamaCpp library names', () {
    test('name the runtime library per platform', () {
      expect(
        LlamaCpp.defaultLibraryFileName(operatingSystem: 'macos'),
        'libllama.0.dylib',
      );
      expect(
        LlamaCpp.defaultLibraryFileName(operatingSystem: 'linux'),
        'libllama.so',
      );
      expect(
        LlamaCpp.defaultLibraryFileName(operatingSystem: 'windows'),
        'llama.dll',
      );
    });

    test('name the common library per platform', () {
      expect(
        LlamaCpp.defaultCommonLibraryFileName(operatingSystem: 'macos'),
        'libllama-common.0.dylib',
      );
      expect(
        LlamaCpp.defaultCommonLibraryFileName(operatingSystem: 'linux'),
        'libllama-common.so',
      );
      expect(
        LlamaCpp.defaultCommonLibraryFileName(operatingSystem: 'windows'),
        'llama-common.dll',
      );
    });

    test('reject platforms without a llama.cpp build', () {
      expect(
        () => LlamaCpp.defaultLibraryFileName(operatingSystem: 'fuchsia'),
        throwsUnsupportedError,
      );
      expect(
        () => LlamaCpp.defaultCommonLibraryFileName(operatingSystem: 'fuchsia'),
        throwsUnsupportedError,
      );
    });

    test('default to the host platform', () {
      expect(LlamaCpp.defaultLibraryFileName(), isNotEmpty);
      expect(LlamaCpp.defaultCommonLibraryFileName(), isNotEmpty);
    });
  });
}
