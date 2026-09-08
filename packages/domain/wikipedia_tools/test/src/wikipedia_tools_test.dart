import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:wikimedia_client/wikimedia_client.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

class _MockWikimediaClient extends Mock implements WikimediaClient {}

const storeAt = 'out/call-1';

WikipediaTopic _topic(int at, {String description = 'A bovine.'}) =>
    WikipediaTopic(
      title: 'Topic $at',
      url: 'https://en.wikipedia.org/wiki/Topic_$at',
      description: description,
    );

void main() {
  late MemoryFileSystem fileSystem;
  late _MockWikimediaClient wikipedia;
  late WikipediaTools tools;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work').createSync(recursive: true);
    wikipedia = _MockWikimediaClient();
    tools = WikipediaTools(
      wikipedia: wikipedia,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: '/work',
      ),
    );
  });

  String stored() => fileSystem.file('/work/$storeAt').readAsStringSync();

  void answerWith(WikipediaOutcome outcome) {
    when(
      () => wikipedia.searchTopics(any(), maxResults: any(named: 'maxResults')),
    ).thenAnswer((_) async => outcome);
  }

  Future<WikipediaSearchOutcome> search({int maxResults = 5}) => tools.search(
    query: 'cows',
    storeAt: storeAt,
    maxResults: maxResults,
  );

  test('writes every topic out and cites each one', () async {
    answerWith(WikipediaTopicsFound([_topic(1), _topic(2)]));

    final outcome = await search() as WikipediaSearchSucceeded;

    expect(outcome.topics, 2);
    expect(stored(), '''
1. Topic 1
https://en.wikipedia.org/wiki/Topic_1
A bovine.

2. Topic 2
https://en.wikipedia.org/wiki/Topic_2
A bovine.''');
    expect(
      outcome.sources.map((source) => source.title),
      ['Topic 1', 'Topic 2'],
    );
  });

  test('leaves out an empty description', () async {
    answerWith(WikipediaTopicsFound([_topic(1, description: '')]));

    await search();

    expect(stored(), '''
1. Topic 1
https://en.wikipedia.org/wiki/Topic_1''');
  });

  test('asks for the number of results it was given', () async {
    answerWith(const WikipediaTopicsFound([]));

    await search(maxResults: 9);

    verify(() => wikipedia.searchTopics('cows', maxResults: 9)).called(1);
  });

  test('finds nothing and writes nothing when there are no topics', () async {
    answerWith(const WikipediaTopicsFound([]));

    expect(await search(), isA<WikipediaSearchFoundNothing>());
    expect(fileSystem.file('/work/$storeAt').existsSync(), isFalse);
  });

  test('carries the reason Wikipedia could not answer', () async {
    answerWith(const WikipediaUnavailable('connection reset'));

    final outcome = await search();

    expect(
      (outcome as WikipediaSearchUnavailable).reason,
      'connection reset',
    );
  });
}
