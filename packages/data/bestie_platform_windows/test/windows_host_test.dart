@TestOn('windows')
library;

import 'dart:ffi';
import 'dart:io';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

/// `dart test` runs from the package root.
final String _repoRoot = p.normalize(
  p.join(Directory.current.path, '..', '..', '..'),
);

/// The real Windows manifest, mirrored here so this host test resolves the
/// actual source-tree libraries. The composition root ships the canonical copy
/// (`package:bestie`), which this data-layer package cannot import.
const _hostAssets = WindowsAppAssets(
  curl: AppAsset(
    path: 'libcurl-impersonate.dll',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Curl library (libcurl-impersonate.dll) not found.',
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
    missingMessage: 'Editor (bestie_edit.exe) not found.',
  ),
  shared: SharedAppAssets(
    caCert: AppAsset(
      path: 'cacert.pem',
      packageOwner: 'packages/ffi/curl_impersonate_dart',
      isPlatformSpecific: false,
      missingMessage: 'CA certificate bundle (cacert.pem) not found.',
    ),
    credits: AppAsset(
      path: 'CREDITS.md',
      bundleSubdir: '',
      missingMessage: 'Credits file (CREDITS.md) not found.',
    ),
    shellBin: AppAsset(
      path: 'shell/bin',
      packageOwner: 'packages/infra/agent_shell',
      missingMessage: 'Shell userland (brush + coreutils) not built.',
    ),
  ),
);

/// Every data source here is built with its host defaults, so this is what
/// proves the wiring to `win32_dart` resolves on a real machine rather than
/// only against doubles.
void main() {
  test('the resolved curl library loads', () {
    const local = LocalPlatform();
    final platform = WindowsPlatformDataSource(
      // Only `script` is faked: it is what the repo root is derived from, and
      // under the test runner it points at a generated file.
      platform: FakePlatform(
        operatingSystem: local.operatingSystem,
        resolvedExecutable: local.resolvedExecutable,
        script: Uri.file(p.join(_repoRoot, 'packages/bestie/bin/bestie.dart')),
        environment: local.environment,
      ),
      fileSystem: const LocalFileSystem(),
      abi: Abi.current(),
      bundled: false,
      assets: _hostAssets,
    ).loadPlatform();

    expect(
      () => DynamicLibrary.open(platform.curlLibraryPath),
      returnsNormally,
    );
  });

  test('system info comes back plausible for this machine', () {
    final snapshot = WindowsSystemInfoDataSource().readSystemInfo();

    expect(snapshot.logicalCoreCount, inInclusiveRange(1, 512));
    expect(snapshot.totalRamBytes, greaterThan(0));
    expect(
      snapshot.availableRamBytes,
      lessThanOrEqualTo(snapshot.totalRamBytes),
    );
    expect(snapshot.platformAlwaysUnified, isFalse);
  });

  test(
    'disk space is reported for a real directory and not for a fake one',
    () {
      final disk = WindowsDiskSpaceDataSource();

      expect(disk.availableBytes(Directory.systemTemp.path), greaterThan(0));
      expect(disk.availableBytes(r'\\?\nope\nope'), 0);
    },
  );

  test('a hardlink is created next to a real file', () {
    final directory = Directory.systemTemp.createTempSync(
      'bestie_platform_link_',
    );
    try {
      final target = p.join(directory.path, 'coreutils.exe');
      final link = p.join(directory.path, 'ls.exe');
      File(target).writeAsStringSync('multicall');

      final result = WindowsExecutableLinkDataSource().link(
        linkPath: link,
        targetPath: target,
      );

      expect(result, isA<ExecutableLinkCreated>());
      expect(File(link).readAsStringSync(), 'multicall');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('copying to the clipboard completes', () async {
    await expectLater(WindowsClipboardDataSource().copy('cow'), completes);
  });

  test('stderr is redirected to the log file and put back', () async {
    final directory = Directory.systemTemp.createTempSync(
      'bestie_platform_win_',
    );
    final logPath = p.join(directory.path, 'native.log');

    try {
      final override = WindowsTerminalDataSource().redirectStderr(
        targetPath: logPath,
      );

      expect(override, isNotNull);
      expect(override!.originalSink, isNotNull);
      expect(File(logPath).existsSync(), isTrue);

      await override.revert();
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
