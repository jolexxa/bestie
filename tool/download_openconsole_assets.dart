// Installs the Windows console host bestie ships: Microsoft's redistributable
// `conpty.dll` and the `OpenConsole.exe` it launches, taken from the ConPTY
// NuGet package attached to a pinned Windows Terminal release.
//
// The pin — release, package version, checksum — lives in
// tool/src/console_host.dart. The licence notice is regenerated from the same
// pin, so bumping one bumps the other.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'src/console_host.dart';
import 'src/helpers.dart';

Future<void> main() async {
  final root = repoRoot().path;

  stdout.writeln('Downloading $consoleHostArchiveUrl');
  final archiveBytes = await _download(consoleHostArchiveUrl);

  final digest = sha256.convert(archiveBytes).toString();
  if (digest != consoleHostSha256) {
    stderr.writeln(
      'Checksum mismatch for $consoleHostAsset.\n'
      '  expected $consoleHostSha256\n'
      '  actual   $digest\n'
      'Either the pin in tool/src/console_host.dart is stale or the download '
      'was tampered with; nothing was installed.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('Verified sha256 $digest');

  final archive = ZipDecoder().decodeBytes(archiveBytes);
  final destination = Directory(
    p.join(root, consoleHostAssetDir, consoleHostArchitecture),
  )..createSync(recursive: true);

  for (final file in consoleHostFiles) {
    final entryPath = file.archivePath.replaceAll(
      '<arch>',
      consoleHostArchitecture,
    );
    final entry = archive.findFile(entryPath);
    if (entry == null) {
      stderr.writeln(
        'The package does not carry $entryPath. The pinned package version '
        'may have changed its layout.',
      );
      exitCode = 1;
      return;
    }
    final installed = File(p.join(destination.path, file.name))
      ..writeAsBytesSync(entry.content as List<int>);
    stdout.writeln('  ${p.relative(installed.path, from: root)}');
  }

  await _writeNotice(root);
}

/// Writes the verbatim licence text for the shipped binaries, taken from the
/// terminal repo at the pinned release rather than from a working checkout, so
/// the notice describes exactly what was installed.
Future<void> _writeNotice(String root) async {
  final license = utf8.decode(await _download(consoleHostSourceUrl('LICENSE')));
  final notice = utf8.decode(
    await _download(consoleHostSourceUrl('NOTICE.md')),
  );

  final out = File(p.join(root, consoleHostNoticeFile))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('''
Release:   microsoft/terminal $consoleHostRelease
Package:   $consoleHostAsset
Generated: dart tool/download_openconsole_assets.dart

${license.trimRight()}

--- NOTICE ---

${notice.trimRight()}
''');

  stdout.writeln(
    '  ${p.relative(out.path, from: root)} (${out.lengthSync()} bytes)',
  );
}

Future<List<int>> _download(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('Failed to download $url (status ${response.statusCode})');
      exit(1);
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  } finally {
    client.close();
  }
}
