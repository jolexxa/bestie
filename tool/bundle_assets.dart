// Stages every asset a platform ships into a release bundle's `lib/` (and
// root), driven entirely by that platform's `bundleAssets` manifest — the same
// list the app resolves at runtime. There is no hand-maintained copy list to
// drift from the manifest, and a final pass verifies every declared asset
// actually landed in the bundle, along with the llama.cpp libraries the
// bundled `bestie_server` loads.
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

import 'src/llama_release.dart';

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
      case AssetBundleUnit.ownerCliBundle:
        await _mergeCliBundle(asset, repoRoot, bundleDir, destination);
    }
  }

  _verify(target.assets, destination);
  _verifyLlamaLibraries(os, bundleDir);
  stdout.writeln(
    'Bundled ${target.assets.length} declared assets and the llama.cpp '
    'libraries — verified.',
  );
}

/// Builds the asset's Dart program with `dart build cli` into a directory
/// beside the bundle, then merges that build's bundle into this one. The
/// executable replaces an earlier build of itself; any other file must match
/// what the bundle already holds.
Future<void> _mergeCliBundle(
  AppAsset asset,
  String repoRoot,
  String bundleDir,
  AppAssetResolver destination,
) async {
  final packageDir = p.join(repoRoot, asset.packageOwner);
  final outputDir = p.join(p.dirname(bundleDir), p.basename(packageDir));
  final entryPoint = p.relative(
    p.join(repoRoot, asset.sourceScript),
    from: packageDir,
  );
  stdout.writeln('  dart build cli $entryPoint (${asset.packageOwner})');
  final build = await Process.start(
    'dart',
    ['build', 'cli', '--target', entryPoint, '--output', outputDir],
    workingDirectory: packageDir,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await build.exitCode;
  if (code != 0) {
    stderr.writeln('dart build cli failed for ${asset.packageOwner} ($code).');
    exit(1);
  }

  final builtBundle = Directory(p.join(outputDir, 'bundle'));
  final conflicts = <String>[];
  var merged = 0;
  for (final file in builtBundle.listSync(recursive: true).whereType<File>()) {
    final relative = p.relative(file.path, from: builtBundle.path);
    final target = File(p.join(bundleDir, relative));
    final isExecutable = p.equals(target.path, destination.pathFor(asset));
    if (isExecutable || !target.existsSync()) {
      target.parent.createSync(recursive: true);
      file.copySync(target.path);
      merged++;
    } else if (!_sameBytes(file, target)) {
      conflicts.add(relative);
    }
  }
  if (conflicts.isNotEmpty) {
    stderr.writeln(
      '${asset.packageOwner} would replace different files in the bundle:',
    );
    for (final conflict in conflicts) {
      stderr.writeln('  - $conflict');
    }
    exit(1);
  }
  stdout.writeln('  merged $merged files from ${asset.packageOwner}');
}

bool _sameBytes(File first, File second) {
  if (first.lengthSync() != second.lengthSync()) return false;
  final firstBytes = first.readAsBytesSync();
  final secondBytes = second.readAsBytesSync();
  for (var index = 0; index < firstBytes.length; index++) {
    if (firstBytes[index] != secondBytes[index]) return false;
  }
  return true;
}

/// Fails loudly unless the bundle's `lib/` carries every llama.cpp library
/// `bestie_server` needs on [os]. The llama hook bundles whatever is staged,
/// and nothing when nothing is, so a missing download only shows up here.
void _verifyLlamaLibraries(String os, String bundleDir) {
  final platform = llamaPlatforms.firstWhere((platform) => platform.os == os);
  final libDir = p.join(bundleDir, 'lib');
  final missing = [
    for (final library in platform.requiredLibraries)
      if (!File(p.join(libDir, library)).existsSync()) library,
  ];
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Bundle is missing llama.cpp libraries in $libDir '
      '(run `dart tool/download_llama_assets.dart --os $os`):',
    );
    for (final library in missing) {
      stderr.writeln('  - $library');
    }
    exit(1);
  }
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
