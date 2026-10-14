import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/search/repo_searcher.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

class _MockHub extends Mock implements HubClient {}

HfModel _model(
  String id, {
  String? architecture,
  String? chatTemplate = qwen3Template,
  String? pipelineTag,
}) => HfModel(
  id: id,
  pipelineTag: pipelineTag,
  downloads: 1200,
  likes: 34,
  gguf: architecture == null
      ? null
      : HfGgufInfo(
          total: 8200000000,
          architecture: architecture,
          chatTemplate: chatTemplate,
        ),
);

void main() {
  late _MockHub hub;
  late RepoSearcher searcher;

  void answer(Future<HfSearchResult> Function() result) => when(
    () => hub.searchModels(
      search: any(named: 'search'),
      filter: any(named: 'filter'),
      sort: any(named: 'sort'),
      direction: any(named: 'direction'),
      limit: any(named: 'limit'),
      expand: any(named: 'expand'),
    ),
  ).thenAnswer((_) => result());

  setUp(() {
    hub = _MockHub();
    searcher = RepoSearcher(hub);
  });

  test('asks for the most downloaded GGUF repos matching the query', () async {
    answer(
      () async => HfSearchSucceeded(
        PaginatedResponse(
          items: [
            _model(
              'lmstudio-community/Qwen3-8B-GGUF',
              architecture: 'qwen3',
              pipelineTag: 'text-generation',
            ),
            _model('bartowski/granite-GGUF', architecture: 'granite'),
            _model(
              'someone/Distill-GGUF',
              architecture: 'qwen2',
              chatTemplate: deepSeekTemplate,
            ),
            _model('unsloth/Mystery-GGUF'),
            _model(
              'jinaai/jina-embeddings-v5-text-nano-retrieval-GGUF',
              architecture: 'qwen3',
              pipelineTag: 'sentence-similarity',
            ),
            _model(
              'mradermacher/Qwen3-VL-Reranker-2B-GGUF',
              architecture: 'qwen3',
            ),
          ],
        ),
      ),
    );

    final result = await searcher.search(
      '  qwen 3 ',
      limit: 20,
      timeout: const Duration(seconds: 10),
    );

    verify(
      () => hub.searchModels(
        search: 'qwen 3',
        filter: 'gguf',
        sort: 'downloads',
        direction: SortDirection.descending,
        limit: 20,
        expand: const [
          ModelExpandField.author,
          ModelExpandField.downloads,
          ModelExpandField.likes,
          ModelExpandField.gguf,
          ModelExpandField.pipelineTag,
        ],
      ),
    ).called(1);
    final repos = (result as RepoSearchSucceeded).repos;
    expect(repos.map((repo) => repo.repo), [
      'lmstudio-community/Qwen3-8B-GGUF',
      'bartowski/granite-GGUF',
      'someone/Distill-GGUF',
      'unsloth/Mystery-GGUF',
      'jinaai/jina-embeddings-v5-text-nano-retrieval-GGUF',
      'mradermacher/Qwen3-VL-Reranker-2B-GGUF',
    ]);
    final qwen = repos.first;
    expect(qwen.owner, 'lmstudio-community');
    expect(qwen.name, 'Qwen3-8B-GGUF');
    expect(qwen.downloads, 1200);
    expect(qwen.likes, 34);
    expect(qwen.architecture, 'qwen3');
    expect(qwen.parameterCount, 8200000000);
    expect(qwen.unrunnable, isNull);
    expect(
      repos[1].unrunnable,
      isA<ArchitectureUnsupported>().having(
        (reason) => reason.architecture,
        'architecture',
        'granite',
      ),
    );
    expect(repos[2].unrunnable, isA<TemplateUnrecognized>());
    expect(repos[3].unrunnable, isNull, reason: 'unknown until downloaded');
    expect(repos[3].architecture, isNull);
    expect(
      repos[4].unrunnable,
      isA<NotAChatModel>().having(
        (reason) => reason.task,
        'task',
        'sentence-similarity',
      ),
      reason: 'a chat architecture does not make an embedder a chat model',
    );
    expect(
      repos[5].unrunnable,
      isA<NotAChatModel>().having(
        (reason) => reason.task,
        'task',
        'text-ranking',
      ),
      reason: 'untagged, so its name decides',
    );
  });

  test('an empty query lists the most downloaded of all', () async {
    answer(
      () async => const HfSearchSucceeded(PaginatedResponse(items: [])),
    );

    final result = await searcher.search(
      ' ',
      limit: 5,
      timeout: const Duration(seconds: 10),
    );

    expect((result as RepoSearchSucceeded).repos, isEmpty);
    verify(
      () => hub.searchModels(
        filter: 'gguf',
        sort: 'downloads',
        direction: SortDirection.descending,
        limit: 5,
        expand: any(named: 'expand'),
      ),
    ).called(1);
  });

  test('a failed request reports the Hub message', () async {
    answer(
      () async => const HfRequestFailed(message: 'rate limited'),
    );

    final result = await searcher.search(
      'gemma',
      limit: 20,
      timeout: const Duration(seconds: 10),
    );

    expect(
      result,
      isA<RepoSearchFailed>().having(
        (failed) => failed.message,
        'message',
        'rate limited',
      ),
    );
  });

  test('a Hub that does not answer in time times out', () {
    fakeAsync((async) {
      answer(() => Completer<HfSearchResult>().future);
      RepoSearchResult? result;
      unawaited(
        searcher
            .search('gemma', limit: 20, timeout: const Duration(seconds: 10))
            .then((value) => result = value),
      );

      async.elapse(const Duration(seconds: 9));
      expect(result, isNull);
      async.elapse(const Duration(seconds: 1));
      expect(
        result,
        isA<RepoSearchTimedOut>().having(
          (timedOut) => timedOut.timeout,
          'timeout',
          const Duration(seconds: 10),
        ),
      );
    });
  });
}
