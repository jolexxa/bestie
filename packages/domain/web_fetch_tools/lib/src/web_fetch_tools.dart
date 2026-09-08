import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:web_fetch_tools/src/models/web_fetch_outcome.dart';
import 'package:web_page_client/web_page_client.dart';

/// What Bestie's web fetch tool does.
@repository
class WebFetchTools {
  WebFetchTools({
    required WebPageClient pages,
    required FilesDataSource files,
  }) : _pages = pages,
       _files = files;

  final WebPageClient _pages;
  final FilesDataSource _files;

  Future<WebFetchOutcome> fetch({
    required String url,
    required String storeAt,
  }) async {
    final address = Uri.tryParse(url);
    if (address == null) return WebFetchUrlInvalid(url: url);

    return switch (await _pages.fetch(address)) {
      PageUnavailable(:final reason) => WebFetchFailed(
        url: url,
        reason: reason,
      ),
      PageHadNoContent() => WebFetchFoundNoContent(url: url),
      PageFetched(:final text, :final title) => WebFetchSucceeded(
        url: url,
        title: title,
        body: await _files.storeProse(storeAt, text),
      ),
    };
  }
}
