@TestOn('!windows')
library;

import 'dart:ffi';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_linux/bestie_platform_linux.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

const _shared = SharedAppAssets(
  caCert: AppAsset(
    path: 'cacert.pem',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    isPlatformSpecific: false,
    missingMessage: 'CA cert not found.',
  ),
  credits: AppAsset(
    path: 'CREDITS.md',
    bundleSubdir: '',
    missingMessage: 'Credits not found.',
  ),
  shellBin: AppAsset(
    path: 'shell/bin',
    packageOwner: 'packages/infra/agent_shell',
    missingMessage: 'Shell userland not built.',
  ),
);

const _assets = PosixAppAssets(
  curl: AppAsset(
    path: 'libcurl-impersonate.so',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Curl library not found.',
  ),
  spawner: AppAsset(
    path: 'spawner',
    packageOwner: 'packages/ffi/posix_spawner',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Spawner helper not found.',
  ),
  editor: AppAsset(
    path: 'bestie_edit',
    packageOwner: 'packages/infra/bestie_edit',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Editor not found.',
  ),
  shared: _shared,
);

FakePlatform _platform({required String resolvedExecutable}) => FakePlatform(
  operatingSystem: 'linux',
  resolvedExecutable: resolvedExecutable,
  script: Uri.file('/repo/packages/bestie/bin/bestie.dart'),
  environment: const {'HOME': '/home/tester'},
  numberOfProcessors: 8,
  pathSeparator: '/',
);

LinuxPlatformDataSource _dataSource(
  MemoryFileSystem fs, {
  required bool bundled,
  String resolvedExecutable = '/opt/Bestie/bin/bestie',
  Abi abi = Abi.linuxX64,
}) => LinuxPlatformDataSource(
  platform: _platform(resolvedExecutable: resolvedExecutable),
  fileSystem: fs,
  abi: abi,
  bundled: bundled,
  assets: _assets,
);

/// A resolver mirroring the data source's own, so tests know where each asset
/// must be created for the given environment.
AppAssetResolver _mirror(
  MemoryFileSystem fs, {
  required bool bundled,
  String resolvedExecutable = '/opt/Bestie/bin/bestie',
}) => AppAssetResolver(
  bundled: bundled,
  fileSystem: fs,
  executableDir: p.dirname(resolvedExecutable),
  repoRoot: '/repo',
  platformDir: 'linux',
  archDir: 'x64',
);

void _createAssets(MemoryFileSystem fs, AppAssetResolver resolver) {
  for (final asset in _assets.bundleAssets) {
    fs.file(resolver.pathFor(asset)).createSync(recursive: true);
  }
}

void main() {
  for (final bundled in [false, true]) {
    final mode = bundled ? 'release bundle' : 'source tree';
    group('loadPlatform ($mode)', () {
      test('resolves the curl, cert, and credits paths', () {
        final fs = MemoryFileSystem.test();
        final resolver = _mirror(fs, bundled: bundled);
        _createAssets(fs, resolver);

        final platform = _dataSource(fs, bundled: bundled).loadPlatform();

        expect(
          platform.curlLibraryPath,
          resolver.pathFor(_assets.curl),
        );
        expect(
          platform.caCertPath,
          resolver.pathFor(_assets.shared.caCert),
        );
        expect(
          platform.creditsPath,
          resolver.pathFor(_assets.shared.credits),
        );
      });
    });
  }

  test('resolves the temp directory to /tmp when TMPDIR is unset', () {
    final fs = MemoryFileSystem.test();
    _createAssets(fs, _mirror(fs, bundled: false));

    final platform = _dataSource(fs, bundled: false).loadPlatform();

    expect(platform.tempDir, '/tmp');
  });

  test('loadPlatform throws naming the missing asset', () {
    final dataSource = _dataSource(MemoryFileSystem.test(), bundled: false);

    expect(
      dataSource.loadPlatform,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Curl library'),
        ),
      ),
    );
  });

  test('resolves the spawner helper', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    _createAssets(fs, resolver);

    final spawnerPath = _dataSource(fs, bundled: false).resolveSpawnerPath();

    expect(spawnerPath, resolver.pathFor(_assets.spawner));
  });

  test('resolves the editor', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    _createAssets(fs, resolver);

    final editorPath = _dataSource(fs, bundled: false).resolveEditorPath();

    expect(editorPath, resolver.pathFor(_assets.editor));
  });

  test('throws for the editor when it is not built', () {
    final dataSource = _dataSource(MemoryFileSystem.test(), bundled: false);
    expect(dataSource.resolveEditorPath, throwsStateError);
  });

  test('throws on unsupported architecture', () {
    final dataSource = _dataSource(
      MemoryFileSystem.test(),
      bundled: false,
      abi: Abi.linuxArm64,
    );

    expect(dataSource.loadPlatform, throwsA(isA<UnsupportedError>()));
  });

  test('resolves the shell userland when it exists', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    final binDir = resolver.pathFor(_assets.shared.shellBin);
    fs.directory(binDir).createSync(recursive: true);

    final userland = _dataSource(fs, bundled: false).resolveShellUserland();

    expect(userland.binDir, binDir);
    expect(userland.shellPath, fs.path.join(binDir, 'brush'));
    expect(userland.executables, ShellExecutables.posix);
  });

  test('throws for the shell userland when it is not built', () {
    final dataSource = _dataSource(MemoryFileSystem.test(), bundled: false);
    expect(dataSource.resolveShellUserland, throwsStateError);
  });

  test('bundleAssets covers every asset the platform resolves', () {
    expect(
      _assets.bundleAssets,
      containsAll(<AppAsset>[
        _assets.curl,
        _assets.spawner,
        _assets.shared.caCert,
        _assets.shared.credits,
        _assets.shared.shellBin,
      ]),
    );
  });
}
