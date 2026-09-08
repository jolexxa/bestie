import 'dart:ffi';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

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

const _assets = WindowsAppAssets(
  curl: AppAsset(
    path: 'libcurl-impersonate.dll',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Curl library not found.',
  ),
  conptyLibrary: AppAsset(
    path: 'conpty.dll',
    packageOwner: 'packages/ffi/win32_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Console host library (conpty.dll) not found.',
  ),
  consoleHostExecutable: AppAsset(
    path: 'OpenConsole.exe',
    packageOwner: 'packages/ffi/win32_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Console host (OpenConsole.exe) not found.',
  ),
  editor: AppAsset(
    path: 'bestie_edit.exe',
    packageOwner: 'packages/infra/bestie_edit',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Editor not found.',
  ),
  shared: _shared,
);

final Uri _script = Uri.file('/repo/packages/bestie/bin/bestie.dart');

/// The repo root the data source derives from the script URI, computed the
/// same way so the expectations hold whatever host runs this.
final String _repoRoot = p.normalize(
  p.join(p.dirname(_script.toFilePath()), '..', '..', '..'),
);

WindowsPlatformDataSource _dataSource(
  MemoryFileSystem fs, {
  required bool bundled,
  String resolvedExecutable = '/opt/bestie/bestie.exe',
  Abi abi = Abi.windowsX64,
  DllSearchPath? dllSearchPath,
}) => WindowsPlatformDataSource(
  platform: FakePlatform(
    operatingSystem: 'windows',
    resolvedExecutable: resolvedExecutable,
    script: _script,
    environment: const {'USERPROFILE': r'C:\Users\tester'},
    numberOfProcessors: 16,
  ),
  fileSystem: fs,
  abi: abi,
  bundled: bundled,
  assets: _assets,
  dllSearchPath: dllSearchPath ?? _acceptingSearchPath(),
);

MockDllSearchPath _acceptingSearchPath() {
  final searchPath = MockDllSearchPath();
  when(() => searchPath.use(any())).thenReturn(const DllSearchPathSucceeded());
  return searchPath;
}

/// A resolver mirroring the data source's own, so tests know where each asset
/// must be created for the given environment.
AppAssetResolver _mirror(
  MemoryFileSystem fs, {
  required bool bundled,
  String resolvedExecutable = '/opt/bestie/bestie.exe',
}) => AppAssetResolver(
  bundled: bundled,
  fileSystem: fs,
  executableDir: p.dirname(resolvedExecutable),
  repoRoot: _repoRoot,
  platformDir: 'windows',
  archDir: 'x64',
);

void _createAssets(MemoryFileSystem fs, AppAssetResolver resolver) {
  for (final asset in _assets.bundleAssets) {
    fs.file(resolver.pathFor(asset)).createSync(recursive: true);
  }
}

void main() {
  test('resolves the curl library from the source tree', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    _createAssets(fs, resolver);

    final platform = _dataSource(fs, bundled: false).loadPlatform();

    expect(platform.curlLibraryPath, resolver.pathFor(_assets.curl));
  });

  test('resolves the curl library from the bundle in release mode', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: true);
    _createAssets(fs, resolver);

    final platform = _dataSource(fs, bundled: true).loadPlatform();

    expect(platform.curlLibraryPath, resolver.pathFor(_assets.curl));
  });

  test('resolves the CA cert and credits from the source tree', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    _createAssets(fs, resolver);

    final platform = _dataSource(fs, bundled: false).loadPlatform();

    expect(
      platform.caCertPath,
      resolver.pathFor(_assets.shared.caCert),
    );
    expect(
      platform.creditsPath,
      resolver.pathFor(_assets.shared.credits),
    );
  });

  test('describes the platform it resolved', () {
    final fs = MemoryFileSystem.test();
    _createAssets(fs, _mirror(fs, bundled: false));

    final platform = _dataSource(fs, bundled: false).loadPlatform();

    expect(platform, isA<WindowsPlatform>());
    expect(platform.os, OSKind.windows);
    expect(platform.architecture, OSArchitecture.windowsX64);
    expect(platform.homeDir, r'C:\Users\tester');
    expect(platform.tempDir, r'C:\Users\tester\AppData\Local\Temp');
    expect(platform.bestieDir, bestieDirFor(r'C:\Users\tester', p.windows));
  });

  test('bundles no spawner — the PTY helper is POSIX-only', () {
    final paths = _assets.bundleAssets.map((a) => a.path);
    expect(paths, isNot(contains('spawner')));
  });

  test('refuses any architecture but x64', () {
    expect(
      _dataSource(
        MemoryFileSystem.test(),
        bundled: false,
        abi: Abi.windowsArm64,
      ).loadPlatform,
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          'bestie requires 64-bit x86 Windows.',
        ),
      ),
    );
  });

  test('searches the directory the native libraries were resolved to', () {
    final fs = MemoryFileSystem.test();
    final resolver = _mirror(fs, bundled: false);
    _createAssets(fs, resolver);
    final libraryDir = fs.path.dirname(resolver.pathFor(_assets.curl));
    final searchPath = _acceptingSearchPath();

    _dataSource(fs, bundled: false, dllSearchPath: searchPath).loadPlatform();

    verify(() => searchPath.use(libraryDir)).called(1);
  });

  test('refuses to report a platform whose libraries could not be found', () {
    final fs = MemoryFileSystem.test();
    _createAssets(fs, _mirror(fs, bundled: false));
    final searchPath = MockDllSearchPath();
    when(() => searchPath.use(any())).thenReturn(
      const DllSearchPathFailed(
        Win32Failure(
          function: 'SetDllDirectoryW',
          code: 3,
          message: 'The system cannot find the path specified.',
          channel: Win32ErrorChannel.lastError,
        ),
      ),
    );

    expect(
      _dataSource(fs, bundled: false, dllSearchPath: searchPath).loadPlatform,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('SetDllDirectoryW'),
        ),
      ),
    );
  });

  test('resolves the shell userland when it exists', () {
    final fs = MemoryFileSystem.test();
    final binDir = _mirror(
      fs,
      bundled: false,
    ).pathFor(_assets.shared.shellBin);
    fs.directory(binDir).createSync(recursive: true);

    final userland = _dataSource(fs, bundled: false).resolveShellUserland();

    expect(userland.binDir, binDir);
    expect(userland.shellPath, fs.path.join(binDir, 'brush.exe'));
    expect(userland.executables, ShellExecutables.windows);
  });

  test('throws for the shell userland when it is not built', () {
    expect(
      _dataSource(MemoryFileSystem.test(), bundled: false).resolveShellUserland,
      throwsStateError,
    );
  });

  test('resolves the console host when both halves are installed', () {
    final fs = MemoryFileSystem.test();
    final mirror = _mirror(fs, bundled: false);
    final library = mirror.pathFor(_assets.conptyLibrary);
    final executable = mirror.pathFor(
      _assets.consoleHostExecutable,
    );
    fs.file(library).createSync(recursive: true);
    fs.file(executable).createSync(recursive: true);

    final host = _dataSource(fs, bundled: false).resolveConsoleHost();

    expect(host.libraryPath, library);
    expect(host.executablePath, executable);
  });

  // The library alone would load and quietly fall back to the console that
  // came with Windows, so a half-installed pair has to fail.
  test('throws for the console host when only the library is installed', () {
    final fs = MemoryFileSystem.test();
    fs
        .file(
          _mirror(
            fs,
            bundled: false,
          ).pathFor(_assets.conptyLibrary),
        )
        .createSync(recursive: true);

    expect(
      _dataSource(fs, bundled: false).resolveConsoleHost,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('OpenConsole.exe'),
        ),
      ),
    );
  });

  test('names the asset it could not find', () {
    expect(
      _dataSource(MemoryFileSystem.test(), bundled: false).loadPlatform,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Curl library'),
        ),
      ),
    );
  });

  test('bundleAssets covers every asset the platform resolves', () {
    expect(
      _assets.bundleAssets,
      containsAll(<AppAsset>[
        _assets.curl,
        _assets.conptyLibrary,
        _assets.consoleHostExecutable,
        _assets.shared.caCert,
        _assets.shared.credits,
        _assets.shared.shellBin,
      ]),
    );
  });
}
