// Regenerates the third-party licence bundles for the Rust sidecars.
//
// Every sidecar is a statically linked binary, so shipping it ships its whole
// crate tree. This walks each crate's Cargo.lock with cargo-about and writes
// the verbatim licence text of everything that links, into
// assets/third_party_licenses/, where tool/build_licenses.dart picks it up.
//
// Run after bumping a version in tool/src/shell_sidecars.dart or changing the
// editor crate's dependencies, and commit the result — the texts are vendored
// so a release never depends on the network.
//
//   dart tool/build_shell_licenses.dart
//
// Needs the published crates' sources in the cargo registry, which
// `build:sidecars` puts there, and cargo-about:
//
//   cargo install cargo-about --locked --features cli

import 'dart:io';

import 'src/helpers.dart';
import 'src/shell_sidecars.dart';

const _noticeDir = 'assets/third_party_licenses';
const _configDir = 'tool/licenses';

Future<void> main() async {
  final root = repoRoot().path;

  if (!await _hasCargoAbout()) {
    stderr.writeln(
      'cargo-about is not on PATH. Install it with:\n'
      '  cargo install cargo-about --locked --features cli',
    );
    exitCode = 1;
    return;
  }

  for (final sidecar in sidecars) {
    final manifest = _manifestFor(sidecar, root);
    if (manifest == null) {
      stderr.writeln(
        '${sidecar.crate} ${sidecar.version} is not in the cargo registry. '
        'Run `dart tool/build_sidecar.dart ${sidecar.name}` first so cargo '
        'fetches it.',
      );
      exitCode = 1;
      return;
    }

    final out = File('$root/$_noticeDir/${sidecar.noticeName}.txt');
    stdout.writeln('=== ${sidecar.crate} ${sidecar.version} ===');

    final result = await Process.run('cargo', [
      'about',
      'generate',
      '--config',
      '$root/$_configDir/about.toml',
      '$root/$_configDir/about.hbs',
      '--locked',
      if (sidecar is CratesIOSidecar) ...sidecar.featureArgs,
      '--manifest-path',
      manifest,
    ]);

    if (result.exitCode != 0) {
      stderr
        ..writeln('cargo-about failed for ${sidecar.crate}:')
        ..writeln(result.stderr);
      exitCode = 1;
      return;
    }

    out.parent.createSync(recursive: true);
    out.writeAsStringSync(_header(sidecar) + (result.stdout as String));
    stdout.writeln('=> ${out.path} (${out.lengthSync()} bytes)');
  }
}

Future<bool> _hasCargoAbout() async {
  try {
    final result = await Process.run('cargo', ['about', '--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Where the crate's manifest is: in this repository for a crate of our own,
/// else the unpacked source cargo left in its registry — null when the crate
/// has never been fetched.
String? _manifestFor(Sidecar sidecar, String root) {
  if (sidecar is LocalSidecar) return '$root/${sidecar.crateDir}/Cargo.toml';
  final home =
      Platform.environment['CARGO_HOME'] ??
      '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}'
          '/.cargo';
  final sources = Directory('$home/registry/src');
  if (!sources.existsSync()) return null;

  for (final index in sources.listSync().whereType<Directory>()) {
    final manifest = File(
      '${index.path}/${sidecar.crate}-${sidecar.version}/Cargo.toml',
    );
    if (manifest.existsSync()) return manifest.path;
  }
  return null;
}

String _header(Sidecar sidecar) => switch (sidecar) {
  CratesIOSidecar() =>
    '''
Bestie ships the `${sidecar.crate}` binary, statically linked, so the verbatim
licence text of every crate that binary links follows — the project's own
licence among them.
${_footer(sidecar)}''',
  LocalSidecar() =>
    '''
Bestie's own `${sidecar.crate}` binary is statically linked, so the verbatim
licence text of every third-party crate it links follows.
${_footer(sidecar)}''',
};

String _footer(Sidecar sidecar) =>
    '''

Version:   ${sidecar.crate} ${sidecar.version}
Generated: dart tool/build_shell_licenses.dart (cargo-about)

''';
