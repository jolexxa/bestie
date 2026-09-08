import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metasearch_client/metasearch_client.dart';
import 'package:test/test.dart';

void main() {
  MetasearchClient clientReturning(
    Future<http.Response> Function(http.Request request) respond,
  ) => MetasearchClient(client: MockClient(respond));

  test('routes web search through the injected transport', () async {
    var calls = 0;
    final client = clientReturning((_) async {
      calls++;
      return http.Response('<html></html>', 200);
    });

    final results = await client.searchWeb('cows', maxResults: 3);

    expect(calls, greaterThan(0));
    expect(results, isEmpty);
  });

  test('routes news search through the injected transport', () async {
    var calls = 0;
    final client = clientReturning((_) async {
      calls++;
      return http.Response('<html></html>', 200);
    });

    final results = await client.searchNews(
      'cows',
      maxResults: 3,
      window: NewsWindow.day,
    );

    expect(calls, greaterThan(0));
    expect(results, isEmpty);
  });

  test('reports a page it could not be served as no results', () async {
    final client = clientReturning((_) async => http.Response('nope', 500));

    expect(await client.searchWeb('cows', maxResults: 3), isEmpty);
  });
}
