// To run:
// dart tool/cloc.dart             # by-package Dart breakdown (default)
// dart tool/cloc.dart --tests     # include test/

import 'dart:convert';
import 'dart:io';

import 'src/helpers.dart';

const _ffiPackageNames = {'curl_impersonate_dart', 'posix_dart'};

final _excludeDirsBase = [
  'external',
  '.dart_tool',
  '.build',
  '.fvm',
  'coverage',
  'build',
  'third_party',
  '.pub-cache',
  '.idea',
  '.claude',
  // Exclude FFI binding packages (mostly generated code).
  ..._ffiPackageNames,
];

const _generatedDartFilePattern =
    r'\.(g|freezed|mapper|mocks)\.dart$|\.pb(json)?\.dart$|_bindings_stubs\.dart$';

Future<void> main(List<String> args) async {
  final root = repoRoot().path;
  final includeTests = args.contains('--tests');
  final targets = [..._workspacePackages(root), 'tool'];
  final excludeDirs = [..._excludeDirsBase, if (!includeTests) 'test'];
  final excludeArg = '--exclude-dir=${excludeDirs.join(',')}';
  const excludeExtArg = '--exclude-ext=profraw,lock';

  // Per-package breakdown: run cloc --json on each target, Dart only.
  final results = <String, _PkgResult>{};
  var totalFiles = 0;
  var totalBlank = 0;
  var totalComment = 0;
  var totalCode = 0;

  for (final target in targets) {
    final dir = '$root/$target';
    if (!Directory(dir).existsSync()) continue;

    final proc = await Process.run('cloc', [
      dir,
      '--json',
      '--vcs=git',
      '--include-lang=Dart',
      excludeArg,
      excludeExtArg,
      '--not-match-f=$_generatedDartFilePattern',
    ]);

    if (proc.exitCode != 0) continue;

    try {
      final json = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      final dart = json['Dart'] as Map<String, dynamic>?;
      if (dart == null) continue;

      final r = _PkgResult(
        files: dart['nFiles'] as int,
        blank: dart['blank'] as int,
        comment: dart['comment'] as int,
        code: dart['code'] as int,
      );
      results[target.split('/').last] = r;
      totalFiles += r.files;
      totalBlank += r.blank;
      totalComment += r.comment;
      totalCode += r.code;
    } on FormatException {
      continue;
    }
  }

  // Print table.
  const nameW = 22;
  const numW = 10;

  stdout.writeln(
    '${'Package'.padRight(nameW)}'
    '${'Files'.padLeft(numW)}'
    '${'Blank'.padLeft(numW)}'
    '${'Comment'.padLeft(numW)}'
    '${'Code'.padLeft(numW)}',
  );
  stdout.writeln('-' * (nameW + numW * 4));

  // Sort by code descending.
  final sorted = results.entries.toList()
    ..sort((a, b) => b.value.code.compareTo(a.value.code));

  for (final entry in sorted) {
    final r = entry.value;
    stdout.writeln(
      '${entry.key.padRight(nameW)}'
      '${r.files.toString().padLeft(numW)}'
      '${r.blank.toString().padLeft(numW)}'
      '${r.comment.toString().padLeft(numW)}'
      '${r.code.toString().padLeft(numW)}',
    );
  }

  stdout.writeln('-' * (nameW + numW * 4));
  stdout.writeln(
    '${'TOTAL'.padRight(nameW)}'
    '${totalFiles.toString().padLeft(numW)}'
    '${totalBlank.toString().padLeft(numW)}'
    '${totalComment.toString().padLeft(numW)}'
    '${totalCode.toString().padLeft(numW)}',
  );
}

List<String> _workspacePackages(String root) {
  final packagesDir = Directory('$root/packages');
  if (!packagesDir.existsSync()) return const [];

  final packages =
      packagesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('/pubspec.yaml'))
          .map((file) => file.parent.path.substring(root.length + 1))
          .where(_isCountableWorkspacePackage)
          .toList()
        ..sort();

  return packages;
}

bool _isCountableWorkspacePackage(String path) {
  final segments = path.split(Platform.pathSeparator);
  if (segments.any(
    (segment) => segment == 'external' || segment == 'third_party',
  )) {
    return false;
  }

  return !_ffiPackageNames.contains(segments.last);
}

class _PkgResult {
  _PkgResult({
    required this.files,
    required this.blank,
    required this.comment,
    required this.code,
  });

  final int files;
  final int blank;
  final int comment;
  final int code;
}
