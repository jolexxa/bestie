import 'package:arxiv_client/arxiv_client.dart';
import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockArxivSearchClient extends Mock implements ArxivSearchClient {}

const storeAt = 'out/call-1';

ArxivPaper _paper(int at, {String? category}) => ArxivPaper(
  id: 'https://arxiv.org/abs/$at',
  title: 'Paper $at',
  authors: const ['Ada Bovine'],
  published: DateTime.utc(2026, 3, 4),
  summary: 'About cows, number $at.',
  category: category,
);

void main() {
  late MemoryFileSystem fileSystem;
  late _MockArxivSearchClient arxiv;
  late ArxivTools tools;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work').createSync(recursive: true);
    arxiv = _MockArxivSearchClient();
    tools = ArxivTools(
      arxiv: arxiv,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: '/work',
      ),
    );
  });

  String stored() => fileSystem.file('/work/$storeAt').readAsStringSync();

  void answerWith(ArxivOutcome outcome) {
    when(
      () => arxiv.search(any(), maxResults: any(named: 'maxResults')),
    ).thenAnswer((_) async => outcome);
  }

  Future<ArxivSearchOutcome> search({String? category, int maxResults = 5}) =>
      tools.search(
        query: 'cows',
        storeAt: storeAt,
        maxResults: maxResults,
        category: category,
      );

  test('writes every paper out and cites each one', () async {
    answerWith(ArxivPapersFound([_paper(1, category: 'cs.AI')]));

    final outcome = await search() as ArxivSearchSucceeded;

    expect(outcome.papers, 1);
    expect(stored(), '''
1. Paper 1
https://arxiv.org/abs/1
Authors: Ada Bovine
Published: 2026-03-04
Category: cs.AI
About cows, number 1.''');
    expect(outcome.sources.single.url, 'https://arxiv.org/abs/1');
    expect(outcome.sources.single.title, 'Paper 1');
  });

  test('leaves out a category the paper does not have', () async {
    answerWith(ArxivPapersFound([_paper(1)]));

    await search();

    expect(stored(), isNot(contains('Category:')));
  });

  test('separates papers with a blank line', () async {
    answerWith(ArxivPapersFound([_paper(1), _paper(2)]));

    await search();

    expect(stored(), contains('About cows, number 1.\n\n2. Paper 2'));
  });

  test('searches every field when no category was asked for', () async {
    answerWith(const ArxivPapersFound([]));

    await search();

    verify(() => arxiv.search('all:cows', maxResults: 5)).called(1);
  });

  test('narrows to a category when one was asked for', () async {
    answerWith(const ArxivPapersFound([]));

    await search(category: 'cs.AI');

    verify(
      () => arxiv.search('cat:cs.AI AND all:cows', maxResults: 5),
    ).called(1);
  });

  test('treats an empty category as none at all', () async {
    answerWith(const ArxivPapersFound([]));

    await search(category: '');

    verify(() => arxiv.search('all:cows', maxResults: 5)).called(1);
  });

  test('finds nothing and writes nothing when there are no papers', () async {
    answerWith(const ArxivPapersFound([]));

    expect(await search(), isA<ArxivSearchFoundNothing>());
    expect(fileSystem.file('/work/$storeAt').existsSync(), isFalse);
  });

  test('carries the reason arXiv could not answer', () async {
    answerWith(const ArxivUnavailable('connection reset'));

    final outcome = await search();

    expect((outcome as ArxivSearchUnavailable).reason, 'connection reset');
  });
}
