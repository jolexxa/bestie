import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:metasearch_client/metasearch_client.dart';
import 'package:web_search_tools/src/models/news_period.dart';
import 'package:web_search_tools/src/models/news_search_outcome.dart';
import 'package:web_search_tools/src/models/web_search_outcome.dart';

/// What Bestie's web and news search tools do.
@repository
class WebSearchTools {
  WebSearchTools({
    required MetasearchClient search,
    required FilesDataSource files,
  }) : _search = search,
       _files = files;

  final MetasearchClient _search;
  final FilesDataSource _files;

  Future<WebSearchOutcome> searchWeb({
    required String query,
    required String storeAt,
    int maxResults = 5,
  }) async {
    final results = await _search.searchWeb(query, maxResults: maxResults);
    if (results.isEmpty) return WebSearchFoundNothing(query: query);

    return WebSearchSucceeded(
      query: query,
      body: await _files.storeLines(
        storeAt,
        _renderWeb(results),
      ),
      results: results.length,
    );
  }

  Future<NewsSearchOutcome> searchNews({
    required String query,
    required String storeAt,
    int maxResults = 5,
    NewsPeriod period = NewsPeriod.week,
  }) async {
    final results = await _search.searchNews(
      query,
      maxResults: maxResults,
      window: _windowOf(period),
    );
    if (results.isEmpty) return NewsSearchFoundNothing(query: query);

    return NewsSearchSucceeded(
      query: query,
      body: await _files.storeLines(
        storeAt,
        _renderNews(results),
      ),
      results: results.length,
    );
  }

  Stream<String> _renderWeb(List<SearchResult> results) async* {
    for (var at = 0; at < results.length; at++) {
      final result = results[at];
      if (at > 0) yield '';
      yield '${at + 1}. ${result.title}';
      yield result.url;
      yield result.snippet;
    }
  }

  Stream<String> _renderNews(List<SearchResult> results) async* {
    for (var at = 0; at < results.length; at++) {
      final result = results[at];
      if (at > 0) yield '';
      yield '${at + 1}. ${result.title}';
      if (result.source case final source? when source.isNotEmpty) {
        yield 'Source: $source';
      }
      if (result.published case final published?) {
        yield 'Date: ${_dateOf(published)}';
      }
      yield result.url;
      yield result.snippet;
    }
  }

  String _dateOf(DateTime moment) =>
      '${moment.year}-'
      '${moment.month.toString().padLeft(2, '0')}-'
      '${moment.day.toString().padLeft(2, '0')}';

  NewsWindow _windowOf(NewsPeriod period) => switch (period) {
    NewsPeriod.day => NewsWindow.day,
    NewsPeriod.week => NewsWindow.week,
    NewsPeriod.month => NewsWindow.month,
  };
}
