// Renames a workspace package: its directory, pubspec `name:` field,
// internal barrel/test files named after the package, and every
// whole-word reference to the old name across the repo. Re-sorts any
// pubspec dependency lists and Dart import/export directives the rename
// knocked out of alphabetical order.
//
// Usage:
//   dart tool/rename_package.dart <old_name> <new_name> [--execute]
//
// Defaults to a dry run that prints the plan without touching anything.
// Pass --execute to actually perform the renames via `git mv` and rewrite
// file contents in place.

import 'dart:io';

const _excludedDirNames = {
  '.git',
  '.dart_tool',
  'build',
  'coverage',
  'external',
  'node_modules',
  '.venv',
};

const _skippedFileNames = {'pubspec.lock'};

Future<void> main(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final execute = args.contains('--execute');

  if (positional.length != 2) {
    stderr.writeln(
      'Usage: dart tool/rename_package.dart <old_name> <new_name> [--execute]',
    );
    exitCode = 64;
    return;
  }

  final oldName = positional[0];
  final newName = positional[1];
  final wordBoundary = RegExp('\\b${RegExp.escape(oldName)}\\b');

  final repoRoot = Directory.current;
  final packageDir = await _findPackageDir(repoRoot, oldName);
  if (packageDir == null) {
    stderr.writeln('Could not find a package directory named "$oldName".');
    exitCode = 1;
    return;
  }

  print('${execute ? 'Executing' : 'Dry run'}: $oldName -> $newName');
  print('Package directory: ${_relative(repoRoot, packageDir)}');

  // Internal files whose stem is exactly the package name (barrel file)
  // or "<name>_test" (main test file) get renamed in place first.
  final internalRenames = await _findInternalRenames(
    packageDir,
    oldName,
    newName,
  );
  for (final rename in internalRenames) {
    print(
      '  rename file: ${_relative(repoRoot, rename.from)} -> '
      '${_relative(repoRoot, rename.to)}',
    );
    if (execute) {
      await _gitMv(rename.from, rename.to, cwd: repoRoot);
    }
  }

  // Whole-word content substitution across every text file in the repo,
  // including the package's own pubspec.yaml, README, etc.
  final changedFiles = await _substituteAcrossRepo(
    repoRoot: repoRoot,
    pattern: wordBoundary,
    replacement: newName,
    execute: execute,
  );
  for (final entry in changedFiles.entries) {
    print('  edit (${entry.value}x): ${_relative(repoRoot, entry.key)}');
  }

  // Renaming a dependency can knock its pubspec entry, or any import/export
  // referencing it, out of alphabetical order, which trips the
  // sort_pub_dependencies / directives_ordering lints. Re-sort every
  // pubspec.yaml and .dart file touched above.
  if (execute) {
    for (final file in changedFiles.keys) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      if (fileName == 'pubspec.yaml') {
        if (await _sortPubspecDependencies(file)) {
          print('  re-sorted: ${_relative(repoRoot, file)}');
        }
      } else if (fileName.endsWith('.dart')) {
        if (await _sortDartDirectives(file)) {
          print('  re-sorted imports: ${_relative(repoRoot, file)}');
        }
      }
    }
  }

  // Move the package directory itself last, after its contents have
  // already been renamed/rewritten.
  final newPackageDir = Directory(
    '${packageDir.parent.path}${Platform.pathSeparator}$newName',
  );
  print(
    '  rename dir: ${_relative(repoRoot, packageDir)} -> '
    '${_relative(repoRoot, newPackageDir)}',
  );
  if (execute) {
    await _gitMv(packageDir, newPackageDir, cwd: repoRoot);
  }

  print(
    '${execute ? 'Done.' : 'Dry run complete.'} '
    '${internalRenames.length} internal file rename(s), '
    '${changedFiles.length} file(s) with content edits, '
    '1 directory rename.',
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

class _Rename {
  _Rename(this.from, this.to);
  final File from;
  final File to;
}

Future<List<_Rename>> _findInternalRenames(
  Directory packageDir,
  String oldName,
  String newName,
) async {
  final renames = <_Rename>[];
  await for (final entity in packageDir.list(recursive: true)) {
    if (entity is! File) continue;
    if (_isExcluded(entity.path)) continue;

    final fileName = entity.path.split(Platform.pathSeparator).last;
    if (!fileName.endsWith('.dart')) continue;
    final stem = fileName.substring(0, fileName.length - '.dart'.length);

    String? newStem;
    if (stem == oldName) {
      newStem = newName;
    } else if (stem == '${oldName}_test') {
      newStem = '${newName}_test';
    }
    if (newStem == null) continue;

    final dir = entity.parent.path;
    renames.add(
      _Rename(entity, File('$dir${Platform.pathSeparator}$newStem.dart')),
    );
  }
  return renames;
}

Future<Map<File, int>> _substituteAcrossRepo({
  required Directory repoRoot,
  required RegExp pattern,
  required String replacement,
  required bool execute,
}) async {
  final changed = <File, int>{};
  await for (final entity in repoRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    if (_isExcluded(entity.path)) continue;
    if (_skippedFileNames.contains(
      entity.path.split(Platform.pathSeparator).last,
    )) {
      continue;
    }

    String content;
    try {
      content = await entity.readAsString();
    } on FormatException {
      continue; // binary file
    } on FileSystemException {
      continue; // unreadable/binary file
    }

    final matchCount = pattern.allMatches(content).length;
    if (matchCount == 0) continue;

    changed[entity] = matchCount;
    if (execute) {
      final updated = content.replaceAll(pattern, replacement);
      await entity.writeAsString(updated);
    }
  }
  return changed;
}

const _sortedPubspecSections = {'dependencies:', 'dev_dependencies:'};

/// Re-sorts the entries of `dependencies:`/`dev_dependencies:` blocks
/// alphabetically by key. Only handles the flat two-space-indent style
/// used throughout this workspace's package pubspecs; leaves everything
/// else (including `dependency_overrides:`, which carries comments)
/// untouched.
Future<bool> _sortPubspecDependencies(File file) async {
  final lines = await file.readAsLines();
  final result = <String>[...lines];
  var changed = false;

  for (var i = 0; i < result.length; i++) {
    if (!_sortedPubspecSections.contains(result[i].trim())) continue;
    if (result[i].startsWith(' ')) continue; // must be a top-level key

    // A blank line only ends the block if nothing indented follows it;
    // some pubspecs use blank lines to visually group entries within
    // the block, which must not be mistaken for the section's end.
    var end = i + 1;
    while (end < result.length) {
      if (result[end].isEmpty) {
        var lookahead = end + 1;
        while (lookahead < result.length && result[lookahead].isEmpty) {
          lookahead++;
        }
        if (lookahead < result.length && result[lookahead].startsWith(' ')) {
          end = lookahead;
          continue;
        }
        break;
      }
      if (!result[end].startsWith(' ')) break;
      end++;
    }

    final entries = <List<String>>[];
    for (var line = i + 1; line < end;) {
      if (result[line].isEmpty) {
        line++;
        continue;
      }
      final entryStart = line;
      line++;
      while (line < end && result[line].startsWith('    ')) {
        line++;
      }
      entries.add(result.sublist(entryStart, line));
    }

    final sorted = [...entries]
      ..sort((a, b) => a.first.trim().compareTo(b.first.trim()));
    if (!_sameOrder(entries, sorted)) {
      changed = true;
      result.replaceRange(i + 1, end, sorted.expand((e) => e));
    }
  }

  if (changed) {
    await file.writeAsString('${result.join('\n')}\n');
  }
  return changed;
}

bool _sameOrder(List<List<String>> a, List<List<String>> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i].first != b[i].first) return false;
  }
  return true;
}

final _directiveUriPattern = RegExp("^(?:import|export)\\s+'([^']*)'");

/// Re-sorts contiguous blocks of `import`/`export` directives into the
/// dart:/package:/relative groups the `directives_ordering` lint expects,
/// each sorted alphabetically by URI, with a single blank line between
/// non-empty groups. Comments attached above a directive are left where
/// they are, which splits the block there; this only matters for the rare
/// file that comments individual imports.
Future<bool> _sortDartDirectives(File file) async {
  final lines = await file.readAsLines();
  final result = <String>[...lines];
  var changed = false;

  var i = 0;
  while (i < result.length) {
    if (!_isDirectiveLine(result[i])) {
      i++;
      continue;
    }

    var end = i;
    while (end < result.length) {
      if (result[end].isEmpty) {
        var lookahead = end + 1;
        while (lookahead < result.length && result[lookahead].isEmpty) {
          lookahead++;
        }
        if (lookahead < result.length && _isDirectiveLine(result[lookahead])) {
          end = lookahead;
          continue;
        }
        break;
      }
      if (!_isDirectiveLine(result[end])) break;
      end++;
      while (end < result.length && result[end].startsWith('    ')) {
        end++;
      }
    }

    final block = result.sublist(i, end);
    final rewritten = _reorderDirectiveBlock(block);
    if (!_sameLines(block, rewritten)) {
      changed = true;
      result.replaceRange(i, end, rewritten);
      end = i + rewritten.length;
    }
    i = end;
  }

  if (changed) {
    await file.writeAsString('${result.join('\n')}\n');
  }
  return changed;
}

bool _isDirectiveLine(String line) =>
    line.startsWith('import ') || line.startsWith('export ');

List<String> _reorderDirectiveBlock(List<String> block) {
  final imports = <List<String>>[];
  final exports = <List<String>>[];

  var line = 0;
  while (line < block.length) {
    if (block[line].isEmpty) {
      line++;
      continue;
    }
    final entryStart = line;
    line++;
    while (line < block.length && block[line].startsWith('    ')) {
      line++;
    }
    final entry = block.sublist(entryStart, line);
    (entry.first.startsWith('export ') ? exports : imports).add(entry);
  }

  final result = <String>[..._sortDirectiveEntries(imports)];
  final sortedExports = _sortDirectiveEntries(exports);
  if (result.isNotEmpty && sortedExports.isNotEmpty) result.add('');
  result.addAll(sortedExports);
  return result;
}

List<String> _sortDirectiveEntries(List<List<String>> entries) {
  int rank(List<String> entry) {
    final uri = _directiveUriPattern.firstMatch(entry.first)?.group(1) ?? '';
    if (uri.startsWith('dart:')) return 0;
    if (uri.startsWith('package:')) return 1;
    return 2;
  }

  String sortKey(List<String> entry) =>
      _directiveUriPattern.firstMatch(entry.first)?.group(1) ?? entry.first;

  final buckets = <int, List<List<String>>>{0: [], 1: [], 2: []};
  for (final entry in entries) {
    buckets[rank(entry)]!.add(entry);
  }
  for (final bucket in buckets.values) {
    bucket.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
  }

  final result = <String>[];
  for (final key in [0, 1, 2]) {
    final bucket = buckets[key]!;
    if (bucket.isEmpty) continue;
    if (result.isNotEmpty) result.add('');
    result.addAll(bucket.expand((entry) => entry));
  }
  return result;
}

bool _sameLines(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
