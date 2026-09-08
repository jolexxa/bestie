import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_page_client/web_page_client.dart';

class _MockWebPageClient extends Mock implements WebPageClient {}

const storeAt = 'out/call-1';
const url = 'https://cows.example/article';

void main() {
  late MemoryFileSystem fileSystem;
  late _MockWebPageClient pages;
  late WebFetchTools tools;

  setUpAll(() {
    registerFallbackValue(Uri.parse(url));
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work').createSync(recursive: true);
    pages = _MockWebPageClient();
    tools = WebFetchTools(
      pages: pages,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: '/work',
      ),
    );
  });

  void answerWith(PageOutcome outcome) {
    when(() => pages.fetch(any())).thenAnswer((_) async => outcome);
  }

  test('writes the whole page and answers with the head', () async {
    answerWith(
      PageFetched(url: url, text: 'x' * 500, title: 'All About Cows'),
    );
    tools = WebFetchTools(
      pages: pages,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: '/work',
        headCacheChars: 100,
      ),
    );

    final outcome =
        await tools.fetch(url: url, storeAt: storeAt) as WebFetchSucceeded;

    expect(outcome.title, 'All About Cows');
    expect(outcome.body.head.text.length, 100);
    expect(outcome.body.totalChars, 500);
    expect(outcome.body.head.isWhole, isFalse);
    expect(
      fileSystem.file('/work/$storeAt').readAsStringSync().length,
      500,
    );
  });

  test('fetches the url it was given', () async {
    answerWith(const PageHadNoContent());

    await tools.fetch(url: url, storeAt: storeAt);

    verify(() => pages.fetch(Uri.parse(url))).called(1);
  });

  test('refuses a url that will not parse', () async {
    expect(
      await tools.fetch(
        url: 'http://[oops',
        storeAt: storeAt,
      ),
      isA<WebFetchUrlInvalid>(),
    );
    verifyNever(() => pages.fetch(any()));
  });

  test('says so when there was no article in the page', () async {
    answerWith(const PageHadNoContent());

    expect(
      await tools.fetch(url: url, storeAt: storeAt),
      isA<WebFetchFoundNoContent>(),
    );
    expect(fileSystem.file('/work/$storeAt').existsSync(), isFalse);
  });

  test('carries the reason the page did not come back', () async {
    answerWith(const PageUnavailable('connection reset'));

    final outcome = await tools.fetch(
      url: url,
      storeAt: storeAt,
    );

    expect((outcome as WebFetchFailed).reason, 'connection reset');
  });
}
