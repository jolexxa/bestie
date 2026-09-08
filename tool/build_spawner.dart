// Build the `spawner` Rust helper used by posix_spawner's PTY spawn
// path, and copy the result into the asset directory that
// `NativeLibraryResolver` searches.
//
// Usage:
//   dart tool/build_spawner.dart
//
// Run this once on each platform/arch you intend to ship from.
// Contributors run it once after cloning; CI runs it in the release
// pipeline before the bundle step.
import 'dart:io';

import 'src/helpers.dart';

Future<void> main(List<String> args) async {
  if (Platform.isWindows) {
    stderr.writeln('spawner: POSIX only; Windows spawns through ConPTY.');
    exitCode = 1;
    return;
  }
  final root = repoRoot().path;
  stdout.writeln('=== building spawner (cargo) ===');
  final releaseDir = await cargoBuildRelease(
    crateDir: '$root/packages/ffi/posix_spawner/spawner',
    targetDir: cargoTargetDir(root),
  );
  if (releaseDir == null) {
    exitCode = 1;
    return;
  }

  final builtPath = '$releaseDir/spawner';
  if (!File(builtPath).existsSync()) {
    stderr.writeln('spawner: cargo build did not produce $builtPath');
    exitCode = 1;
    return;
  }

  final destDir = Directory(
    '$root/packages/ffi/posix_spawner/assets/native/${hostAssetSubdir()}',
  );
  destDir.createSync(recursive: true);
  final dest = '${destDir.path}/spawner';
  File(builtPath).copySync(dest);
  await runCommand('chmod', ['+x', dest]);

  stdout.writeln('=> $dest');
}
