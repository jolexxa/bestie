import 'package:arxiv_client/arxiv_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _feed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>http://arxiv.org/abs/2401.00001v1</id>
    <published>2024-01-02T00:00:00Z</published>
    <updated>2024-01-02T00:00:00Z</updated>
    <title>On Cows</title>
    <summary>  A study of cows.  </summary>
    <author><name>Ada Bovine</name></author>
    <author><name>Grace Heifer</name></author>
    <arxiv:primary_category xmlns:arxiv="http://arxiv.org/schemas/atom"
      term="cs.AI" />
  </entry>
</feed>
''';

const _emptyFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"></feed>
''';

void main() {
  ArxivSearchClient clientReturning(
    Future<http.Response> Function(http.Request request) respond,
  ) => ArxivSearchClient(client: MockClient(respond));

  test('turns a feed into papers', () async {
    final client = clientReturning((_) async => http.Response(_feed, 200));

    final outcome = await client.search('all:cows', maxResults: 5);

    expect(outcome, isA<ArxivPapersFound>());
    final paper = (outcome as ArxivPapersFound).papers.single;
    expect(paper.title, 'On Cows');
    expect(paper.id, 'http://arxiv.org/abs/2401.00001v1');
    expect(paper.authors, ['Ada Bovine', 'Grace Heifer']);
    expect(paper.published.year, 2024);
    expect(paper.category, 'cs.AI');
    expect(paper.summary, 'A study of cows.');
  });

  test('finds no papers in an empty feed', () async {
    final client = clientReturning((_) async => http.Response(_emptyFeed, 200));

    final outcome = await client.search('all:cows', maxResults: 5);

    expect((outcome as ArxivPapersFound).papers, isEmpty);
  });

  test('says it is unavailable when the transport gives up', () async {
    final client = clientReturning(
      (_) async => throw http.ClientException('connection reset'),
    );

    expect(
      await client.search('all:cows', maxResults: 5),
      isA<ArxivUnavailable>(),
    );
  });
}
