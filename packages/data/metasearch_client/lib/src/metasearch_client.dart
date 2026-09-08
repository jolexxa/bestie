import 'package:ddgs/ddgs.dart' as ddgs;
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:metasearch_client/src/models/news_window.dart';
import 'package:metasearch_client/src/models/search_result.dart';

/// Searches the web by asking many engines at once and merging what they say.
///
// TODO(jolexxa): return a failure once ddgs can report one. It drops a refusing
// engine and carries on, so "no engine answered" and "there is nothing to find"
// both arrive as an empty list. Reporting the failed engines alongside the
// results would make "all of them" an outcome the domain could act on.
@dataSource
class MetasearchClient {
  MetasearchClient({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<List<SearchResult>> searchWeb(
    String query, {
    required int maxResults,
  }) => _search(
    (session) => session.textTyped(
      query,
      options: ddgs.SearchOptions(maxResults: maxResults),
    ),
    (result) => SearchResult(
      title: result.title,
      url: result.href,
      snippet: result.body,
    ),
  );

  Future<List<SearchResult>> searchNews(
    String query, {
    required int maxResults,
    required NewsWindow window,
  }) => _search(
    (session) => session.newsTyped(
      query,
      options: ddgs.SearchOptions(
        maxResults: maxResults,
        timeLimit: _timeLimitOf(window),
      ),
    ),
    (result) => SearchResult(
      title: result.title,
      url: result.url,
      snippet: result.body,
      source: result.source,
      published: result.publishedDate,
    ),
  );

  Future<List<SearchResult>> _search<T>(
    Future<List<T>> Function(ddgs.DDGS session) run,
    SearchResult Function(T result) toResult,
  ) async {
    final session = ddgs.DDGS(client: _client);
    try {
      return (await run(session)).map(toResult).toList();
    } finally {
      session.close();
    }
  }

  ddgs.TimeLimit _timeLimitOf(NewsWindow window) => switch (window) {
    NewsWindow.day => ddgs.TimeLimit.day,
    NewsWindow.week => ddgs.TimeLimit.week,
    NewsWindow.month => ddgs.TimeLimit.month,
  };
}
