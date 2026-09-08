// Build the Rust sidecars Bestie ships: the agent shell's userland (brush,
// coreutils, ripgrep, findutils, sed) and Bestie's own file editor.
//
// Published crates are installed with `cargo install` so we consume the exact
// upstream binaries without vendoring their workspaces; in-repo crates are
// built in place. Every build shares one repo-local cargo target directory,
// so CI can cache it. Windows builds target msvc with a static CRT.
//
// Usage:
//   dart tool/build_sidecar.dart <name>     # brush, coreutils, ripgrep, ...
//   dart tool/build_sidecar.dart --all
//
// Run once per platform/arch you intend to ship from. `cargo` must be on PATH.
//
// The coreutils build produces only the multicall binary. Its per-utility
// links (ls, cat, ...) are materialized at each destination the userland
// `bin/` lands, because baking them into a stored directory would make every
// later copy of that directory duplicate the ~12 MB binary once per name.
import 'dart:io';

import 'src/helpers.dart';
import 'src/shell_sidecars.dart';

Future<void> main(List<String> args) async {
  final selected = _select(args);
  if (selected == null) {
    stderr.writeln(
      'Usage: dart tool/build_sidecar.dart <name> | --all\n'
      'Names: ${[for (final sidecar in sidecars) sidecar.name].join(', ')}',
    );
    exitCode = 64;
    return;
  }

  final root = repoRoot().path;
  for (final sidecar in selected) {
    final built = await _build(sidecar, root);
    if (!built) {
      exitCode = 1;
      return;
    }
  }
}

List<Sidecar>? _select(List<String> args) {
  if (args.length != 1) return null;
  if (args.single == '--all') return sidecars;
  for (final sidecar in sidecars) {
    if (sidecar.name == args.single) return [sidecar];
  }
  return null;
}

Future<bool> _build(Sidecar sidecar, String root) async {
  stdout.writeln(
    '=== building ${sidecar.crate} ${sidecar.version} (cargo) ===',
  );
  final targetDir = cargoTargetDir(root);
  final String binDir;
  switch (sidecar) {
    case CratesIOSidecar():
      final stageRoot = shellStageRoot(root);
      final code = await cargoInstallCrate(
        crate: sidecar.crate,
        version: sidecar.version,
        stageRoot: stageRoot,
        targetDir: targetDir,
        featureArgs: sidecar.featureArgs,
      );
      if (code != 0) return false;
      binDir = '$stageRoot/bin';
    case LocalSidecar():
      final releaseDir = await cargoBuildRelease(
        crateDir: '$root/${sidecar.crateDir}',
        targetDir: targetDir,
        locked: true,
      );
      if (releaseDir == null) return false;
      binDir = '$root/${sidecar.assetOwner}/assets/native/${hostAssetSubdir()}';
      Directory(binDir).createSync(recursive: true);
      for (final binary in sidecar.binaries) {
        final name = _exeName(binary);
        final dest = '$binDir/$name';
        File('$releaseDir/$name').copySync(dest);
        if (!Platform.isWindows) await runCommand('chmod', ['+x', dest]);
      }
  }
  return _verify(sidecar, binDir);
}

bool _verify(Sidecar sidecar, String binDir) {
  for (final binary in sidecar.binaries) {
    final installed = File('$binDir/${_exeName(binary)}');
    if (!installed.existsSync()) {
      stderr.writeln(
        '${sidecar.name}: cargo did not produce ${installed.path}',
      );
      return false;
    }
    stdout.writeln('=> ${installed.path}');
  }
  return true;
}

String _exeName(String binary) => Platform.isWindows ? '$binary.exe' : binary;
