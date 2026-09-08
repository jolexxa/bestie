@TestOn('mac-os')
library;

import 'dart:io';

import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String? _findLibrary() {
  final candidates = [
    p.join(
      Directory.current.path,
      'assets',
      'native',
      'macos',
      'arm64',
      'libcurl-impersonate.dylib',
    ),
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

String? _findCaCert() {
  final candidate = p.join(
    Directory.current.path,
    'assets',
    'certs',
    'cacert.pem',
  );
  return File(candidate).existsSync() ? candidate : null;
}

void main() {
  final libPath = _findLibrary();
  final caCertPath = _findCaCert();

  test(
    'fetches a page with browser impersonation and the bundled CA',
    () async {
      if (libPath == null) {
        markTestSkipped('curl-impersonate dylib not found');
        return;
      }
      if (caCertPath == null) {
        markTestSkipped('cacert.pem not found — run download_cert_assets.dart');
        return;
      }

      CurlImpersonate.globalInit(libPath);
      addTearDown(() => CurlImpersonate.globalCleanup(libPath));

      final response = await CurlImpersonate.fetch(
        libPath,
        CurlRequest(
          url: 'https://httpbin.org/get',
          impersonate: 'chrome136',
          caCertPath: caCertPath,
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, contains('"url"'));
      expect(response.headers, isNotEmpty);
      expect(response.headers['content-type'], contains('application/json'));
    },
  );
}
