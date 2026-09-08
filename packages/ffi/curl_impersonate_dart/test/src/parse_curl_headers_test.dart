import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';
import 'package:test/test.dart';

void main() {
  group('parseCurlHeaders', () {
    test('parses header lines into a lowercased map', () {
      final headers = parseCurlHeaders([
        'HTTP/1.1 200 OK\r\n',
        'Content-Type: text/html; charset=utf-8\r\n',
        'X-Frame-Options: DENY\r\n',
        '\r\n',
      ]);

      expect(headers, {
        'content-type': 'text/html; charset=utf-8',
        'x-frame-options': 'DENY',
      });
    });

    test('trims whitespace around names and values', () {
      final headers = parseCurlHeaders(['  Server :   nginx  \r\n']);
      expect(headers, {'server': 'nginx'});
    });

    test('skips the status line and blank separators', () {
      final headers = parseCurlHeaders([
        'HTTP/2 301\r\n',
        '\r\n',
        '   \r\n',
      ]);
      expect(headers, isEmpty);
    });

    test('keeps only the final block across redirects', () {
      final headers = parseCurlHeaders([
        'HTTP/1.1 301 Moved Permanently\r\n',
        'Location: https://example.com/\r\n',
        '\r\n',
        'HTTP/1.1 200 OK\r\n',
        'Content-Type: application/json\r\n',
        '\r\n',
      ]);

      expect(headers, {'content-type': 'application/json'});
    });

    test('joins duplicate headers with a comma', () {
      final headers = parseCurlHeaders([
        'HTTP/1.1 200 OK\r\n',
        'Set-Cookie: a=1\r\n',
        'Set-Cookie: b=2\r\n',
      ]);

      expect(headers['set-cookie'], 'a=1, b=2');
    });

    test('ignores lines without a value-bearing colon', () {
      final headers = parseCurlHeaders([
        'HTTP/1.1 200 OK\r\n',
        'garbage-without-colon\r\n',
        ': leading-colon\r\n',
        'Valid: yes\r\n',
      ]);

      expect(headers, {'valid': 'yes'});
    });

    test('preserves colons inside the value', () {
      final headers = parseCurlHeaders(['Date: Mon, 20 Jul 2026 10:30:00 GMT']);
      expect(headers['date'], 'Mon, 20 Jul 2026 10:30:00 GMT');
    });
  });
}
