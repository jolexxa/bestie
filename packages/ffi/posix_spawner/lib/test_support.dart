import 'dart:io';
import 'dart:isolate';

import 'package:meta/meta.dart';

/// Locates the repo-built `spawner` helper for the tests and dev tools that
/// drive a real pty — process_host_posix's integration tests,
/// agentic_terminal's harness, and vt_parser's fixture recorder. posix_spawner
/// owns the binary, so it owns the lookup.
///
/// The asset directory is resolved from the running isolate's package config
/// (`Isolate.resolvePackageUri`), so it is correct from any working directory
/// and encodes no assumption about where a consumer package sits in the tree.
///
/// Production never uses this: bestie injects a fully-qualified spawner path
/// into `PosixProcessHost` (`spawnerBinaryPath:`). Kept off the main barrel —
/// reach it via `package:posix_spawner/test_support.dart` — so it can't be
/// mistaken for library API. `tool/build_spawner.dart` builds the binary into
/// this package's `assets/native/<os>/<arch>/` directory.
@visibleForTesting
class RepoSpawnerLocator {
  /// Creates a locator.
  const RepoSpawnerLocator();

  /// Returns the absolute `spawner` path, or null when it has not been built
  /// (or the package can't be resolved — e.g. an AOT binary with no package
  /// config).
  Future<String?> locate() async {
    final libRoot = await Isolate.resolvePackageUri(
      Uri.parse('package:posix_spawner/'),
    );
    if (libRoot == null) return null;
    final spawner = libRoot.resolve('../assets/native/$_assetDir/spawner');
    final path = spawner.toFilePath();
    return File(path).existsSync() ? path : null;
  }

  /// The `<platform>/<arch>` asset fragment for the host. The spawner is
  /// POSIX-only, so only macOS and Linux are supported.
  String get _assetDir {
    if (Platform.isMacOS) return 'macos/arm64';
    if (Platform.isLinux) return 'linux/x64';
    throw UnsupportedError(
      'RepoSpawnerLocator: unsupported platform ${Platform.operatingSystem}',
    );
  }
}
