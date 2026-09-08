import 'package:arxiv_client/src/models/arxiv_outcome.dart';
import 'package:arxiv_client/src/models/arxiv_paper.dart';
import 'package:arxlib/arxlib.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';

/// Searches arXiv.
@dataSource
class ArxivSearchClient {
  ArxivSearchClient({required http.Client client}) : _client = client;

  final http.Client _client;

  /// Runs [expression], which is arXiv's own query syntax.
  Future<ArxivOutcome> search(
    String expression, {
    required int maxResults,
  }) async {
    final arxiv = ArxivClient(
      httpClient: DefaultArxivHttpClient(client: _client),
      config: ArxivClientConfig(userAgent: 'bestie', pageSize: maxResults),
    );

    try {
      final page = await arxiv.search(
        ArxivQuery.search(
          expression,
          maxResults: maxResults,
          sortBy: ArxivSortBy.relevance,
        ),
      );

      return ArxivPapersFound([
        for (final entry in page.entries)
          ArxivPaper(
            id: entry.id,
            title: entry.title,
            authors: [for (final author in entry.authors) author.name],
            published: entry.published,
            summary: entry.summary.trim(),
            category: entry.primaryCategory?.term,
          ),
      ]);
    } on Exception catch (error) {
      return ArxivUnavailable('$error');
    } finally {
      await arxiv.close();
    }
  }
}
