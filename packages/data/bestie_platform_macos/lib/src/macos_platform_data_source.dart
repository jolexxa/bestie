import 'dart:ffi';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';

@dataSource
class MacOSPlatformDataSource {
  MacOSPlatformDataSource({
    required this.platform,
    required this.fileSystem,
    required this.abi,
    required this.bundled,
    required this.assets,
  });

  final Platform platform;

  final FileSystem fileSystem;
  final Abi abi;

  /// Whether bestie runs from a release bundle rather than the source tree.
  final bool bundled;

  /// The native assets this platform resolves and ships.
  final PosixAppAssets assets;

  AppAssetResolver get _resolver => AppAssetResolver(
    bundled: bundled,
    fileSystem: fileSystem,
    executableDir: p.dirname(platform.resolvedExecutable),
    repoRoot: _repoRoot,
    platformDir: 'macos',
    archDir: 'arm64',
  );

  /// Absolute path of the bundled `spawner` helper binary.
  String resolveSpawnerPath() => _resolver.resolve(assets.spawner);

  /// Absolute path of the bundled `bestie_edit` program.
  String resolveEditorPath() => _resolver.resolve(assets.editor);

  /// The resolved shell userland (brush + the coreutils multicall). Throws
  /// [StateError] if it isn't bundled — the confined shell is required, like
  /// every other native asset.
  ShellUserland resolveShellUserland() {
    final binDir = _resolver.resolve(assets.shared.shellBin);
    return ShellUserland(
      binDir: binDir,
      shellPath: fileSystem.path.join(binDir, ShellExecutables.posix.brushName),
      executables: ShellExecutables.posix,
    );
  }

  OSPlatform loadPlatform() {
    if (abi != Abi.macosArm64) {
      throw UnsupportedError('Unsupported architecture: $abi');
    }

    final resolver = _resolver;

    final homeDir = resolveHomeDir(platform.environment);
    final bestieDir = bestieDirFor(homeDir, p.posix);
    return MacOSPlatform(
      architecture: OSArchitecture.macosArm64,
      homeDir: homeDir,
      tempDir: resolvePosixTempDir(platform.environment),
      bestieDir: bestieDir,
      configFile: configFileFor(bestieDir, p.posix),
      conversationsDir: conversationsDirFor(bestieDir, p.posix),
      curlLibraryPath: resolver.resolve(assets.curl),
      caCertPath: resolver.resolve(assets.shared.caCert),
      creditsPath: resolver.resolve(assets.shared.credits),
    );
  }

  String get _repoRoot {
    final scriptDir = p.dirname(platform.script.toFilePath());
    return p.normalize(p.join(scriptDir, '..', '..', '..'));
  }
}
