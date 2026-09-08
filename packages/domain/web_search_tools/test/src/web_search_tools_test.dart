import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:metasearch_client/metasearch_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:web_search_tools/web_search_tools.dart';

class _MockMetasearchClient extends Mock implements MetasearchClient {}

const storeAt = 'out/call-1';

SearchResult _result(int at) => SearchResult(
  title: 'Result $at',
  url: 'https://cows.example/$at',
  snippet: 'About cows, number $at.',
);

void main() {
  late MemoryFileSystem fileSystem;
  late _MockMetasearchClient search;
  late WebSearchTools tools;

  setUpAll(() {
    registerFallbackValue(NewsWindow.week);
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work').createSync(recursive: true);
    search = _MockMetasearchClient();
    tools = WebSearchTools(
      search: search,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: '/work',
      ),
    );
  });

  String stored() => fileSystem.file('/work/$storeAt').readAsStringSync();

  void webReturns(List<SearchResult> results) {
    when(
      () => search.searchWeb(any(), maxResults: any(named: 'maxResults')),
    ).thenAnswer((_) async => results);
  }

  void newsReturns(List<SearchResult> results) {
    when(
      () => search.searchNews(
        any(),
        maxResults: any(named: 'maxResults'),
        window: any(named: 'window'),
      ),
    ).thenAnswer((_) async => results);
  }

  group('searchWeb', () {
    test('writes every result out, one block each', () async {
      webReturns([_result(1), _result(2)]);

      final outcome =
          await tools.searchWeb(
                query: 'cows',
                storeAt: storeAt,
              )
              as WebSearchSucceeded;

      expect(outcome.results, 2);
      expect(stored(), '''
1. Result 1
https://cows.example/1
About cows, number 1.

2. Result 2
https://cows.example/2
About cows, number 2.''');
      expect(outcome.body.head.isWhole, isTrue);
    });

    test('answers with only the head when there is too much', () async {
      webReturns([for (var at = 0; at < 40; at++) _result(at)]);
      tools = WebSearchTools(
        search: search,
        files: FilesDataSource(
          fileSystem: fileSystem,
          workingDirectory: '/work',
          headCacheChars: 60,
        ),
      );

      final outcome =
          await tools.searchWeb(
                query: 'cows',
                storeAt: storeAt,
              )
              as WebSearchSucceeded;

      expect(outcome.results, 40);
      expect(outcome.body.head.isWhole, isFalse);
      expect(outcome.body.head.text.length, lessThanOrEqualTo(60));
      expect(stored(), contains('40. Result 39'));
    });

    test('finds nothing and writes nothing when there are no hits', () async {
      webReturns([]);

      expect(
        await tools.searchWeb(query: 'cows', storeAt: storeAt),
        isA<WebSearchFoundNothing>(),
      );
      expect(fileSystem.file('/work/$storeAt').existsSync(), isFalse);
    });

    test('asks for the number of results it was given', () async {
      webReturns([]);

      await tools.searchWeb(
        query: 'cows',
        storeAt: storeAt,
        maxResults: 9,
      );

      verify(() => search.searchWeb('cows', maxResults: 9)).called(1);
    });
  });

  group('searchNews', () {
    test('includes the source and date when the hit has them', () async {
      newsReturns([
        SearchResult(
          title: 'Cows Today',
          url: 'https://news.example/1',
          snippet: 'A cow was seen.',
          source: 'The Herald',
          published: DateTime.utc(2026, 3, 4),
        ),
      ]);

      await tools.searchNews(
        query: 'cows',
        storeAt: storeAt,
      );

      expect(stored(), '''
1. Cows Today
Source: The Herald
Date: 2026-03-04
https://news.example/1
A cow was seen.''');
    });

    test('leaves out a source and date the hit does not have', () async {
      newsReturns([_result(1)]);

      await tools.searchNews(
        query: 'cows',
        storeAt: storeAt,
      );

      expect(stored(), isNot(contains('Source:')));
      expect(stored(), isNot(contains('Date:')));
    });

    test('leaves out an empty source', () async {
      newsReturns([
        const SearchResult(
          title: 'Cows Today',
          url: 'https://news.example/1',
          snippet: 'A cow was seen.',
          source: '',
        ),
      ]);

      await tools.searchNews(
        query: 'cows',
        storeAt: storeAt,
      );

      expect(stored(), isNot(contains('Source:')));
    });

    test('finds nothing when there are no hits', () async {
      newsReturns([]);

      expect(
        await tools.searchNews(query: 'cows', storeAt: storeAt),
        isA<NewsSearchFoundNothing>(),
      );
    });

    test('translates each period into the window to search', () async {
      newsReturns([]);

      for (final period in NewsPeriod.values) {
        await tools.searchNews(
          query: 'cows',
          storeAt: storeAt,
          period: period,
        );
      }

      for (final window in NewsWindow.values) {
        verify(
          () => search.searchNews(
            'cows',
            maxResults: any(named: 'maxResults'),
            window: window,
          ),
        ).called(1);
      }
    });
  });
}
