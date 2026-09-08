import 'dart:convert';
import 'dart:typed_data';

import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('CurlImpersonateClient', () {
    late List<CurlRequest> captured;
    late CurlResponse stubbed;

    CurlImpersonateClient buildClient() => CurlImpersonateClient(
      libraryPath: '/lib/libcurl.dylib',
      caCertPath: '/certs/cacert.pem',
      fetch: (libraryPath, request) async {
        captured.add(request);
        return stubbed;
      },
    );

    setUp(() {
      captured = [];
      stubbed = CurlResponse(
        statusCode: 200,
        bodyBytes: Uint8List.fromList(utf8.encode('hello')),
        headers: const {'content-type': 'text/plain'},
      );
    });

    test('translates a GET request onto a CurlRequest', () async {
      final client = buildClient();

      await client.send(http.Request('GET', Uri.parse('https://x.test/a?q=1')));

      final req = captured.single;
      expect(req.url, 'https://x.test/a?q=1');
      expect(req.body, isNull);
      expect(req.caCertPath, '/certs/cacert.pem');
      expect(req.impersonate, 'chrome146');
    });

    test('strips fingerprint headers but forwards the rest', () async {
      final client = buildClient();

      await client.send(
        http.Request('GET', Uri.parse('https://x.test'))
          ..headers.addAll({
            'User-Agent': 'spoofed',
            'Accept': 'text/html',
            'Accept-Language': 'en',
            'Accept-Encoding': 'gzip',
            'Sec-Fetch-Mode': 'navigate',
            'Referer': 'https://ref.test',
          }),
      );

      final headers = captured.single.headers;
      expect(headers, isNotNull);
      expect(headers!.keys.map((k) => k.toLowerCase()), ['referer']);
      expect(headers['Referer'], 'https://ref.test');
    });

    test('leaves headers null when only fingerprint headers sent', () async {
      final client = buildClient();

      await client.send(
        http.Request('GET', Uri.parse('https://x.test'))
          ..headers['User-Agent'] = 'spoofed',
      );

      expect(captured.single.headers, isNull);
    });

    test('forwards a POST body', () async {
      final client = buildClient();

      await client.send(
        http.Request('POST', Uri.parse('https://x.test'))..body = 'a=1&b=2',
      );

      expect(captured.single.body, 'a=1&b=2');
    });

    test('sends an empty body for a bodyless POST to keep it a POST', () async {
      final client = buildClient();

      await client.send(http.Request('POST', Uri.parse('https://x.test')));

      expect(captured.single.body, '');
    });

    test('maps the CurlResponse onto a StreamedResponse', () async {
      final client = buildClient();

      final response = await http.Response.fromStream(
        await client.send(http.Request('GET', Uri.parse('https://x.test'))),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'hello');
      expect(response.headers['content-type'], 'text/plain');
      expect(response.contentLength, 5);
    });

    test('honours a custom impersonation target', () async {
      final client = CurlImpersonateClient(
        libraryPath: '/lib/libcurl.dylib',
        impersonate: 'safari18',
        fetch: (libraryPath, request) async {
          captured.add(request);
          return stubbed;
        },
      );

      await client.send(http.Request('GET', Uri.parse('https://x.test')));

      expect(captured.single.impersonate, 'safari18');
    });

    test('defaults the fetch seam to the real FFI entry point', () {
      final client = CurlImpersonateClient(libraryPath: '/lib/libcurl.dylib');
      expect(client.caCertPath, isNull);
      expect(client.impersonate, 'chrome146');
    });
  });
}
