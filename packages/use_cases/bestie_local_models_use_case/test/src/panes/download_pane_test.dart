import 'dart:async';

import 'package:bestie_local_models_use_case/src/panes/download_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/quant_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:fake_async/fake_async.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  const gptOss = RepoSummary(
    repo: 'lmstudio-community/gpt-oss-20b-GGUF',
    downloads: 2400000,
    likes: 612,
    architecture: 'gpt_oss',
    parameterCount: 20900000000,
  );
  const vision = RepoSummary(
    repo: 'bartowski/gemma-4-12B-vision-GGUF',
    downloads: 96000,
    likes: 40,
    unrunnable: ArchitectureUnsupported('gemma4v'),
  );
  const bare = RepoSummary(repo: 'someone/bare-GGUF');

  late MockLocalModelsOperations operations;
  late StreamController<ModelLibrary> library;

  setUp(() {
    operations = MockLocalModelsOperations();
    library = StreamController<ModelLibrary>.broadcast();
    stubOperations(
      operations,
      library: Stream.multi((controller) {
        controller.add(readyLibrary);
        final subscription = library.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      }),
    );
  });

  DownloadPane paneOf() =>
      DownloadPane(operations: operations, startTimer: Timer.new);

  void answer(String query, RepoSearchResult result) => when(
    () => operations.search(query),
  ).thenAnswer((_) async => result);

  test('searches Hugging Face as you type', () {
    final pane = paneOf();
    expect(pane.title, 'Download');
    expect(pane.placeholder, 'Search Hugging Face for GGUF models…');
    expect(pane.filter, PaneFilter.search);
  });

  test('lists the most downloaded GGUFs straight away for an empty query', () {
    fakeAsync((async) {
      answer('', const RepoSearchSucceeded([gptOss, gemmaRepo]));
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      final contents = <PaneContent>[];
      pane.content('').listen(contents.add);
      async.elapse(Duration.zero);

      final section = contents.last.sections.single;
      expect(section.title, 'Most downloaded GGUFs');
      expect(section.rows.map((row) => row.label), [
        'gpt-oss-20b-GGUF',
        'gemma-4-E4B-it-GGUF',
      ]);
      expect(statuses.last, isNull);
    });
  });

  test('keeps its band empty while listing for an empty query', () {
    fakeAsync((async) {
      final pending = Completer<RepoSearchResult>();
      when(() => operations.search('  ')).thenAnswer((_) => pending.future);
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      pane.content('  ').listen((_) {});
      async.elapse(Duration.zero);
      verify(() => operations.search('  ')).called(1);
      expect(statuses, everyElement(isNull));
      pending.complete(const RepoSearchSucceeded([gptOss]));
      async.flushMicrotasks();
      expect(statuses, everyElement(isNull));
    });
  });

  test('waits for typing to pause before searching', () {
    fakeAsync((async) {
      answer('gemma 4', const RepoSearchSucceeded([gemmaRepo]));
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      final contents = <PaneContent>[];
      pane.content('gemma 4').listen(contents.add);
      async.elapse(const Duration(milliseconds: 349));
      verifyNever(() => operations.search(any()));
      async.elapse(const Duration(milliseconds: 1));
      verify(() => operations.search('gemma 4')).called(1);
      expect(contents.last.sections.single.title, 'Hugging Face');
      expect(spansText(statuses.last!.trailing), '1 result');
    });
  });

  test('never searches for a query typed over before it settled', () {
    fakeAsync((async) {
      final pane = paneOf();
      final subscription = pane.content('gem').listen((_) {});
      async.elapse(const Duration(milliseconds: 100));
      unawaited(subscription.cancel());
      async.elapse(const Duration(seconds: 1));
      verifyNever(() => operations.search(any()));
    });
  });

  test('spins while searching, then counts the results', () {
    fakeAsync((async) {
      final pending = Completer<RepoSearchResult>();
      when(
        () => operations.search('gemma'),
      ).thenAnswer((_) => pending.future);
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      pane.content('gemma').listen((_) {});
      async.elapse(const Duration(milliseconds: 350));
      expect(spansText(statuses.last!.spans), 'Searching Hugging Face');
      expect(statuses.last!.progress, isA<PaneIndeterminate>());
      pending.complete(const RepoSearchSucceeded([gptOss, gemmaRepo]));
      async.flushMicrotasks();
      expect(statuses.last!.progress, isNull);
      expect(spansText(statuses.last!.trailing), '2 results');
    });
  });

  test('drops a search that returns after the query changed', () {
    fakeAsync((async) {
      final pending = Completer<RepoSearchResult>();
      when(() => operations.search('gem')).thenAnswer((_) => pending.future);
      final pane = paneOf();
      final contents = <PaneContent>[];
      final subscription = pane.content('gem').listen(contents.add);
      async.elapse(const Duration(milliseconds: 350));
      unawaited(subscription.cancel());
      pending.complete(const RepoSearchSucceeded([gemmaRepo]));
      async.flushMicrotasks();
      expect(contents, isEmpty);
      verifyNever(() => operations.library);
    });
  });

  test('shows the last results again without searching when you return', () {
    fakeAsync((async) {
      answer('', const RepoSearchSucceeded([gptOss]));
      final pane = paneOf();
      unawaited(pane.content('').first);
      async.elapse(Duration.zero);
      final contents = <PaneContent>[];
      pane.content('').listen(contents.add);
      async.elapse(Duration.zero);
      verify(() => operations.search('')).called(1);
      expect(contents.single.rows.single.label, 'gpt-oss-20b-GGUF');
    });
  });

  test('says when Hugging Face could not search, and keeps no rows', () {
    fakeAsync((async) {
      answer('qwen', const RepoSearchFailed('HTTP 503'));
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      final contents = <PaneContent>[];
      pane.content('qwen').listen(contents.add);
      async.elapse(const Duration(milliseconds: 350));
      expect(statuses.last!.glyph, '⚠');
      expect(statuses.last!.glyphTone, PaneTone.danger);
      expect(
        spansText(statuses.last!.spans),
        "Hugging Face couldn't search: HTTP 503",
      );
      expect(contents.last.rows, isEmpty);
    });
  });

  test('stops searching when the search breaks instead of answering', () {
    fakeAsync((async) {
      when(
        () => operations.search(''),
      ).thenAnswer((_) async => throw StateError('No element'));
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      final contents = <PaneContent>[];
      pane.content('').listen(contents.add);
      async.elapse(Duration.zero);
      expect(
        spansText(statuses.last!.spans),
        "Hugging Face couldn't search: Bad state: No element",
      );
      expect(contents.last.rows, isEmpty);
    });
  });

  test('says when Hugging Face did not answer in time, and retries', () {
    fakeAsync((async) {
      answer('qwen7-ultra', const RepoSearchTimedOut(Duration(seconds: 10)));
      final pane = paneOf();
      final statuses = <PaneStatus?>[];
      pane.status.listen(statuses.add);
      pane.content('qwen7-ultra').listen((_) {});
      async.elapse(const Duration(milliseconds: 350));
      expect(
        spansText(statuses.last!.spans),
        "Hugging Face didn't answer within 10s. Check your connection, then "
        'type to retry.',
      );
      pane.content('qwen7-ultra').listen((_) {});
      async.elapse(const Duration(milliseconds: 350));
      verify(() => operations.search('qwen7-ultra')).called(2);
    });
  });

  test('suggests a family name when nothing matches', () {
    fakeAsync((async) {
      answer(' qwen7-ultra ', const RepoSearchSucceeded([]));
      final contents = <PaneContent>[];
      paneOf().content(' qwen7-ultra ').listen(contents.add);
      async.elapse(const Duration(milliseconds: 350));
      final section = contents.last.sections.single;
      expect(section.rows, isEmpty);
      expect(section.notes.map(noteText), [
        '',
        'No GGUF repos match “qwen7-ultra”.',
        '',
        'Try a family name like qwen3, gemma 4 or gpt-oss.',
      ]);
    });
  });

  group('a repo row', () {
    PaneContent contentFor(
      FakeAsync async,
      List<RepoSummary> repos, {
      ModelLibrary? have,
    }) {
      answer('', RepoSearchSucceeded(repos));
      final contents = <PaneContent>[];
      paneOf().content('').listen(contents.add);
      async.elapse(Duration.zero);
      if (have != null) {
        library.add(have);
        async.flushMicrotasks();
      }
      return contents.last;
    }

    test('shows its downloads, likes, owner, architecture and size', () {
      fakeAsync((async) {
        final row = contentFor(async, [gemmaRepo]).rows.single;
        expect(row.glyph, '·');
        expect(row.label, 'gemma-4-E4B-it-GGUF');
        expect(spansText(row.trailing), '↓988K  ♡287');
        expect(spansText(row.detail), 'lmstudio-community · gemma4 · 7.5B');
        expect(row.keywords, 'lmstudio-community/gemma-4-E4B-it-GGUF');
      });
    });

    test('shows just the owner when Hugging Face says nothing else', () {
      fakeAsync((async) {
        final row = contentFor(async, [bare]).rows.single;
        expect(spansText(row.trailing), '');
        expect(spansText(row.detail), 'someone');
      });
    });

    test('mutes a repo bestie cannot run and says why', () {
      fakeAsync((async) {
        final row = contentFor(async, [vision]).rows.single;
        expect(row.glyph, '⊘');
        expect(row.labelTone, PaneTone.muted);
        expect(
          spansText(row.detail),
          "bartowski · gemma4v isn't supported yet",
        );
      });
    });

    test('ticks a repo the library has, whether downloading or done', () {
      fakeAsync((async) {
        final content = contentFor(
          async,
          [gptOss, gemmaRepo, vision, bare],
          have: ModelLibrary(
            status: const LibraryReady(),
            downloading: [modelDownload(repo: gptOss.repo)],
            needsAttention: [modelDownload(repo: vision.repo)],
            downloaded: [
              supportedModel(
                source: DownloadedSource(
                  downloadId: 'x',
                  repo: gemmaRepo.repo,
                  file: 'x.gguf',
                ),
              ),
              unsupportedModel(),
            ],
          ),
        );
        expect(content.rows.map((row) => row.glyph), ['✓', '✓', '✓', '·']);
        expect(content.rows.first.glyphTone, PaneTone.success);
      });
    });

    test('opens the quants of the repo on Enter', () {
      fakeAsync((async) {
        final row = contentFor(async, [gemmaRepo]).rows.single;
        final action = actionOf(row, const PrimaryKey());
        expect(action.label, 'Choose quant');
        PaneActionResult? result;
        unawaited(action.invoke().then((value) => result = value));
        async.flushMicrotasks();
        expect(
          result,
          isA<PanePush>().having(
            (push) => (push.pane as QuantPane).repo,
            'repo',
            same(gemmaRepo),
          ),
        );
      });
    });

    test('offers to explain why on Enter for a repo bestie cannot run', () {
      fakeAsync((async) {
        final row = contentFor(async, [vision]).rows.single;
        final action = actionOf(row, const PrimaryKey());
        expect(row.glyph, '⊘');
        expect(action.label, 'Why');
        PaneActionResult? result;
        unawaited(action.invoke().then((value) => result = value));
        async.flushMicrotasks();
        expect(
          result,
          isA<PanePush>().having(
            (push) => (push.pane as QuantPane).repo,
            'repo',
            same(vision),
          ),
        );
      });
    });
  });

  test('closes its status when disposed', () async {
    final pane = paneOf();
    final done = pane.status.drain<void>();
    await pane.dispose();
    await done;
  });
}
