import 'package:arxiv_client/arxiv_client.dart';
import 'package:arxiv_tools/src/models/arxiv_search_outcome.dart';
import 'package:arxiv_tools/src/models/paper_source.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

/// What Bestie's arXiv search tool does.
@repository
class ArxivTools {
  ArxivTools({
    required ArxivSearchClient arxiv,
    required FilesDataSource files,
  }) : _arxiv = arxiv,
       _files = files;

  final ArxivSearchClient _arxiv;
  final FilesDataSource _files;

  Future<ArxivSearchOutcome> search({
    required String query,
    required String storeAt,
    int maxResults = 5,
    String? category,
  }) async {
    final outcome = await _arxiv.search(
      _expressionFor(query, category),
      maxResults: maxResults,
    );

    return switch (outcome) {
      ArxivUnavailable(:final reason) => ArxivSearchUnavailable(
        query: query,
        reason: reason,
      ),
      ArxivPapersFound(:final papers) when papers.isEmpty =>
        ArxivSearchFoundNothing(query: query),
      ArxivPapersFound(:final papers) => ArxivSearchSucceeded(
        query: query,
        body: await _files.storeLines(storeAt, _render(papers)),
        papers: papers.length,
        sources: [
          for (final paper in papers)
            PaperSource(url: paper.id, title: paper.title),
        ],
      ),
    };
  }

  /// arXiv's query syntax, which is what a category filter really is.
  String _expressionFor(String query, String? category) =>
      category == null || category.isEmpty
      ? 'all:$query'
      : 'cat:$category AND all:$query';

  Stream<String> _render(List<ArxivPaper> papers) async* {
    for (var at = 0; at < papers.length; at++) {
      final paper = papers[at];
      if (at > 0) yield '';
      yield '${at + 1}. ${paper.title}';
      yield paper.id;
      yield 'Authors: ${paper.authors.join(', ')}';
      yield 'Published: ${_dateOf(paper.published)}';
      if (paper.category case final category?) yield 'Category: $category';
      yield paper.summary;
    }
  }

  String _dateOf(DateTime moment) =>
      '${moment.year}-'
      '${moment.month.toString().padLeft(2, '0')}-'
      '${moment.day.toString().padLeft(2, '0')}';
}
