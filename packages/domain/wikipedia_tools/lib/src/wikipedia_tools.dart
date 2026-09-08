import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:wikimedia_client/wikimedia_client.dart';
import 'package:wikipedia_tools/src/models/topic_source.dart';
import 'package:wikipedia_tools/src/models/wikipedia_search_outcome.dart';

/// What Bestie's Wikipedia search tool does.
@repository
class WikipediaTools {
  WikipediaTools({
    required WikimediaClient wikipedia,
    required FilesDataSource files,
  }) : _wikipedia = wikipedia,
       _files = files;

  final WikimediaClient _wikipedia;
  final FilesDataSource _files;

  Future<WikipediaSearchOutcome> search({
    required String query,
    required String storeAt,
    int maxResults = 5,
  }) async {
    final outcome = await _wikipedia.searchTopics(
      query,
      maxResults: maxResults,
    );

    return switch (outcome) {
      WikipediaUnavailable(:final reason) => WikipediaSearchUnavailable(
        query: query,
        reason: reason,
      ),
      WikipediaTopicsFound(:final topics) when topics.isEmpty =>
        WikipediaSearchFoundNothing(query: query),
      WikipediaTopicsFound(:final topics) => WikipediaSearchSucceeded(
        query: query,
        body: await _files.storeLines(storeAt, _render(topics)),
        topics: topics.length,
        sources: [
          for (final topic in topics)
            TopicSource(url: topic.url, title: topic.title),
        ],
      ),
    };
  }

  Stream<String> _render(List<WikipediaTopic> topics) async* {
    for (var at = 0; at < topics.length; at++) {
      final topic = topics[at];
      if (at > 0) yield '';
      yield '${at + 1}. ${topic.title}';
      yield topic.url;
      if (topic.description.isNotEmpty) yield topic.description;
    }
  }
}
