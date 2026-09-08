// To run:
// dart tool/download_cert_assets.dart
//
// Downloads the Mozilla CA certificate bundle (cacert.pem) that
// curl-impersonate verifies TLS peers against. The prebuilt
// curl-impersonate libraries bake in Debian/Alpine CA paths that do not
// exist on other distros (or on macOS), so Bestie ships its own copy of the
// bundle and points CURLOPT_CAINFO at it for identical behavior everywhere.
//
// The bundle is Mozilla's root store, extracted and published by the curl
// project. Its SHA-256 is verified against the companion .sha256 file.
//
// The license texts covering this data (MPL-2.0 and CDLA-2.0 Permissive)
// are vendored under assets/third_party_licenses/ — they are frozen legal
// texts and are committed to the repository, not downloaded here.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _bundleUrl = 'https://curl.se/ca/cacert.pem';
const _checksumUrl = 'https://curl.se/ca/cacert.pem.sha256';

Future<void> main() async {
  final repoRoot = _repoRoot();
  final destDir = Directory(
    p.join(repoRoot.path, 'packages', 'ffi', 'curl_impersonate_dart', 'assets'),
  )..createSync(recursive: true);
  final destPath = p.join(destDir.path, 'cacert.pem');

  stdout.writeln('Downloading $_bundleUrl');
  final bundleBytes = await _downloadBytes(Uri.parse(_bundleUrl));

  stdout.writeln('Downloading $_checksumUrl');
  final checksumBody = utf8.decode(
    await _downloadBytes(Uri.parse(_checksumUrl)),
  );
  final expected = _parseChecksum(checksumBody);
  final actual = sha256.convert(bundleBytes).toString();
  if (actual != expected) {
    stderr.writeln(
      'Checksum mismatch for cacert.pem.\n'
      '  expected: $expected\n'
      '  actual:   $actual',
    );
    exit(1);
  }

  File(destPath).writeAsBytesSync(bundleBytes);
  stdout.writeln('Verified and wrote ${bundleBytes.length} bytes to $destPath');
}

Directory _repoRoot() {
  final scriptDir = File.fromUri(Platform.script).parent;
  return scriptDir.parent;
}

/// Parses the first whitespace-delimited token as the expected SHA-256.
///
/// The curl.se checksum file is in `sha256sum` format: `<hash>  cacert.pem`.
String _parseChecksum(String body) {
  final token = body.trim().split(RegExp(r'\s+')).first;
  if (token.length != 64) {
    stderr.writeln('Unexpected checksum format: "$body"');
    exit(1);
  }
  return token.toLowerCase();
}

Future<List<int>> _downloadBytes(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'bestie-download-cert-assets',
    );
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
