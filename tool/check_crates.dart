// Formats, lints, and tests bestie's own Rust crates against the shared cargo
// target directory, skipping crates that do not build on the current host.
//
// Usage:
//   dart tool/check_crates.dart               # every crate
//   dart tool/check_crates.dart edit spawner  # just these
import 'dart:io';

import 'src/helpers.dart';

Future<void> main(List<String> args) async {
  final unknown = args.where(
    (name) => !_crates.any((crate) => crate.name == name),
  );
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unknown crate(s): ${unknown.join(', ')}. '
      'Known: ${_crates.map((crate) => crate.name).join(', ')}.',
    );
    exitCode = 64;
    return;
  }

  final root = repoRoot().path;
  final targetDir = cargoTargetDir(root);
  final selected = _crates.where(
    (crate) => args.isEmpty || args.contains(crate.name),
  );

  for (final crate in selected) {
    if (crate.skipOnHost) {
      stdout.writeln('skip: ${crate.name} (${crate.skipReason})');
      continue;
    }
    final manifest = ['--manifest-path', '$root/${crate.manifestPath}'];
    final target = ['--target-dir', targetDir];
    final commands = [
      ['fmt', ...manifest, '--check'],
      ['clippy', ...manifest, ...target, '--tests', '--', '-D', 'warnings'],
      ['test', ...manifest, ...target],
    ];
    for (final command in commands) {
      stdout.writeln('\n=== ${crate.name}: cargo ${command.first} ===');
      final code = await runCommand('cargo', command);
      if (code != 0) {
        stderr.writeln('${crate.name}: cargo ${command.first} failed ($code).');
        exitCode = code;
        return;
      }
    }
  }
}

final _crates = [
  const RustCrate(
    name: 'edit',
    manifestPath: 'packages/infra/bestie_edit/bestie_edit/Cargo.toml',
  ),
  const RustCrate(
    name: 'guard',
    manifestPath: 'packages/ffi/posix_spawner/bestie_guard/Cargo.toml',
  ),
  RustCrate(
    name: 'spawner',
    manifestPath: 'packages/ffi/posix_spawner/spawner/Cargo.toml',
    skipOnHost: Platform.isWindows,
    skipReason: 'POSIX-only',
  ),
];

/// One of bestie's own Rust crates.
class RustCrate {
  const RustCrate({
    required this.name,
    required this.manifestPath,
    this.skipOnHost = false,
    this.skipReason = '',
  });

  /// Short name used to select the crate on the command line.
  final String name;

  /// Cargo manifest path relative to the repository root.
  final String manifestPath;

  /// Whether the crate does not build on the current host.
  final bool skipOnHost;

  /// Why the crate is skipped, shown when [skipOnHost] is set.
  final String skipReason;
}
