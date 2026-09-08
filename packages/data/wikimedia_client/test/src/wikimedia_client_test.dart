import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:wikimedia_client/wikimedia_client.dart';

http.Response _search(List<Map<String, Object?>> pages) => http.Response(
  jsonEncode({
    'query': {'search': pages},
  }),
  200,
);

Map<String, Object?> _page(
  String title, {
  String snippet = '',
  int id = 1,
}) => {
  'title': title,
  'snippet': snippet,
  'pageid': id,
  'size': 100,
  'wordcount': 20,
  'timestamp': '2024-01-02T00:00:00Z',
};

void main() {
  WikimediaClient clientReturning(
    Future<http.Response> Function(http.Request request) respond,
  ) => WikimediaClient(client: MockClient(respond));

  test('strips markup out of the description', () async {
    final client = clientReturning(
      (_) async => _search([
        _page('Cattle', snippet: 'Cattle are <span class="hit">bovines</span>'),
      ]),
    );

    final outcome = await client.searchTopics('cows', maxResults: 5);

    expect(outcome, isA<WikipediaTopicsFound>());
    final topic = (outcome as WikipediaTopicsFound).topics.single;
    expect(topic.title, 'Cattle');
    expect(topic.description, 'Cattle are bovines');
  });

  test('builds an address when the service gives none', () async {
    final client = clientReturning(
      (_) async => _search([_page('Dairy cattle')]),
    );

    final outcome =
        await client.searchTopics('cows', maxResults: 5)
            as WikipediaTopicsFound;

    expect(
      outcome.topics.single.url,
      'https://en.wikipedia.org/wiki/Dairy_cattle',
    );
  });

  test('finds no topics when the service returns none', () async {
    final client = clientReturning((_) async => _search([]));

    final outcome = await client.searchTopics('cows', maxResults: 5);

    expect((outcome as WikipediaTopicsFound).topics, isEmpty);
  });

  test('says it is unavailable when the service cannot answer', () async {
    final client = clientReturning(
      (_) async => http.Response('not json', 500),
    );

    expect(
      await client.searchTopics('cows', maxResults: 5),
      isA<WikipediaUnavailable>(),
    );
  });
}
