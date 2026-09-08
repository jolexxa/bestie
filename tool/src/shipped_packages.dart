// Shared resolution of the third-party Dart packages that ship inside a Bestie
// release — the runtime-closure dependencies of `packages/bestie`, resolved to
// their pub-cache directories. Used by both `credits.dart` (the human-facing
// summary) and `build_licenses.dart` (the verbatim license bundle) so the two
// can never disagree about which packages are shipped.

import 'dart:convert';
import 'dart:io';

/// A third-party Dart package that ships in the Bestie release archive.
class ShippedPackage {
  ShippedPackage({
    required this.name,
    required this.version,
    required this.source,
    required this.baseDir,
  });

  final String name;
  final String version;

  /// `hosted` or `git`.
  final String source;

  /// Absolute path to the package's directory in the pub cache.
  final String baseDir;

  File? get licenseFile => findLicenseFile(baseDir);
  File? get noticeFile => findNoticeFile(baseDir);
}

/// Resolves the runtime-closure third-party Dart packages of the bestie binary.
///
/// Walks `dart pub deps --json` starting from the [rootPackageName] package
/// (the shipped binary — **not** the pub-workspace root, whose direct deps are
/// just the workspace tools), following each package's `directDependencies` so
/// dev/build-only branches are excluded, and resolving each third-party
/// (non-path/root) package to its pub-cache directory. Names whose cache
/// directory cannot be located are appended to [missing].
///
/// [appPackagePath] is where `dart pub deps` runs; in a workspace this yields
/// the whole graph regardless, and the walk is anchored at [rootPackageName].
Future<List<ShippedPackage>> resolveShippedDartPackages({
  required String repoRoot,
  required String appPackagePath,
  required List<String> missing,
  String rootPackageName = 'bestie',
}) async {
  final result = await Process.run('dart', [
    'pub',
    'deps',
    '--json',
  ], workingDirectory: appPackagePath);
  if (result.exitCode != 0) {
    throw StateError('dart pub deps failed: ${result.stderr}');
  }

  final graph = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final packages = (graph['packages'] as List).cast<Map<String, dynamic>>();
  final byName = {for (final p in packages) p['name'] as String: p};

  final rootPkg = byName[rootPackageName];
  if (rootPkg == null) {
    throw StateError(
      'Root package "$rootPackageName" not found in `dart pub deps` output.',
    );
  }

  // Walk the runtime closure, following non-dev direct dependencies at every
  // level. `directDependencies` excludes each package's dev_dependencies, so
  // builders and test-only tooling do not enter the shipped set.
  List<String> directDeps(Map<String, dynamic> pkg) =>
      (pkg['directDependencies'] as List? ?? const []).cast<String>();

  final visited = <String>{};
  final queue = <String>[...directDeps(rootPkg)];
  while (queue.isNotEmpty) {
    final name = queue.removeLast();
    if (!visited.add(name)) continue;
    final pkg = byName[name];
    if (pkg == null) continue;
    for (final child in directDeps(pkg)) {
      if (!visited.contains(child)) queue.add(child);
    }
  }

  final gitLocations = parseGitPackageLocations('$repoRoot/pubspec.lock');
  final pubCache = pubCacheDir();

  final shipped = <ShippedPackage>[];
  for (final name in visited) {
    final pkg = byName[name];
    if (pkg == null) continue;
    final source = pkg['source'] as String?;
    if (source == 'path' || source == 'root') continue; // first-party.

    final version = pkg['version'] as String;
    String? base;
    if (source == 'hosted') {
      base = '$pubCache/hosted/pub.dev/$name-$version';
    } else if (source == 'git') {
      base = gitLocations[name]?.cacheDirWithin(pubCache);
    }

    if (base == null) {
      missing.add('$name ($source)');
      continue;
    }

    shipped.add(
      ShippedPackage(
        name: name,
        version: version,
        source: source!,
        baseDir: base,
      ),
    );
  }

  shipped.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return shipped;
}

/// Where a git-sourced package lives inside the pub cache: pub names the
/// checkout after the repository, not the package, and a `path:` dependency
/// sits in a subdirectory of that checkout.
class GitPackageLocation {
  const GitPackageLocation({
    required this.repositoryName,
    required this.resolvedRef,
    required this.path,
  });

  final String repositoryName;
  final String resolvedRef;
  final String path;

  String cacheDirWithin(String pubCache) {
    final checkout = '$pubCache/git/$repositoryName-$resolvedRef';
    return path == '.' ? checkout : '$checkout/$path';
  }
}

/// Reads every git-sourced package's `description` block out of a lockfile.
Map<String, GitPackageLocation> parseGitPackageLocations(String lockfilePath) {
  // Tiny indentation-aware scanner — avoids pulling in a YAML dep just
  // for `description` lookups.
  final locations = <String, GitPackageLocation>{};
  String? currentPackage;
  var inDescription = false;
  final fields = <String, String>{};

  void finishPackage() {
    final url = fields['url'];
    final ref = fields['resolved-ref'];
    if (currentPackage != null && url != null && ref != null) {
      locations[currentPackage] = GitPackageLocation(
        repositoryName: _repositoryNameOf(url),
        resolvedRef: ref,
        path: fields['path'] ?? '.',
      );
    }
    fields.clear();
  }

  for (final line in File(lockfilePath).readAsLinesSync()) {
    if (RegExp(r'^  [a-zA-Z_]').hasMatch(line)) {
      finishPackage();
      currentPackage = line.trim().replaceAll(':', '');
      inDescription = false;
    } else if (line.startsWith('    description:')) {
      inDescription = true;
    } else if (inDescription && line.startsWith('      ')) {
      final separator = line.indexOf(':');
      final key = line.substring(0, separator).trim();
      fields[key] = line.substring(separator + 1).trim().replaceAll('"', '');
    } else if (line.startsWith('    ')) {
      inDescription = false;
    }
  }
  finishPackage();
  return locations;
}

String _repositoryNameOf(String url) {
  final lastSegment = url.split('/').last;
  return lastSegment.endsWith('.git')
      ? lastSegment.substring(0, lastSegment.length - 4)
      : lastSegment;
}

String pubCacheDir() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) return env;
  if (Platform.isWindows) {
    for (final variable in const ['LOCALAPPDATA', 'APPDATA']) {
      final base = Platform.environment[variable];
      if (base == null) continue;
      final candidate = '$base/Pub/Cache';
      if (Directory(candidate).existsSync()) return candidate;
    }
  }
  final home = Platform.environment['HOME'];
  return '$home/.pub-cache';
}

File? findLicenseFile(String dir) {
  for (final name in const [
    'LICENSE',
    'LICENSE.txt',
    'LICENSE.md',
    'COPYING',
    'COPYING.txt',
    'license',
    'license.txt',
  ]) {
    final f = File('$dir/$name');
    if (f.existsSync()) return f;
  }
  return null;
}

File? findNoticeFile(String dir) {
  for (final name in const ['NOTICE', 'NOTICE.txt', 'NOTICE.md']) {
    final f = File('$dir/$name');
    if (f.existsSync()) return f;
  }
  return null;
}
