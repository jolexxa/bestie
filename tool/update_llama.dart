// To run:
// dart tool/update_llama.dart <tag>
//
// Moves bestie to another hobbyfarm-ai/llama.cpp release: refreshes the
// header snapshot from the fork at <tag>, regenerates the FFI bindings
// against it, downloads the matching prebuilt libraries for this host, and
// only then pins <tag>, so a failed step leaves the old pin in place.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/helpers.dart';
import 'src/llama_release.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tool/update_llama.dart <release-tag>');
    exitCode = 64;
    return;
  }
  final tag = args.single;
  final root = repoRoot().path;
  final previous = pinnedLlamaTag(root);

  stdout.writeln('Refreshing headers from $llamaRepository@$tag');
  final headers = <String, String>{};
  for (final header in llamaHeaders) {
    final url = llamaSourceUrl(tag, header);
    final contents = await _download(url);
    if (contents == null) {
      stderr.writeln('Could not fetch $url; nothing was changed.');
      exitCode = 1;
      return;
    }
    headers[p.basename(header)] = contents;
  }
  for (final MapEntry(key: name, value: contents) in headers.entries) {
    File(p.join(root, llamaHeaderDir, name)).writeAsStringSync(contents);
    stdout.writeln('  $name');
  }

  stdout.writeln('\nRegenerating FFI bindings...');
  var code = await runCommand('dart', [
    'run',
    'ffigen',
    '--config',
    'tool/ffigen.yaml',
  ], workingDirectory: p.join(root, llamaPackageDir));
  if (code != 0) {
    stderr.writeln('ffigen failed.');
    exitCode = code;
    return;
  }

  stdout.writeln('\nDownloading prebuilt libraries...');
  code = await runCommand('dart', [
    'tool/download_llama_assets.dart',
    '--tag',
    tag,
  ], workingDirectory: root);
  if (code != 0) {
    stderr.writeln('Library download failed.');
    exitCode = code;
    return;
  }

  File(p.join(root, llamaReleaseFile)).writeAsStringSync('$tag\n');
  stdout.writeln('\nllama.cpp updated: $previous -> $tag');
}

Future<String?> _download(Uri url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) return null;
    return utf8.decoder.bind(response).join();
  } finally {
    client.close();
  }
}
