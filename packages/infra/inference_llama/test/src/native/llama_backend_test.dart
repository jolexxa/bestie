import 'dart:ffi';

import 'package:inference_llama/src/native/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';
import '../../fixtures/mocks.dart';

void main() {
  group('LlamaBackend', () {
    late FakeLlamaCppBindings bindings;
    late FakeLlamaCppBindings commonBindings;
    late MockLlamaNativeLibraries libraries;
    late List<LlamaSymbolLookup> lookups;
    final library = DynamicLibrary.process();

    setUpAll(() {
      registerFallbackValue(library);
      registerFallbackValue(library.lookup);
    });

    setUp(() {
      bindings = FakeLlamaCppBindings();
      commonBindings = FakeLlamaCppBindings();
      libraries = MockLlamaNativeLibraries();
      lookups = [];
      final bound = [bindings, commonBindings];
      when(() => libraries.open(any())).thenReturn(library);
      when(() => libraries.bind(any())).thenAnswer((invocation) {
        lookups.add(invocation.positionalArguments.first as LlamaSymbolLookup);
        return bound.removeAt(0);
      });
    });

    LlamaBackend open({
      List<String> additional = const [],
      bool disableMetalResidency = true,
    }) => LlamaBackend.open(
      LlamaBackendConfiguration(
        libraries: LlamaBackendLibraries(
          runtimeLibraryPath: '/opt/llama/libllama.so',
          commonLibraryPath: '/opt/llama/libcommon.so',
          additionalSymbolLibraryPlatformPaths: additional,
        ),
        disableMetalResidency: disableMetalResidency,
      ),
      libraries: libraries,
    );

    test('tryOpen answers with the opened backend', () {
      final opened = LlamaBackend.tryOpen(
        const LlamaBackendConfiguration(
          libraries: LlamaBackendLibraries(
            runtimeLibraryPath: '/opt/llama/libllama.so',
            commonLibraryPath: '/opt/llama/libcommon.so',
          ),
        ),
        libraries: libraries,
      );

      expect(
        opened,
        isA<LlamaBackendOpened>().having(
          (opened) => opened.backend.bindings,
          'bindings',
          same(bindings),
        ),
      );
    });

    test('tryOpen answers unavailable when a library cannot load', () {
      when(
        () => libraries.open(any()),
      ).thenThrow(ArgumentError('libllama.so: image not found'));

      final opened = LlamaBackend.tryOpen(
        const LlamaBackendConfiguration(
          libraries: LlamaBackendLibraries(
            runtimeLibraryPath: '/opt/llama/libllama.so',
            commonLibraryPath: '/opt/llama/libcommon.so',
          ),
        ),
        libraries: libraries,
      );

      expect(
        opened,
        isA<LlamaBackendUnavailable>().having(
          (unavailable) => unavailable.message,
          'message',
          contains('image not found'),
        ),
      );
    });

    test('opens the libraries and initializes llama.cpp once', () {
      final backend = open();

      verifyInOrder([
        libraries.disableMetalResidency,
        () => libraries.searchDependenciesIn('/opt/llama'),
        () => libraries.open('/opt/llama/libllama.so'),
        () => libraries.open('/opt/llama/libcommon.so'),
      ]);
      expect(identical(backend.bindings, bindings), isTrue);
      expect(backend.client, isA<LlamaClient>());
      expect(backend.bestFit, isA<BestFitClient>());
      expect(
        backend.configuration.libraries.runtimeLibraryPath,
        '/opt/llama/libllama.so',
      );
      expect(bindings.backendLoadAllFromPathCalls, 1);
      expect(bindings.lastBackendLoadPath, '/opt/llama');
      expect(bindings.backendInitCalls, 1);
    });

    test('leaves Metal residency alone when asked to', () {
      open(disableMetalResidency: false);

      verifyNever(libraries.disableMetalResidency);
    });

    test('opens each additional symbol library after the runtime', () {
      open(
        additional: ['/opt/llama/libggml.so', '/opt/llama/libggml-base.so'],
      );

      verifyInOrder([
        () => libraries.open('/opt/llama/libllama.so'),
        () => libraries.open('/opt/llama/libggml.so'),
        () => libraries.open('/opt/llama/libggml-base.so'),
        () => libraries.open('/opt/llama/libcommon.so'),
      ]);
    });

    test('dispose frees llama.cpp and closes every library once', () {
      open(additional: ['/opt/llama/libggml.so'])
        ..dispose()
        ..dispose();

      expect(bindings.backendFreeCalls, 1);
      verify(() => libraries.close(library)).called(3);
    });

    test('resolves each symbol from the first library that provides it', () {
      open(additional: ['/opt/llama/libggml.so']);
      final lookup = lookups.first;

      expect(lookup<Void>('malloc'), library.lookup<Void>('malloc'));
      expect(
        () => lookup<Void>('bestie_symbol_nobody_exports'),
        throwsArgumentError,
      );
    });

    test('binds the common library through its own lookup', () {
      final backend = open();

      expect(lookups, hasLength(2));
      expect(lookups.last<Void>('malloc'), library.lookup<Void>('malloc'));
      expect(backend.bestFit, isA<BestFitApi>());
    });
  });
}
