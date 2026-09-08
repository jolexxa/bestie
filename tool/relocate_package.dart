// Moves a workspace package to a new parent directory without renaming it:
// the package keeps its `name:` field and import identity, only its
// location on disk changes. Every `path:` dependency entry across the repo
// that points at the package — including the package's own dependencies,
// which are now relative to a new base — is rewritten to match, along with
// any melos `categories:` list entries that reference it by path.
//
// Usage:
//   dart tool/relocate_package.dart <package_name> <new_parent_dir> [--execute]
//
// <new_parent_dir> is relative to the repo root, e.g. `packages/features/models`.
// The package ends up at <new_parent_dir>/<package_name>.
//
// Defaults to a dry run that prints the plan without touching anything.
// Pass --execute to actually perform the move via `git mv` and rewrite file
// contents in place.

import 'dart:io';

import 'package:path/path.dart' as p;

const _excludedDirNames = {
  '.git',
  '.dart_tool',
  'build',
  'coverage',
  'external',
  'node_modules',
  '.venv',
};

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final execute = args.contains('--execute');

  if (positional.length != 2) {
    stderr.writeln(
      'Usage: dart tool/relocate_package.dart <package_name> '
      '<new_parent_dir> [--execute]',
    );
    exitCode = 64;
    return;
  }

  final packageName = positional[0];
  final newParentDir = positional[1];

  final repoRoot = Directory.current;
  final packageDir = await _findPackageDir(repoRoot, packageName);
  if (packageDir == null) {
    stderr.writeln('Could not find a package directory named "$packageName".');
    exitCode = 1;
    return;
  }

  final oldAbs = p.normalize(packageDir.absolute.path);
  final newAbs = p.normalize(
    p.join(repoRoot.absolute.path, newParentDir, packageName),
  );

  if (oldAbs == newAbs) {
    stderr.writeln('"$packageName" is already under "$newParentDir".');
    exitCode = 1;
    return;
  }
  if (Directory(newAbs).existsSync() || File(newAbs).existsSync()) {
    stderr.writeln(
      'Target path already exists: ${p.relative(newAbs, from: repoRoot.absolute.path)}',
    );
    exitCode = 1;
    return;
  }

  print(
    '${execute ? 'Executing' : 'Dry run'}: $packageName -> $newParentDir/$packageName',
  );
  print('From: ${_relative(repoRoot, packageDir)}');
  print('To:   ${p.relative(newAbs, from: repoRoot.absolute.path)}');
  print('');

  final edits = await _rewritePubspecPaths(
    repoRoot: repoRoot,
    oldAbs: oldAbs,
    newAbs: newAbs,
    execute: execute,
  );
  for (final entry in edits.entries) {
    print('  edit (${entry.value}x): ${_relative(repoRoot, entry.key)}');
  }

  print(
    '  relocate dir: ${_relative(repoRoot, packageDir)} -> '
    '${p.relative(newAbs, from: repoRoot.absolute.path)}',
  );
  if (execute) {
    await Directory(p.dirname(newAbs)).create(recursive: true);
    await _gitMv(packageDir, Directory(newAbs), cwd: repoRoot);
  }

  print(
    '${execute ? 'Done.' : 'Dry run complete.'} '
    '${edits.length} pubspec.yaml file(s) with path edits, '
    '1 directory move.',
  );
}

Future<Directory?> _findPackageDir(Directory repoRoot, String name) async {
  final packagesDir = Directory('${repoRoot.path}/packages');
  if (!packagesDir.existsSync()) return null;

  final matches = <Directory>[];
  await for (final entity in packagesDir.list(recursive: true)) {
    if (entity is! Directory) continue;
    if (entity.path.split(Platform.pathSeparator).last != name) continue;
    if (_isExcluded(entity.path)) continue;
    matches.add(entity);
  }

  if (matches.length > 1) {
    stderr.writeln('Multiple directories named "$name" found:');
    for (final m in matches) {
      stderr.writeln('  ${m.path}');
    }
    exitCode = 1;
    return null;
  }

  return matches.isEmpty ? null : matches.single;
}

/// Local-path dependency fields look like:
///
/// ```yaml
///   some_pkg:
///     path: ../../domain/some_pkg
/// ```
///
/// Nested two spaces deeper than the package key that owns them. This
/// distinguishes a real `path:` field from the hosted `path` package
/// itself (`  path: ^1.9.1`), which is a top-level dependency key, not a
/// nested field.
final _pathFieldPattern = RegExp(r'^(\s{4,})path:\s*(\S.*)$');

/// A melos `categories:` list entry, e.g. `      - packages/data/foo`.
/// Glob entries (containing `*`) are left untouched — they don't need
/// rewriting and rewriting one blindly could change what it matches.
final _categoryListItemPattern = RegExp(r'^(\s*)-\s+(packages/\S+)\s*$');

Future<Map<File, int>> _rewritePubspecPaths({
  required Directory repoRoot,
  required String oldAbs,
  required String newAbs,
  required bool execute,
}) async {
  final changed = <File, int>{};
  await for (final entity in repoRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    if (_isExcluded(entity.path)) continue;
    if (p.basename(entity.path) != 'pubspec.yaml') continue;

    final lines = await entity.readAsLines();
    final fileDir = p.dirname(entity.absolute.path);
    final isMovingFile = p.normalize(fileDir) == oldAbs;
    var editCount = 0;

    final rewritten = lines.map((line) {
      final fieldMatch = _pathFieldPattern.firstMatch(line);
      if (fieldMatch != null) {
        final newValue = _rewrittenPathValue(
          rawValue: fieldMatch.group(2)!,
          fileDir: fileDir,
          isMovingFile: isMovingFile,
          oldAbs: oldAbs,
          newAbs: newAbs,
        );
        if (newValue != null) {
          editCount++;
          return '${fieldMatch.group(1)}path: $newValue';
        }
        return line;
      }

      final itemMatch = _categoryListItemPattern.firstMatch(line);
      if (itemMatch != null && !itemMatch.group(2)!.contains('*')) {
        final target = p.normalize(
          p.join(repoRoot.absolute.path, itemMatch.group(2)!),
        );
        if (target == oldAbs) {
          editCount++;
          final newRelative = p.relative(newAbs, from: repoRoot.absolute.path);
          return '${itemMatch.group(1)}- $newRelative';
        }
      }

      return line;
    }).toList();

    if (editCount == 0) continue;
    changed[entity] = editCount;
    if (execute) {
      await entity.writeAsString('${rewritten.join('\n')}\n');
    }
  }
  return changed;
}

/// Returns the new value for a `path:` field, or null if it doesn't need
/// to change. Handles an optional trailing inline comment (` # ...`).
String? _rewrittenPathValue({
  required String rawValue,
  required String fileDir,
  required bool isMovingFile,
  required String oldAbs,
  required String newAbs,
}) {
  final commentIndex = rawValue.indexOf(' #');
  final value =
      (commentIndex == -1 ? rawValue : rawValue.substring(0, commentIndex))
          .trim();
  final comment = commentIndex == -1 ? '' : rawValue.substring(commentIndex);

  final targetAbs = p.normalize(p.join(fileDir, value));
  final resolvedTarget = targetAbs == oldAbs ? newAbs : targetAbs;
  final resolvedFrom = isMovingFile ? newAbs : fileDir;

  final newValue = p.relative(resolvedTarget, from: resolvedFrom);
  return newValue == value ? null : '$newValue$comment';
}

bool _isExcluded(String path) {
  final segments = path.split(Platform.pathSeparator);
  return segments.any(_excludedDirNames.contains);
}

Future<void> _gitMv(
  FileSystemEntity from,
  FileSystemEntity to, {
  required Directory cwd,
}) async {
  final result = await Process.run('git', [
    'mv',
    from.path,
    to.path,
  ], workingDirectory: cwd.path);
  if (result.exitCode != 0) {
    stderr.writeln('git mv failed: ${result.stderr}');
    exitCode = 1;
  }
}

String _relative(Directory root, FileSystemEntity entity) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  return entity.path.startsWith(rootPath)
      ? entity.path.substring(rootPath.length)
      : entity.path;
}
