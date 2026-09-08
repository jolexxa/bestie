// Stamps the bestie release version into
// `packages/bestie/lib/src/app/models/bestie_version.dart` (reported by
// `AppMetadata.version`) and `packages/bestie/pubspec.yaml`.
//
// Used by `.github/workflows/release.yaml` because `dart build cli` does
// not accept compile-time `--define` flags. The committed tree keeps the
// `0.0.0` dev placeholder; `--check` fails if a stamp has leaked into it.
//
// Usage:
//   dart tool/set_version.dart <version>
//   dart tool/set_version.dart --check

import 'dart:io';

import 'src/helpers.dart';

const devVersion = '0.0.0';

void main(List<String> args) {
  if (args.length != 1 || args.first.isEmpty) {
    stderr.writeln('Usage: dart tool/set_version.dart <version> | --check');
    exit(1);
  }

  final files = _VersionFiles(repoRoot().path);
  if (args.first == '--check') {
    exit(files.check() ? 0 : 1);
  }
  files.write(args.first);
}

class _VersionFiles {
  _VersionFiles(String root)
    : constant = File(
        '$root/packages/bestie/lib/src/app/models/bestie_version.dart',
      ),
      pubspec = File('$root/packages/bestie/pubspec.yaml');

  final File constant;
  final File pubspec;

  static final _pubspecVersion = RegExp(r'^version: .*$', multiLine: true);

  void write(String version) {
    constant.writeAsStringSync(
      '// Overwritten by `dart tool/set_version.dart <version>` during release\n'
      "// builds. The committed tree keeps the '$devVersion' dev placeholder.\n"
      "const String bestieVersion = '$version';\n",
    );
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst(
        _pubspecVersion,
        'version: $version',
      ),
    );
    stdout.writeln('Wrote bestieVersion=$version to ${constant.path}');
    stdout.writeln('Wrote version: $version to ${pubspec.path}');
  }

  bool check() {
    final leaks = [
      if (!constant.readAsStringSync().contains("'$devVersion'")) constant.path,
      if (_pubspecVersion.firstMatch(pubspec.readAsStringSync())?.group(0) !=
          'version: $devVersion')
        pubspec.path,
    ];
    for (final path in leaks) {
      stderr.writeln('$path does not hold the $devVersion dev placeholder');
    }
    return leaks.isEmpty;
  }
}
