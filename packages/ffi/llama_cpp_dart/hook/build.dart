import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final layout = NativeLayout.forTarget(
      input.config.code.targetOS,
      input.config.code.targetArchitecture,
    );
    if (layout == null) return;

    final packageDir = Directory.fromUri(input.packageRoot).path;
    final sourceDir = Directory(p.join(packageDir, layout.assetDir));
    // Every existing folder on the way to the libraries, so staging or
    // restaging them rebuilds instead of reusing the cached output.
    final segments = p.split(layout.assetDir);
    final folders = [
      for (var depth = 0; depth <= segments.length; depth++)
        Directory(p.joinAll([packageDir, ...segments.take(depth)])),
    ];
    output.dependencies.addAll(
      folders
          .takeWhile((folder) => folder.existsSync())
          .map(
            (folder) => folder.uri,
          ),
    );
    // The libraries are opened by absolute path from the app-asset manifest,
    // so a checkout without them (CI jobs that skip the download, fresh
    // clones running pure-Dart tests) still builds; FFI tests skip instead.
    if (!sourceDir.existsSync()) return;

    final outputDir = Directory.fromUri(input.outputDirectoryShared);
    final libraries = sourceDir.listSync().whereType<File>().where(
      (file) => layout.isNativeLibrary(p.basename(file.path)),
    );
    for (final library in libraries) {
      output.dependencies.add(library.uri);
      final name = p.basename(library.path);
      final outputPath = p.join(outputDir.path, name);
      File(library.resolveSymbolicLinksSync()).copySync(outputPath);
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: name,
          linkMode: DynamicLoadingBundled(),
          file: File(outputPath).uri,
        ),
      );
    }
  });
}

/// Where one desktop target's prebuilt llama.cpp libraries live.
final class NativeLayout {
  const NativeLayout._({
    required this.os,
    required this.architecture,
    required this.assetDir,
    required this.extension,
  });

  final OS os;
  final Architecture architecture;
  final String assetDir;
  final String extension;

  bool isNativeLibrary(String name) =>
      name.toLowerCase().endsWith(extension) ||
      (extension == '.so' && name.contains('.so.'));

  static NativeLayout? forTarget(OS os, Architecture architecture) => _layouts
      .where((layout) => layout.os == os)
      .where(
        (layout) => layout.architecture == architecture,
      )
      .firstOrNull;

  static final _layouts = [
    const NativeLayout._(
      os: OS.macOS,
      architecture: Architecture.arm64,
      assetDir: 'assets/native/macos/arm64',
      extension: '.dylib',
    ),
    const NativeLayout._(
      os: OS.linux,
      architecture: Architecture.x64,
      assetDir: 'assets/native/linux/x64',
      extension: '.so',
    ),
    const NativeLayout._(
      os: OS.windows,
      architecture: Architecture.x64,
      assetDir: 'assets/native/windows/x64',
      extension: '.dll',
    ),
  ];
}
