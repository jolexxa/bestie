// Stages every asset a platform ships into a release bundle's `lib/` (and
// root), driven entirely by that platform's `bundleAssets` manifest — the same
// list the app resolves at runtime. There is no hand-maintained copy list to
// drift from the manifest, and a final pass verifies every declared asset
// actually landed in the bundle.
//
// Usage:
//   dart tool/bundle_assets.dart <bundle_dir>              # host platform
//   dart tool/bundle_assets.dart --os windows <bundle_dir> # explicit target
//
// Runs natively on each release matrix runner, so it only ever needs the
// current target's manifest.

import 'dart:io';

import 'package:args/args.dart';
import 'package:bestie/src/app/assets/app_assets.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

/// A release target: its manifest and the `native/<os>/<arch>` coordinates the
/// resolver stamps into source paths.
class _Target {
  const _Target({
    required this.assets,
    required this.platformDir,
    required this.archDir,
  });

  final List<AppAsset> assets;
  final String platformDir;
  final String archDir;
}

final _targets = <String, _Target>{
  'linux': _Target(
    assets: linuxAppAssets.bundleAssets,
    platformDir: 'linux',
    archDir: 'x64',
  ),
  'macos': _Target(
    assets: macOSAppAssets.bundleAssets,
    platformDir: 'macos',
    archDir: 'arm64',
  ),
  'windows': _Target(
    assets: windowsAppAssets.bundleAssets,
    platformDir: 'windows',
    archDir: 'x64',
  ),
};

const _fs = LocalFileSystem();

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'os',
      abbr: 'o',
      allowed: _targets.keys,
      help: 'Target OS family. Defaults to the host.',
    );
  final parsed = parser.parse(args);

  if (parsed.rest.length != 1) {
    stderr.writeln(
      'Usage: dart tool/bundle_assets.dart [--os <os>] <bundle_dir>',
    );
    exit(64);
  }
  final bundleDir = p.normalize(p.absolute(parsed.rest.single));

  final osArg = parsed['os'] as String?;
  final os = osArg ?? _hostOs();
  final target = _targets[os];
  if (target == null) {
    stderr.writeln('Unsupported target OS: $os');
    exit(64);
  }

  final repoRoot = _repoRoot();
  final source = AppAssetResolver(
    bundled: false,
    fileSystem: _fs,
    executableDir: '',
    repoRoot: repoRoot,
    platformDir: target.platformDir,
    archDir: target.archDir,
  );
  final destination = AppAssetResolver(
    bundled: true,
    fileSystem: _fs,
    // A phantom `bin/` so the bundled layout's `bin/../<subdir>` lands the
    // asset under `<bundle_dir>/<subdir>`.
    executableDir: p.join(bundleDir, 'bin'),
    repoRoot: '',
    platformDir: target.platformDir,
    archDir: target.archDir,
  );

  stdout.writeln('Bundling $os assets into $bundleDir');

  final copiedDirs = <String>{};
  for (final asset in target.assets) {
    switch (asset.bundleUnit) {
      case AssetBundleUnit.ownerNativeDir:
        _copyOwnerNativeDir(asset, source, destination, copiedDirs);
      case AssetBundleUnit.assetPath:
        _copyAssetPath(asset, source, destination);
    }
  }

  _verify(target.assets, destination);
  stdout.writeln('Bundled ${target.assets.length} declared assets — verified.');
}

/// Copies the whole `assets/native/<os>/<arch>/` directory the asset lives in
/// (once per source directory), so every co-located sibling library ships.
void _copyOwnerNativeDir(
  AppAsset asset,
  AppAssetResolver source,
  AppAssetResolver destination,
  Set<String> copiedDirs,
) {
  final srcDir = p.dirname(source.pathFor(asset));
  if (!copiedDirs.add(srcDir)) return;

  final destDir = p.dirname(destination.pathFor(asset));
  final dir = Directory(srcDir);
  if (!dir.existsSync()) {
    stderr.writeln('Missing source directory for ${asset.path}: $srcDir');
    exit(1);
  }
  _copyDirContents(dir, destDir);
  stdout.writeln(
    '  dir  ${p.relative(srcDir, from: source.repoRoot)} -> '
    '${p.basename(destDir)}/',
  );
}

/// Copies exactly the asset's declared path — a file or a subdirectory.
void _copyAssetPath(
  AppAsset asset,
  AppAssetResolver source,
  AppAssetResolver destination,
) {
  final srcPath = source.pathFor(asset);
  final destPath = destination.pathFor(asset);
  final type = _fs.typeSync(srcPath);
  if (type == FileSystemEntityType.notFound) {
    stderr.writeln('Missing source asset ${asset.path}: $srcPath');
    exit(1);
  }
  if (type == FileSystemEntityType.directory) {
    _copyDirContents(Directory(srcPath), destPath);
  } else {
    Directory(p.dirname(destPath)).createSync(recursive: true);
    File(srcPath).copySync(destPath);
  }
  stdout.writeln('  file ${asset.path}');
}

/// Fails loudly if any declared asset is absent from the finished bundle
void _verify(List<AppAsset> assets, AppAssetResolver destination) {
  final missing = [
    for (final asset in assets)
      if (_fs.typeSync(destination.pathFor(asset)) ==
          FileSystemEntityType.notFound)
        '${asset.path} (${destination.pathFor(asset)})',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Bundle is missing declared assets:');
    for (final entry in missing) {
      stderr.writeln('  - $entry');
    }
    exit(1);
  }
}

void _copyDirContents(Directory src, String destDir) {
  Directory(destDir).createSync(recursive: true);
  for (final entity in src.listSync(recursive: true, followLinks: false)) {
    // The confined shell's per-utility dispatch links and their marker are
    // runtime state.
    if (entity is Link) continue;
    if (p.basename(entity.path) == '.coreutils-linked') continue;
    final rel = p.relative(entity.path, from: src.path);
    final dest = p.join(destDir, rel);
    if (entity is Directory) {
      Directory(dest).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(dest)).createSync(recursive: true);
      entity.copySync(dest);
    }
  }
}

String _hostOs() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  stderr.writeln('Unsupported host OS: ${Platform.operatingSystem}');
  exit(64);
}

String _repoRoot() =>
    p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'));
