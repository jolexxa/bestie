// To run:
// dart tool/update_curl.dart [tag]
//
// Updates the curl-impersonate submodule to a new release and downloads
// prebuilt native libraries.
//
// If [tag] is given (e.g. v1.5.5), checks out that tag. Otherwise fetches
// and checks out the latest v-prefixed semver release tag.

import 'dart:io';

import 'src/helpers.dart';

Future<void> main(List<String> args) async {
  final root = repoRoot().path;
  final curlDir =
      '$root/packages/ffi/curl_impersonate_dart/third_party/curl-impersonate';

  // ── 1. Fetch latest from upstream ──────────────────────────────

  stdout.writeln('Fetching curl-impersonate upstream...');
  var code = await runCommand('git', [
    'fetch',
    '--tags',
    'origin',
  ], workingDirectory: curlDir);
  if (code != 0) {
    stderr.writeln('Failed to fetch. Is the submodule initialized?');
    stderr.writeln(
      'Try: git submodule update --init '
      'packages/ffi/curl_impersonate_dart/third_party/curl-impersonate',
    );
    exitCode = code;
    return;
  }

  // ── 2. Determine target tag ────────────────────────────────────

  final oldRef = await _gitDescribe(curlDir);

  final String tag;
  if (args.isNotEmpty) {
    tag = args.first;
  } else {
    tag = await _latestSemverTag(curlDir);
    if (tag.isEmpty) {
      stderr.writeln(
        'No v-prefixed semver tags found in curl-impersonate repo.',
      );
      exitCode = 1;
      return;
    }
  }

  stdout.writeln('Checking out: $tag');
  code = await runCommand('git', ['checkout', tag], workingDirectory: curlDir);
  if (code != 0) {
    stderr.writeln('Failed to checkout tag: $tag');
    exitCode = code;
    return;
  }

  final newRef = await _gitDescribe(curlDir);

  // ── 2b. Regenerate FFI bindings ────────────────────────────────

  stdout.writeln('\nRegenerating FFI bindings...');
  code = await runCommand('dart', [
    'run',
    'ffigen',
    '--config',
    'tool/ffigen.yaml',
  ], workingDirectory: '$root/packages/ffi/curl_impersonate_dart');
  if (code != 0) {
    stderr.writeln('ffigen failed.');
    exitCode = code;
    return;
  }

  // ── 3. Download prebuilt native libraries ──────────────────────

  stdout.writeln('\nDownloading prebuilt native libraries...');
  code = await runCommand('dart', [
    'tool/download_curl_assets.dart',
    '--tag',
    tag,
  ], workingDirectory: root);
  if (code != 0) {
    stderr.writeln('Native library download failed.');
    exitCode = code;
    return;
  }

  // ── 4. Summary ─────────────────────────────────────────────────

  stdout.writeln('\n${'=' * 50}');
  stdout.writeln('curl-impersonate updated successfully!');
  stdout.writeln('  $oldRef -> $newRef');
  stdout.writeln('  Native libraries downloaded');
  stdout.writeln('${'=' * 50}');
}

Future<String> _gitDescribe(String dir) async {
  final result = await Process.run('git', [
    'describe',
    '--tags',
    '--always',
  ], workingDirectory: dir);
  return (result.stdout as String).trim();
}

/// Finds the latest v-prefixed semver tag (e.g. v1.5.5).
Future<String> _latestSemverTag(String dir) async {
  final result = await Process.run('git', [
    'tag',
    '-l',
    'v*',
  ], workingDirectory: dir);
  final tags = (result.stdout as String)
      .split('\n')
      .where(
        (t) =>
            t.trim().isNotEmpty &&
            RegExp(r'^v\d+\.\d+\.\d+').hasMatch(t.trim()),
      )
      .map((t) => t.trim())
      .toList();

  if (tags.isEmpty) return '';

  tags.sort((a, b) {
    final partsA = a.substring(1).split('.').map(int.parse).toList();
    final partsB = b.substring(1).split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final cmp = partsA[i].compareTo(partsB[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  });

  return tags.last;
}
