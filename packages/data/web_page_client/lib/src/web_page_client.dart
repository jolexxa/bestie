import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:trafilatura/trafilatura.dart' as trafilatura;
import 'package:web_page_client/src/models/page_outcome.dart';

/// Fetches a page and pulls the article out of it.
@dataSource
class WebPageClient {
  WebPageClient({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<PageOutcome> fetch(Uri url) async {
    final String html;
    try {
      html = (await _client.get(url)).body;
    } on http.ClientException catch (error) {
      return PageUnavailable(error.message);
    }

    if (html.isEmpty) return const PageHadNoContent();

    final address = url.toString();
    final content = trafilatura.extract(
      filecontent: html,
      includeLinks: true,
      url: address,
    );
    if (content == null || content.isEmpty) return const PageHadNoContent();

    return PageFetched(
      url: address,
      text: content,
      title: trafilatura.extractMetadata(html, defaultUrl: address).title,
    );
  }
}
