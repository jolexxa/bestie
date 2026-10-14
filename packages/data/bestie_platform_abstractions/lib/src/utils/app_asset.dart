import 'package:bestie_platform_abstractions/src/models/program_command.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

/// How the release bundler copies an [AppAsset] out of the source tree.
enum AssetBundleUnit {
  /// Copy exactly this asset's [AppAsset.path] — a single file or a subdir.
  assetPath,

  /// Copy the owning package's entire `assets/native/<os>/<arch>/` directory.
  ownerNativeDir,

  /// Build the owning package's [AppAsset.sourceScript] with `dart build cli`
  /// and merge that bundle in: the executable and the native libraries its
  /// dependencies' build hooks produced.
  ownerCliBundle,
}

/// A file bestie ships and locates at runtime — a native library, a helper
/// binary, a data file, or a bundled doc.
@model
final class AppAsset {
  const AppAsset({
    required this.path,
    required this.missingMessage,
    this.packageOwner,
    this.isPlatformSpecific = true,
    this.bundleSubdir = 'lib',
    this.bundleUnit = AssetBundleUnit.assetPath,
    this.sourceScript,
  });

  /// Location relative to a base directory: a file leaf,
  /// a subdirectory, or empty for the base directory itself..
  final String path;

  /// Actionable message shown when the asset is missing.
  final String missingMessage;

  /// In a source checkout, the repo-relative directory of the owning
  /// package. Null for a repo-level file (docs).
  final String? packageOwner;

  /// Whether the source-tree copy lives under
  /// `assets/native/<platform>/<arch>/` (true) or a platform-independent
  /// `assets/` (false).
  final bool isPlatformSpecific;

  /// Subdirectory of the release bundle the asset ships in.
  final String bundleSubdir;

  /// What the release bundler copies for this asset.
  final AssetBundleUnit bundleUnit;

  /// For a program written in Dart, the repo-relative script a source
  /// checkout runs in place of the built executable.
  final String? sourceScript;
}

/// Resolves an [AppAsset] to its one expected path for the current run.
///
/// Deterministic: [bundled] (read from `dart.vm.product` at the composition
/// root) selects the release-bundle layout or the source-tree layout, and each
/// branch computes exactly one path — no candidate search, no sentinel.
@model
class AppAssetResolver {
  const AppAssetResolver({
    required this.bundled,
    required this.fileSystem,
    required this.executableDir,
    required this.repoRoot,
    required this.platformDir,
    required this.archDir,
  });

  /// Whether bestie runs from a release bundle (`bin/` + `lib/`) rather than
  /// the source tree.
  final bool bundled;

  final FileSystem fileSystem;

  /// Directory of the running executable — the bundle anchor.
  final String executableDir;

  /// Repo root — the source-tree anchor (unused when [bundled]).
  final String repoRoot;

  final String platformDir;
  final String archDir;

  p.Context get _p => fileSystem.path;

  /// The verified absolute path of [asset], throwing [StateError] with the
  /// asset's [AppAsset.missingMessage] when nothing exists there.
  String resolve(AppAsset asset) {
    final path = pathFor(asset);
    if (fileSystem.typeSync(path) == FileSystemEntityType.notFound) {
      throw StateError('${asset.missingMessage} Expected at: $path');
    }
    return path;
  }

  /// The expected path of [asset] for the current environment, without
  /// verifying it exists.
  String pathFor(AppAsset asset) {
    final segments = bundled
        ? [executableDir, '..', asset.bundleSubdir]
        : _devBase(asset);
    final base = _p.joinAll(segments.where((segment) => segment.isNotEmpty));
    final full = asset.path.isEmpty ? base : _p.join(base, asset.path);
    return _p.normalize(full);
  }

  /// How to start the program [asset] ships, without verifying it exists:
  /// an optional program that is missing should fail when started, not when
  /// bestie starts. A bundle runs the executable itself; a source checkout
  /// has [dartExecutable] run the asset's [AppAsset.sourceScript], so nothing
  /// needs building first.
  ProgramCommand commandFor(
    AppAsset asset, {
    required String dartExecutable,
  }) => bundled
      ? ProgramCommand(executable: pathFor(asset))
      : ProgramCommand(
          executable: dartExecutable,
          arguments: [
            'run',
            _p.normalize(_p.join(repoRoot, asset.sourceScript)),
          ],
        );

  List<String> _devBase(AppAsset asset) {
    final owner = asset.packageOwner;
    if (owner == null) return [repoRoot];
    return asset.isPlatformSpecific
        ? [repoRoot, owner, 'assets', 'native', platformDir, archDir]
        : [repoRoot, owner, 'assets'];
  }
}
