// Clears each package's generated native-asset directory so `dart run melos run
// setup` regenerates it. Deleting whole `assets/` directories — rather than
// enumerating individual files — keeps this robust as the build/download tools
// change what they emit.
//
// Safe: none of these directories hold committed files — the repo's vendored
// assets live at the root `assets/`, which this never touches.
//
// Usage:
//   dart run melos run clean:assets   # or: dart tool/clean_assets.dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/helpers.dart';

/// Repo-relative `assets/` directories cleared on clean: every package that
/// downloads or builds native assets.
const _assetDirs = <String>[
  'packages/ffi/curl_impersonate_dart/assets',
  'packages/ffi/posix_spawner/assets',
  'packages/infra/agent_shell/assets',
  'packages/infra/bestie_edit/assets',
  'packages/ffi/win32_dart/assets',
];

void main() {
  final root = repoRoot().path;
  var removed = 0;
  for (final rel in _assetDirs) {
    final dir = Directory(p.join(root, rel));
    if (!dir.existsSync()) continue;
    dir.deleteSync(recursive: true);
    stdout.writeln('  removed $rel');
    removed++;
  }
  stdout
    ..writeln(
      removed == 0
          ? 'clean: nothing to remove — already clean.'
          : 'clean: removed $removed asset directories.',
    )
    ..writeln('Run `dart run melos run setup` to regenerate for this host.');
}
