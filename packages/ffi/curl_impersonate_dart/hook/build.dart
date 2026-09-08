import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;

    late final String assetDir;
    late final bool Function(String) isNativeLib;
    if (targetOS == OS.macOS && targetArch == Architecture.arm64) {
      assetDir = 'assets/native/macos/arm64';
      isNativeLib = (name) => name.endsWith('.dylib');
    } else if (targetOS == OS.macOS && targetArch == Architecture.x64) {
      assetDir = 'assets/native/macos/x64';
      isNativeLib = (name) => name.endsWith('.dylib');
    } else if (targetOS == OS.linux && targetArch == Architecture.x64) {
      assetDir = 'assets/native/linux/x64';
      isNativeLib = (name) => name.contains('.so');
    } else if (targetOS == OS.linux && targetArch == Architecture.arm64) {
      assetDir = 'assets/native/linux/arm64';
      isNativeLib = (name) => name.contains('.so');
    } else if (targetOS == OS.windows && targetArch == Architecture.x64) {
      assetDir = 'assets/native/windows/x64';
      isNativeLib = (name) => name.endsWith('.dll');
    } else {
      throw BuildError(
        message:
            'curl_impersonate_dart does not have prebuilt binaries for '
            '$targetOS/$targetArch. Add the appropriate binaries under '
            'assets/native and update hook/build.dart.',
      );
    }

    final packageRootDir = Directory.fromUri(input.packageRoot);
    final sourceDir = Directory(p.join(packageRootDir.path, assetDir));
    if (!sourceDir.existsSync()) {
      throw BuildError(
        message:
            'Missing prebuilt curl-impersonate binaries at ${sourceDir.path}. '
            'Run `dart tool/download_curl_assets.dart` from the repo root.',
      );
    }

    final libs = sourceDir
        .listSync()
        .whereType<File>()
        .where((f) => isNativeLib(p.basename(f.path)))
        .toList();

    if (libs.isEmpty) {
      throw BuildError(
        message: 'No native libraries found in ${sourceDir.path}.',
      );
    }

    final outputDir = Directory.fromUri(input.outputDirectoryShared);
    for (final sourceFile in libs) {
      final libName = p.basename(sourceFile.path);
      final resolvedSourcePath = sourceFile.resolveSymbolicLinksSync();
      final outputPath = p.join(outputDir.path, libName);
      File(resolvedSourcePath).copySync(outputPath);

      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: libName,
          linkMode: DynamicLoadingBundled(),
          file: File(outputPath).uri,
        ),
      );
    }
  });
}
