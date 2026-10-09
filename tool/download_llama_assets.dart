// To run:
// dart tool/download_llama_assets.dart
// dart tool/download_llama_assets.dart --os windows
// dart tool/download_llama_assets.dart --from-build ../llama.cpp/build
//
// Stages the llama.cpp libraries into
// packages/ffi/llama_cpp_dart/assets/native/<os>/<arch>/: downloaded from the
// pinned hobbyfarm-ai/llama.cpp release (see tool/src/llama_release.dart), or
// copied from a local CMake build of the fork with --from-build.
//
// Everything is staged under tool/tmp first and swapped into place only once
// every platform and variant succeeded, so a failed run leaves the libraries
// already there untouched. A release that is not published yet is a warning,
// not a failure: the llama.cpp FFI tests skip without the libraries.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/helpers.dart';
import 'src/llama_release.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'tag',
      abbr: 't',
      help:
          'Release tag to download. Defaults to the pin in $llamaReleaseFile.',
    )
    ..addMultiOption(
      'os',
      abbr: 'o',
      allowed: [for (final platform in llamaPlatforms) platform.os],
      help: 'Platforms to stage. Defaults to the host.',
    )
    ..addOption(
      'from-build',
      help:
          'Stage the host libraries from a local llama.cpp CMake build '
          'directory instead of downloading a release.',
    );
  final parsed = parser.parse(args);
  final root = repoRoot().path;
  final scratch = Directory(p.join(root, 'tool', 'tmp'));
  final run = Directory(
    p.join(scratch.path, 'llama_${DateTime.now().millisecondsSinceEpoch}'),
  )..createSync(recursive: true);

  final _Outcome outcome;
  try {
    outcome = switch (parsed['from-build'] as String?) {
      final String buildDir => await _stageFromBuild(root, run, buildDir),
      null => await _stageRelease(
        root,
        run,
        tag: (parsed['tag'] as String?) ?? pinnedLlamaTag(root),
        osFilter: (parsed['os'] as List<String>).toSet(),
      ),
    };
  } finally {
    run.deleteSync(recursive: true);
    if (scratch.listSync().isEmpty) scratch.deleteSync();
  }

  switch (outcome) {
    case _Staged(:final destinations):
      for (final destination in destinations) {
        stdout.writeln('Staged ${destination.path}');
      }
    case _ReleaseMissing(:final tag, :final url):
      _warn(
        'llama.cpp release $tag is not published yet ($url returned 404). '
        'Kept the existing llama.cpp libraries; the llama.cpp FFI tests skip '
        'without them.',
      );
    case _Failed(:final message):
      stderr.writeln('error: $message');
      exitCode = 1;
  }
}

/// Prints a warning, raised as an annotation when running on GitHub Actions.
void _warn(String message) {
  final annotation = Platform.environment['GITHUB_ACTIONS'] == 'true'
      ? '::warning title=llama.cpp::'
      : 'warning: ';
  stderr.writeln('$annotation$message');
}

sealed class _Outcome {
  const _Outcome();
}

final class _Staged extends _Outcome {
  const _Staged(this.destinations);

  final List<Directory> destinations;
}

final class _ReleaseMissing extends _Outcome {
  const _ReleaseMissing({required this.tag, required this.url});

  final String tag;
  final Uri url;
}

final class _Failed extends _Outcome {
  const _Failed(this.message);

  final String message;
}

/// A platform's libraries gathered under the run's scratch directory, ready
/// to replace its native directory.
final class _StagedPlatform {
  const _StagedPlatform(this.platform, this.directory);

  final LlamaPlatform platform;
  final Directory directory;
}

Future<_Outcome> _stageFromBuild(
  String root,
  Directory run,
  String buildDir,
) async {
  final platform = _hostPlatform();
  if (platform == null) {
    return _Failed('bestie ships no llama.cpp build for ${hostAssetSubdir()}.');
  }
  // Single-config generators write to bin/, multi-config ones (MSVC) to
  // bin/Release/.
  final binDir = [
    Directory(p.join(buildDir, 'bin', 'Release')),
    Directory(p.join(buildDir, 'bin')),
  ].where((candidate) => candidate.existsSync()).firstOrNull;
  if (binDir == null) return _Failed('No bin/ directory under $buildDir.');

  final staged = _StagedPlatform(platform, _stagingDir(run, platform));
  final count = _copyLibraries(binDir, platform, staged.directory);
  stdout.writeln('Gathered $count files from ${binDir.path}');
  await _stageMsvcRuntime(platform, staged.directory);
  return _Staged([_swapIn(root, staged)]);
}

Future<_Outcome> _stageRelease(
  String root,
  Directory run, {
  required String tag,
  required Set<String> osFilter,
}) async {
  final host = _hostPlatform();
  final platforms = osFilter.isEmpty
      ? [?host]
      : [
          for (final platform in llamaPlatforms)
            if (osFilter.contains(platform.os)) platform,
        ];
  if (platforms.isEmpty) {
    return _Failed('bestie ships no llama.cpp build for ${hostAssetSubdir()}.');
  }

  stdout.writeln('llama.cpp release $tag');
  final stagedPlatforms = <_StagedPlatform>[];
  for (final platform in platforms) {
    final staged = _StagedPlatform(platform, _stagingDir(run, platform));
    for (final variant in platform.variants) {
      final failure = await _stageVariant(run, tag, staged, variant);
      if (failure != null) return failure;
    }
    await _stageMsvcRuntime(platform, staged.directory);
    stagedPlatforms.add(staged);
  }
  return _Staged([for (final staged in stagedPlatforms) _swapIn(root, staged)]);
}

LlamaPlatform? _hostPlatform() {
  final host = hostAssetSubdir();
  return llamaPlatforms
      .where((platform) => platform.assetSubdir == host)
      .firstOrNull;
}

Directory _stagingDir(Directory run, LlamaPlatform platform) =>
    Directory(p.join(run.path, 'staged', platform.os, platform.arch))
      ..createSync(recursive: true);

/// Replaces the platform's native directory with the staged one, so
/// libraries from an earlier release never linger beside the new ones.
Directory _swapIn(String root, _StagedPlatform staged) {
  final destination = Directory(
    p.join(
      root,
      llamaPackageDir,
      'assets',
      'native',
      staged.platform.os,
      staged.platform.arch,
    ),
  );
  if (destination.existsSync()) destination.deleteSync(recursive: true);
  destination.parent.createSync(recursive: true);
  return staged.directory.renameSync(destination.path);
}

/// Downloads and extracts one release archive into the platform's staging
/// directory, or says why it could not.
Future<_Outcome?> _stageVariant(
  Directory run,
  String tag,
  _StagedPlatform staged,
  LlamaVariant variant,
) async {
  final workDir = Directory(
    p.join(run.path, 'work', '${staged.platform.os}_${variant.label}'),
  )..createSync(recursive: true);
  final assetName = variant.assetName(tag);
  final archive = File(p.join(workDir.path, assetName));
  final url = llamaAssetUrl(tag, assetName);
  stdout.writeln('  [${variant.label}] downloading $url');
  final failure =
      await _download(tag, url, archive) ??
      await _extract(archive, variant, workDir);
  if (failure != null) return failure;
  final count = _copyLibraries(workDir, staged.platform, staged.directory);
  stdout.writeln('  [${variant.label}] gathered $count files');
  return null;
}

/// Copies every library and licence under [source] into [destination],
/// keeping symlinks as symlinks so a versioned macOS or Linux set stays one
/// copy of each library. The first file staged under a name wins.
int _copyLibraries(
  Directory source,
  LlamaPlatform platform,
  Directory destination,
) {
  var staged = 0;
  final entries = source.listSync(recursive: true, followLinks: false);
  for (final entry in entries) {
    final name = p.basename(entry.path);
    if (!platform.isLibrary(name) && !platform.isLicense(name)) continue;
    final target = p.join(destination.path, name);
    if (FileSystemEntity.typeSync(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      continue;
    }
    switch (entry) {
      case Link():
        Link(target).createSync(entry.targetSync());
      case File():
        entry.copySync(target);
      default:
        continue;
    }
    staged++;
  }
  return staged;
}

Future<_Outcome?> _extract(
  File archive,
  LlamaVariant variant,
  Directory destination,
) async {
  if (variant.isZip) {
    // Written by hand rather than with extractFileToDisk, which carries over
    // the Windows archive's permission bits and leaves files unreadable on a
    // POSIX host. Entries are flattened, which also keeps them inside
    // [destination].
    final zip = ZipDecoder().decodeStream(InputFileStream(archive.path));
    for (final entry in zip.files.where((entry) => entry.isFile)) {
      File(
        p.join(destination.path, p.basename(entry.name)),
      ).writeAsBytesSync(entry.content as List<int>);
    }
    return null;
  }
  final code = await runCommand('tar', [
    '-xzf',
    archive.path,
    '-C',
    destination.path,
  ]);
  return code == 0
      ? null
      : _Failed('Could not extract ${archive.path} (tar exit $code).');
}

/// Copies the MSVC C++ runtime the Windows libraries import from the build
/// machine's Visual Studio install. Only a Windows host has one, so other
/// hosts skip it; release builds stage Windows on a Windows runner.
Future<void> _stageMsvcRuntime(
  LlamaPlatform platform,
  Directory destination,
) async {
  if (!platform.needsMsvcRuntime) return;
  if (!Platform.isWindows) {
    stdout.writeln(
      '  [crt] skipped: the MSVC runtime is copied from Visual Studio on a '
      'Windows host.',
    );
    return;
  }

  const vswhere =
      r'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe';
  final installation = await Process.run(vswhere, [
    '-latest',
    '-products',
    '*',
    '-property',
    'installationPath',
  ]);
  final visualStudio = (installation.stdout as String).trim();
  final redistVersion = File(
    p.join(
      visualStudio,
      'VC',
      'Auxiliary',
      'Build',
      'Microsoft.VCRedistVersion.default.txt',
    ),
  ).readAsStringSync().trim();
  // The runtime sits in a `Microsoft.VC<toolset>.CRT` folder named after the
  // toolset, so it is found by shape rather than by name.
  final runtimeDir =
      Directory(
        p.join(visualStudio, 'VC', 'Redist', 'MSVC', redistVersion, 'x64'),
      ).listSync().whereType<Directory>().firstWhere((directory) {
        final name = p.basename(directory.path);
        return name.startsWith('Microsoft.VC') && name.endsWith('.CRT');
      });

  for (final library in msvcRuntimeLibraries) {
    File(
      p.join(runtimeDir.path, library),
    ).copySync(p.join(destination.path, library));
  }
  stdout.writeln('  [crt] staged ${msvcRuntimeLibraries.join(', ')}');
}

Future<_Outcome?> _download(String tag, Uri url, File destination) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    switch (response.statusCode) {
      case HttpStatus.ok:
        await response.pipe(destination.openWrite());
        return null;
      case HttpStatus.notFound:
        await response.drain<void>();
        return _ReleaseMissing(tag: tag, url: url);
      case final status:
        await response.drain<void>();
        return _Failed('Failed to download $url (HTTP $status).');
    }
  } on IOException catch (error) {
    return _Failed('Failed to download $url: $error');
  } finally {
    client.close();
  }
}
