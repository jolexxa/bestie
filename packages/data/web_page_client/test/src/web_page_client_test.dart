import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:web_page_client/web_page_client.dart';

const _article = '''
<html>
  <head><title>All About Cows</title></head>
  <body><article><p>Cows are large domesticated bovines kept for milk and
  meat across most of the inhabited world, and they have been for a very long
  time indeed.</p></article></body>
</html>
''';

void main() {
  WebPageClient clientReturning(
    Future<http.Response> Function(http.Request request) respond,
  ) => WebPageClient(client: MockClient(respond));

  final url = Uri.parse('https://cows.example/article');

  test('extracts the article and its title', () async {
    final client = clientReturning((_) async => http.Response(_article, 200));

    final outcome = await client.fetch(url);

    expect(outcome, isA<PageFetched>());
    final page = outcome as PageFetched;
    expect(page.url, 'https://cows.example/article');
    expect(page.title, 'All About Cows');
    expect(page.text, contains('domesticated bovines'));
  });

  test('routes the fetch through the injected transport', () async {
    Uri? asked;
    final client = clientReturning((request) async {
      asked = request.url;
      return http.Response(_article, 200);
    });

    await client.fetch(url);

    expect(asked, url);
  });

  test('says there was no content when the body is empty', () async {
    final client = clientReturning((_) async => http.Response('', 200));

    expect(await client.fetch(url), isA<PageHadNoContent>());
  });

  test('says there was no content when nothing could be extracted', () async {
    final client = clientReturning(
      (_) async => http.Response('<html><body></body></html>', 200),
    );

    expect(await client.fetch(url), isA<PageHadNoContent>());
  });

  test('says it is unavailable when the transport gives up', () async {
    final client = clientReturning(
      (_) async => throw http.ClientException('connection reset'),
    );

    final outcome = await client.fetch(url);

    expect(outcome, isA<PageUnavailable>());
    expect((outcome as PageUnavailable).reason, 'connection reset');
  });
}
