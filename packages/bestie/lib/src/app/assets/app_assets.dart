import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';

/// Assets that every platform needs.
const sharedAppAssets = SharedAppAssets(
  caCert: AppAsset(
    path: 'cacert.pem',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    isPlatformSpecific: false,
    missingMessage:
        'CA certificate bundle (cacert.pem) not found. Run '
        '`dart tool/download_cert_assets.dart` from the repo root.',
  ),
  credits: AppAsset(
    path: 'CREDITS.md',
    bundleSubdir: '',
    missingMessage: 'Credits file (CREDITS.md) not found.',
  ),
  // Platform-specific -- the correct version of the shell will be resolved
  // based on the host platform.
  shellBin: AppAsset(
    path: 'shell/bin',
    packageOwner: 'packages/infra/agent_shell',
    missingMessage:
        'Shell userland (brush, coreutils, ripgrep, findutils, sed) not '
        'built. Run `dart tool/build_sidecar.dart --all` from the repo root.',
  ),
);

const posixSpawner = AppAsset(
  path: 'spawner',
  packageOwner: 'packages/ffi/posix_spawner',
  bundleUnit: AssetBundleUnit.ownerNativeDir,
  missingMessage:
      'Spawner helper (`spawner`) not found. Run '
      '`dart tool/build_spawner.dart` from the repo root.',
);

/// The program behind the edit tool, built like the spawner is.
const posixEditor = AppAsset(
  path: 'bestie_edit',
  packageOwner: 'packages/infra/bestie_edit',
  bundleUnit: AssetBundleUnit.ownerNativeDir,
  missingMessage:
      'Editor (`bestie_edit`) not found. Run '
      '`dart tool/build_sidecar.dart edit` from the repo root.',
);

/// The native assets bestie resolves and ships on macOS.
const macOSAppAssets = PosixAppAssets(
  curl: AppAsset(
    path: 'libcurl-impersonate.dylib',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Curl library (libcurl-impersonate.dylib) not found.',
  ),
  spawner: posixSpawner,
  editor: posixEditor,
  shared: sharedAppAssets,
);

/// The native assets bestie resolves and ships on Linux.
const linuxAppAssets = PosixAppAssets(
  curl: AppAsset(
    path: 'libcurl-impersonate.so',
    packageOwner: 'packages/ffi/curl_impersonate_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage: 'Curl library (libcurl-impersonate.so) not found.',
  ),
  spawner: posixSpawner,
  editor: posixEditor,
  shared: sharedAppAssets,
);

/// The native assets bestie resolves and ships on Windows.
const windowsAppAssets = WindowsAppAssets(
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
    missingMessage:
        'Console host library (conpty.dll) not found. Run '
        '`dart tool/download_openconsole_assets.dart` from the repo root.',
  ),
  consoleHostExecutable: AppAsset(
    path: 'OpenConsole.exe',
    packageOwner: 'packages/ffi/win32_dart',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage:
        'Console host (OpenConsole.exe) not found. Run '
        '`dart tool/download_openconsole_assets.dart` from the repo root.',
  ),
  editor: AppAsset(
    path: 'bestie_edit.exe',
    packageOwner: 'packages/infra/bestie_edit',
    bundleUnit: AssetBundleUnit.ownerNativeDir,
    missingMessage:
        'Editor (`bestie_edit.exe`) not found. Run '
        '`dart tool/build_sidecar.dart edit` from the repo root.',
  ),
  shared: sharedAppAssets,
);
