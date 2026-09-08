import 'dart:ffi';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:win32_dart/win32_dart.dart';

@dataSource
class WindowsPlatformDataSource {
  WindowsPlatformDataSource({
    required this.platform,
    required this.fileSystem,
    required this.abi,
    required this.bundled,
    required this.assets,
    DllSearchPath? dllSearchPath,
  }) : _dllSearchPath = dllSearchPath ?? DllSearchPath(win32);

  final Platform platform;
  final FileSystem fileSystem;
  final Abi abi;

  /// Whether bestie runs from a release bundle rather than the source tree.
  final bool bundled;

  /// The native assets this platform resolves and ships.
  final WindowsAppAssets assets;

  final DllSearchPath _dllSearchPath;

  AppAssetResolver get _resolver => AppAssetResolver(
    bundled: bundled,
    fileSystem: fileSystem,
    executableDir: p.dirname(platform.resolvedExecutable),
    repoRoot: _repoRoot,
    platformDir: 'windows',
    archDir: 'x64',
  );

  /// The resolved shell userland (brush + the coreutils multicall). Throws
  /// [StateError] if it isn't bundled — the confined shell is required, like
  /// every other native asset.
  ShellUserland resolveShellUserland() {
    final binDir = _resolver.resolve(assets.shared.shellBin);
    return ShellUserland(
      binDir: binDir,
      shellPath: fileSystem.path.join(
        binDir,
        ShellExecutables.windows.brushName,
      ),
      executables: ShellExecutables.windows,
    );
  }

  /// Absolute path of the bundled `bestie_edit` program.
  String resolveEditorPath() => _resolver.resolve(assets.editor);

  /// The resolved console host. Throws [StateError] if either half is
  /// missing — the library alone would fall back to the console that came
  /// with Windows, which is the behaviour shipping one is meant to replace.
  ConsoleHost resolveConsoleHost() {
    final resolver = _resolver;
    return ConsoleHost(
      libraryPath: resolver.resolve(assets.conptyLibrary),
      executablePath: resolver.resolve(assets.consoleHostExecutable),
    );
  }

  OSPlatform loadPlatform() {
    if (abi != Abi.windowsX64) {
      throw UnsupportedError('bestie requires 64-bit x86 Windows.');
    }

    final resolver = _resolver;
    final curlLibraryPath = resolver.resolve(assets.curl);

    // A library opened by absolute path still loads any by-name siblings
    // through the search path, so the native library directory joins it.
    final searched = _dllSearchPath.use(
      fileSystem.path.dirname(curlLibraryPath),
    );
    if (searched case DllSearchPathFailed(:final failure)) {
      throw StateError('Could not prepare the library search path: $failure');
    }

    final homeDir = resolveHomeDir(platform.environment);
    final bestieDir = bestieDirFor(homeDir, p.windows);
    return WindowsPlatform(
      architecture: OSArchitecture.windowsX64,
      homeDir: homeDir,
      tempDir: resolveWindowsTempDir(platform.environment, homeDir: homeDir),
      bestieDir: bestieDir,
      configFile: configFileFor(bestieDir, p.windows),
      conversationsDir: conversationsDirFor(bestieDir, p.windows),
      curlLibraryPath: curlLibraryPath,
      caCertPath: resolver.resolve(assets.shared.caCert),
      creditsPath: resolver.resolve(assets.shared.credits),
    );
  }

  String get _repoRoot {
    final scriptDir = p.dirname(platform.script.toFilePath());
    return p.normalize(p.join(scriptDir, '..', '..', '..'));
  }
}
