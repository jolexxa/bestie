import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

const _fileAsset = AppAsset(
  path: 'libtest.dylib',
  packageOwner: 'packages/ffi/test_ffi',
  missingMessage: 'Test library not found.',
);

const _sharedAsset = AppAsset(
  path: 'cacert.pem',
  packageOwner: 'packages/ffi/curl_impersonate_dart',
  isPlatformSpecific: false,
  missingMessage: 'Cert not found.',
);

const _docAsset = AppAsset(
  path: 'CREDITS.md',
  bundleSubdir: '',
  missingMessage: 'Credits not found.',
);

const _dirAsset = AppAsset(
  path: 'shell/bin',
  packageOwner: 'packages/infra/agent_shell',
  missingMessage: 'Shell userland not found.',
);

const _baseDirAsset = AppAsset(
  path: '',
  packageOwner: 'packages/ffi/curl_impersonate_dart',
  missingMessage: 'Curl library set not found.',
);

AppAssetResolver _resolver(MemoryFileSystem fs, {required bool bundled}) =>
    AppAssetResolver(
      bundled: bundled,
      fileSystem: fs,
      executableDir: '/app/bin',
      repoRoot: '/repo',
      platformDir: 'macos',
      archDir: 'arm64',
    );

void main() {
  group('pathFor — release bundle', () {
    final resolver = _resolver(MemoryFileSystem.test(), bundled: true);

    test('a file lands beside the executable, under lib/', () {
      expect(resolver.pathFor(_fileAsset), '/app/lib/libtest.dylib');
    });

    test('a platform-independent file still lands under lib/', () {
      expect(resolver.pathFor(_sharedAsset), '/app/lib/cacert.pem');
    });

    test('a doc (empty bundleSubdir) lands at the bundle root', () {
      expect(resolver.pathFor(_docAsset), '/app/CREDITS.md');
    });

    test('a subdirectory asset resolves under lib/', () {
      expect(resolver.pathFor(_dirAsset), '/app/lib/shell/bin');
    });

    test('an empty path resolves the lib/ directory itself', () {
      expect(resolver.pathFor(_baseDirAsset), '/app/lib');
    });
  });

  group('pathFor — source tree', () {
    final resolver = _resolver(MemoryFileSystem.test(), bundled: false);

    test('a platform-specific file sits under assets/native/<os>/<arch>', () {
      expect(
        resolver.pathFor(_fileAsset),
        '/repo/packages/ffi/test_ffi/assets/native/macos/arm64/libtest.dylib',
      );
    });

    test('a platform-independent file sits under assets/', () {
      expect(
        resolver.pathFor(_sharedAsset),
        '/repo/packages/ffi/curl_impersonate_dart/assets/cacert.pem',
      );
    });

    test('a doc without an owner sits at the repo root', () {
      expect(resolver.pathFor(_docAsset), '/repo/CREDITS.md');
    });

    test('an empty path resolves the native/<os>/<arch> directory', () {
      expect(
        resolver.pathFor(_baseDirAsset),
        '/repo/packages/ffi/curl_impersonate_dart/assets/native/macos/arm64',
      );
    });
  });

  group('resolve verifies existence', () {
    test('returns the bundle path when the file exists', () {
      final fs = MemoryFileSystem.test();
      fs.file('/app/lib/libtest.dylib').createSync(recursive: true);

      expect(
        _resolver(fs, bundled: true).resolve(_fileAsset),
        '/app/lib/libtest.dylib',
      );
    });

    test('returns the source path when the file exists', () {
      final fs = MemoryFileSystem.test();
      final path = _resolver(fs, bundled: false).pathFor(_fileAsset);
      fs.file(path).createSync(recursive: true);

      expect(_resolver(fs, bundled: false).resolve(_fileAsset), path);
    });

    test('resolves a directory that exists, even when empty', () {
      final fs = MemoryFileSystem.test();
      fs.directory('/app/lib/shell/bin').createSync(recursive: true);

      expect(
        _resolver(fs, bundled: true).resolve(_dirAsset),
        '/app/lib/shell/bin',
      );
    });

    test('throws StateError naming the expected path when missing', () {
      final fs = MemoryFileSystem.test();

      expect(
        () => _resolver(fs, bundled: true).resolve(_fileAsset),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Test library not found.'),
              contains('/app/lib/libtest.dylib'),
            ),
          ),
        ),
      );
    });
  });
}
