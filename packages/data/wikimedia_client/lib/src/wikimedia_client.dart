import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:wikimedia_client/src/models/wikipedia_outcome.dart';
import 'package:wikimedia_client/src/models/wikipedia_topic.dart';
import 'package:wikimedia_commons_search/wikimedia_commons_search.dart'
    as wikimedia;

final _markup = RegExp('<[^>]*>');

/// Searches Wikipedia for topics.
@dataSource
class WikimediaClient {
  WikimediaClient({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<WikipediaOutcome> searchTopics(
    String query, {
    required int maxResults,
  }) async {
    final wiki = wikimedia.WikimediaCommons(client: _client);
    try {
      final topics = await wiki.searchTopics(query, limit: maxResults);
      return WikipediaTopicsFound([
        for (final topic in topics)
          WikipediaTopic(
            title: topic.title,
            url: topic.url ?? _addressOf(topic.title),
            description: topic.description.replaceAll(_markup, '').trim(),
          ),
      ]);
    } on wikimedia.WikimediaNoResultsException {
      return const WikipediaTopicsFound([]);
    } on Exception catch (error) {
      return WikipediaUnavailable('$error');
    } finally {
      wiki.dispose();
    }
  }

  String _addressOf(String title) =>
      'https://en.wikipedia.org/wiki/'
      '${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
}
