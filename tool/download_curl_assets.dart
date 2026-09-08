// To run:
// dart tool/download_curl_assets.dart
// dart tool/download_curl_assets.dart --os windows
//
// Downloads prebuilt curl-impersonate binaries from GitHub releases
// for all supported platforms, or just those named by --os.
// Tag defaults to the latest release (including prereleases) or --tag.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const _repoOwner = 'lexiforest';
const _repoName = 'curl-impersonate';
const _tmpDirName = 'tmp';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'tag',
      abbr: 't',
      help:
          'curl-impersonate release tag (e.g. v2.0.0a5). If omitted, uses '
          'the latest release (including prereleases).',
    )
    ..addMultiOption(
      'os',
      abbr: 'o',
      allowed: ['macos', 'linux', 'windows'],
      help:
          'Restrict downloads to these OS families. Defaults to all. The '
          'macOS and Linux archives carry symlinked libraries that a '
          'Windows host cannot extract, so pass `--os windows` there.',
    );

  final parsed = parser.parse(args);
  final tagArg = parsed['tag'];
  final tag = tagArg is String && tagArg.isNotEmpty
      ? tagArg
      : await _resolveReleaseTag();

  final repoRoot = _repoRoot();
  final tmpRoot = Directory(p.join(repoRoot.path, 'tool', _tmpDirName));

  final osFilter = (parsed['os'] as List<String>).toSet();
  final targets = osFilter.isEmpty
      ? PlatformTarget.allTargets
      : PlatformTarget.allTargets
            .where((target) => osFilter.contains(target.osFamily))
            .toList();

  for (final platform in targets) {
    final assetName = _assetName(tag, platform);
    final entryLibrary = _entryLibraryName(platform);
    final runDir = Directory(
      p.join(
        tmpRoot.path,
        'curl_assets_${platform.releaseLabel}_'
        '${DateTime.now().millisecondsSinceEpoch}',
      ),
    )..createSync(recursive: true);

    try {
      final downloadPath = p.join(runDir.path, assetName);
      final url = Uri.parse(
        'https://github.com/$_repoOwner/$_repoName/releases/download/'
        '$tag/$assetName',
      );
      stdout.writeln('Downloading $url');
      await _downloadFile(url, downloadPath);

      stdout.writeln('Extracting $assetName');
      await _runProcess('tar', ['-xzf', downloadPath, '-C', runDir.path]);

      final extractedRoot = _findExtractedRoot(runDir, entryLibrary);
      stdout.writeln('Copying libraries from ${extractedRoot.path}');

      final destDir = Directory(
        p.join(
          repoRoot.path,
          'packages',
          'ffi',
          'curl_impersonate_dart',
          'assets',
          'native',
          platform.assetFolder,
          platform.archFolder,
        ),
      );

      // Clean out old libraries before copying new ones.
      if (destDir.existsSync()) {
        for (final entity in destDir.listSync()) {
          final path = entity.path;
          if (FileSystemEntity.isLinkSync(path)) {
            Link(path).deleteSync();
          } else if (FileSystemEntity.isFileSync(path)) {
            File(path).deleteSync();
          }
        }
      }
      destDir.createSync(recursive: true);

      final libs = _findAllNativeLibraries(extractedRoot, platform);
      for (final sourceFile in libs) {
        final name = p.basename(sourceFile.path);
        final destPath = p.join(destDir.path, name);
        sourceFile.copySync(destPath);
      }

      final licenseFile = File(p.join(extractedRoot.path, 'LICENSE'));
      if (licenseFile.existsSync()) {
        licenseFile.copySync(p.join(destDir.path, 'LICENSE'));
      }

      stdout.writeln('Copied ${libs.length} libraries into ${destDir.path}\n');
    } finally {
      if (runDir.existsSync()) {
        runDir.deleteSync(recursive: true);
      }
    }
  }

  // Remove the scratch root if nothing else is using it.
  if (tmpRoot.existsSync() && tmpRoot.listSync().isEmpty) {
    tmpRoot.deleteSync();
  }
}

Directory _repoRoot() {
  final scriptDir = File.fromUri(Platform.script).parent;
  return scriptDir.parent;
}

Future<String> _resolveReleaseTag() async {
  // Prefer the tag the submodule is pinned at: ffigen binds against those
  // headers, so the prebuilt libraries must be the same version or the ABI can
  // drift. Keeps setup deterministic regardless of newer upstream releases.
  // An explicit --tag still overrides this.
  final pinned = _pinnedSubmoduleTag();
  if (pinned != null) return pinned;

  // No submodule checked out (a shallow tooling clone) — fall back to the
  // newest release the API lists.
  final fromApi = await _latestReleaseTagFromApi();
  if (fromApi != null) {
    stderr.writeln(
      'curl-impersonate submodule not checked out; using latest release '
      '$fromApi from the API.',
    );
    return fromApi;
  }

  stderr.writeln(
    'Could not resolve a curl-impersonate tag from the submodule or the '
    'releases API. Pass one explicitly with --tag.',
  );
  exit(1);
}

/// The newest release tag from GitHub, or null when the API lists none or the
/// request fails — the caller falls back to the pinned submodule tag.
Future<String?> _latestReleaseTagFromApi() async {
  // GitHub's /releases/latest excludes prereleases, so list all releases
  // (newest first) and take the first entry regardless of prerelease flag.
  final url = Uri.parse(
    'https://api.github.com/repos/$_repoOwner/$_repoName/releases?per_page=1',
  );
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'bestie-download-curl-assets',
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map && first['tag_name'] is String) {
        return first['tag_name'] as String;
      }
    }
    return null;
  } finally {
    client.close();
  }
}

/// The tag the curl-impersonate submodule is checked out at, or null when the
/// submodule is absent or its HEAD is not exactly on a tag.
String? _pinnedSubmoduleTag() {
  final submodule = p.join(
    _repoRoot().path,
    'packages',
    'ffi',
    'curl_impersonate_dart',
    'third_party',
    'curl-impersonate',
  );
  if (!Directory(submodule).existsSync()) return null;
  final result = Process.runSync('git', [
    '-C',
    submodule,
    'describe',
    '--tags',
    '--exact-match',
  ]);
  if (result.exitCode != 0) return null;
  final tag = (result.stdout as String).trim();
  return tag.isEmpty ? null : tag;
}

String _assetName(String tag, PlatformTarget platform) =>
    'libcurl-impersonate-$tag.${platform.releaseLabel}.tar.gz';

String _entryLibraryName(PlatformTarget platform) {
  switch (platform.osFamily) {
    case 'macos':
      return 'libcurl-impersonate.dylib';
    case 'linux':
      return 'libcurl-impersonate.so';
    case 'windows':
      return 'libcurl-impersonate.dll';
  }
  throw StateError('Unknown OS family: ${platform.osFamily}');
}

Future<void> _downloadFile(Uri url, String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url (status ${response.statusCode})',
      );
    }
    final file = File(path);
    final sink = file.openWrite();
    await response.pipe(sink);
  } finally {
    client.close();
  }
}

Directory _findExtractedRoot(Directory runDir, String entryLibrary) {
  // Check runDir itself first (flat archives).
  if (File(p.join(runDir.path, entryLibrary)).existsSync()) {
    return runDir;
  }

  // Search subdirectories.
  final candidates = runDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => p.basename(file.path) == entryLibrary)
      .toList();
  if (candidates.isEmpty) {
    stderr.writeln('Could not find $entryLibrary in extracted archive.');
    exit(1);
  }
  return candidates.first.parent;
}

List<File> _findAllNativeLibraries(Directory root, PlatformTarget platform) {
  bool isNativeLib(String name) {
    switch (platform.osFamily) {
      case 'macos':
        return name.endsWith('.dylib');
      case 'linux':
        return name.contains('.so');
      case 'windows':
        return name.endsWith('.dll');
    }
    return false;
  }

  return root
      .listSync()
      .whereType<File>()
      .where((f) => isNativeLib(p.basename(f.path)))
      .toList();
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    final stderrText = result.stderr is String ? result.stderr as String : '';
    throw ProcessException(
      executable,
      arguments,
      'Command failed with exit code ${result.exitCode}: $stderrText',
      result.exitCode,
    );
  }
  return result;
}

class PlatformTarget {
  const PlatformTarget._({
    required this.assetFolder,
    required this.archFolder,
    required this.releaseLabel,
    required this.osFamily,
  });

  static const allTargets = [
    PlatformTarget._(
      assetFolder: 'macos',
      archFolder: 'arm64',
      releaseLabel: 'arm64-macos',
      osFamily: 'macos',
    ),
    PlatformTarget._(
      assetFolder: 'macos',
      archFolder: 'x64',
      releaseLabel: 'x86_64-macos',
      osFamily: 'macos',
    ),
    PlatformTarget._(
      assetFolder: 'linux',
      archFolder: 'x64',
      releaseLabel: 'x86_64-linux-gnu',
      osFamily: 'linux',
    ),
    PlatformTarget._(
      assetFolder: 'linux',
      archFolder: 'arm64',
      releaseLabel: 'aarch64-linux-gnu',
      osFamily: 'linux',
    ),
    PlatformTarget._(
      assetFolder: 'windows',
      archFolder: 'x64',
      releaseLabel: 'x86_64-win32',
      osFamily: 'windows',
    ),
  ];

  final String assetFolder;
  final String archFolder;
  final String releaseLabel;
  final String osFamily;
}
