import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:llm_model_profiles/llm_model_profiles.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/repo_resolver.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

class _MockHub extends Mock implements HubClient {}

SiblingInfo _lfs(String path, int size) => SiblingInfo(
  relativeFilename: path,
  lfs: LfsInfo(sha256: 'sha-$path', size: size),
);

HfModel _model(
  List<SiblingInfo> siblings, {
  String? architecture = 'qwen3',
  String? sha = 'abc123',
  String? chatTemplate = qwen3Template,
  String id = 'org/Model-GGUF',
  String? pipelineTag,
}) => HfModel(
  id: id,
  pipelineTag: pipelineTag,
  sha: sha,
  siblings: siblings,
  gguf: architecture == null
      ? null
      : HfGgufInfo(
          total: 1700000000,
          architecture: architecture,
          contextLength: 40960,
          chatTemplate: chatTemplate,
        ),
);

void main() {
  late _MockHub hub;
  late RepoResolver resolver;

  setUpAll(() => registerFallbackValue(RepoId.tryParse('a/b')));

  setUp(() {
    hub = _MockHub();
    resolver = RepoResolver(hub);
    when(
      () => hub.resolveFileUrl(
        any(),
        any(),
        revision: any(named: 'revision'),
      ),
    ).thenAnswer((invocation) {
      final id = invocation.positionalArguments[0] as RepoId;
      final file = invocation.positionalArguments[1] as String;
      final revision = invocation.namedArguments[#revision] as String;
      return Uri.parse(
        'https://hf.test/${id.fullName}/resolve/$revision/$file',
      );
    });
  });

  void hubAnswers(HfRepoResult result) =>
      when(() => hub.getModel(any())).thenAnswer((_) async => result);

  Future<RepoResolution> resolve({Set<String> inLibrary = const {}}) =>
      resolver.resolve('org/Model-GGUF', inLibrary: inLibrary);

  test('lists the quants it can run, smallest first', () async {
    hubAnswers(
      HfRepoResolved(
        _model([
          const SiblingInfo(relativeFilename: 'README.md', size: 10),
          _lfs('Model-Q8_0.gguf', 800),
          _lfs('Model-Q4_K_M.gguf', 400),
          _lfs('mmproj-Model-f16.gguf', 50),
          const SiblingInfo(relativeFilename: 'Model-Q6_K.gguf', size: 600),
        ]),
      ),
    );

    final resolved =
        await resolve(inLibrary: {'org/Model-GGUF:Model-Q8_0.gguf'})
            as RepoResolved;

    expect(resolved.repo, 'org/Model-GGUF');
    expect(resolved.revision, 'abc123');
    expect(resolved.architecture, 'qwen3');
    expect(resolved.profile, ModelProfileId.qwen3);
    expect(resolved.contextLength, 40960);
    expect(resolved.parameterCount, 1700000000);
    expect(resolved.quants.map((quant) => quant.label), [
      'Q4_K_M',
      'Q6_K',
      'Q8_0',
    ]);
    final smallest = resolved.quants.first;
    expect(smallest.type, QuantType.q4KMedium);
    expect(smallest.downloadId, 'org/Model-GGUF:Model-Q4_K_M.gguf');
    expect(smallest.inLibrary, isFalse);
    expect(smallest.sizeBytes, 400);
    final file = smallest.files.single;
    expect(file.path, 'Model-Q4_K_M.gguf');
    expect(file.sha256, 'sha-Model-Q4_K_M.gguf');
    expect(
      file.url,
      Uri.parse(
        'https://hf.test/org/Model-GGUF/resolve/abc123/Model-Q4_K_M.gguf',
      ),
    );
    expect(resolved.quants[1].files.single.sha256, isNull);
    expect(resolved.quants.last.inLibrary, isTrue);
  });

  test('groups split files into one quant', () async {
    hubAnswers(
      HfRepoResolved(
        _model([
          _lfs('Q8_0/Model-Q8_0-00002-of-00002.gguf', 300),
          _lfs('Q8_0/Model-Q8_0-00001-of-00002.gguf', 500),
        ], sha: null),
      ),
    );

    final quant = (await resolve() as RepoResolved).quants.single;

    expect(quant.label, 'Q8_0');
    expect(quant.sizeBytes, 800);
    expect(quant.files.map((file) => file.path), [
      'Q8_0/Model-Q8_0-00001-of-00002.gguf',
      'Q8_0/Model-Q8_0-00002-of-00002.gguf',
    ]);
    expect(quant.files.first.url.path, contains('/resolve/main/'));
  });

  test('drops quants with a missing or unsized file', () async {
    hubAnswers(
      HfRepoResolved(
        _model([
          _lfs('Model-Q8_0-00001-of-00002.gguf', 500),
          const SiblingInfo(relativeFilename: 'Model-Q6_K.gguf'),
          _lfs('Model-Q4_K_M.gguf', 400),
        ]),
      ),
    );

    final resolved = await resolve() as RepoResolved;

    expect(resolved.quants.map((quant) => quant.label), ['Q4_K_M']);
  });

  test('leaves the architecture to the header when the Hub has none', () async {
    hubAnswers(
      HfRepoResolved(
        _model([_lfs('Model-Q4_K_M.gguf', 400)], architecture: null),
      ),
    );

    final resolved = await resolve() as RepoResolved;

    expect(resolved.architecture, isNull);
    expect(resolved.profile, isNull);
    expect(resolved.contextLength, isNull);
    expect(resolved.quants, hasLength(1));
  });

  test('runs repos the Hub files under a text-writing task', () async {
    for (final task in ['text-generation', 'image-text-to-text']) {
      hubAnswers(
        HfRepoResolved(
          _model([_lfs('Model-Q4_K_M.gguf', 400)], pipelineTag: task),
        ),
      );

      expect(await resolve(), isA<RepoResolved>(), reason: task);
    }
  });

  group('says why a repo cannot run', () {
    Future<UnrunnableReason> reasonFor(HfModel model) async {
      hubAnswers(HfRepoResolved(model));
      return (await resolve() as RepoUnrunnable).reason;
    }

    test('no GGUF files', () async {
      final reason = await reasonFor(
        const HfModel(id: 'org/Model-GGUF'),
      );

      expect(reason, isA<NoGgufFiles>());
    });

    test('a task other than chat, whatever the architecture', () async {
      final reason = await reasonFor(
        _model(
          [_lfs('Model-Q4_K_M.gguf', 400)],
          pipelineTag: 'sentence-similarity',
        ),
      );

      expect((reason as NotAChatModel).task, 'sentence-similarity');
    });

    test('an untagged repo named for embeddings', () async {
      final reason = await reasonFor(
        _model(
          [_lfs('Qwen3-Embedding-0.6B-Q8_0.gguf', 400)],
          id: 'Qwen/Qwen3-Embedding-0.6B-GGUF',
        ),
      );

      expect((reason as NotAChatModel).task, 'feature-extraction');
    });

    test('an architecture no profile runs', () async {
      final reason = await reasonFor(
        _model([_lfs('Model-Q4_K_M.gguf', 400)], architecture: 'llama'),
      );

      expect((reason as ArchitectureUnsupported).architecture, 'llama');
    });

    test('a template from another family', () async {
      final reason = await reasonFor(
        _model(
          [_lfs('Model-Q4_K_M.gguf', 400)],
          architecture: 'qwen2',
          chatTemplate: deepSeekTemplate,
        ),
      );

      expect((reason as TemplateUnrecognized).architecture, 'qwen2');
    });

    test('no quant it knows', () async {
      final reason = await reasonFor(
        _model([
          _lfs('Model-NVFP4.gguf', 400),
          _lfs('Model-NVFP4-copy.gguf', 400),
          _lfs('model.gguf', 400),
        ]),
      );

      expect((reason as NoSupportedQuants).labels, ['NVFP4']);
    });
  });

  test('names the repo as the Hub spells it', () async {
    hubAnswers(
      HfRepoResolved(
        _model([_lfs('Model-Q4_K_M.gguf', 400)], id: 'Org/Model-GGUF'),
      ),
    );

    final resolved =
        await resolver.resolve('org/model-gguf', inLibrary: {}) as RepoResolved;

    expect(resolved.repo, 'Org/Model-GGUF');
    final quant = resolved.quants.single;
    expect(quant.repo, 'Org/Model-GGUF');
    expect(quant.downloadId, 'Org/Model-GGUF:Model-Q4_K_M.gguf');
    expect(quant.files.single.url.path, startsWith('/Org/Model-GGUF/'));
  });

  test('finds nothing for a malformed repo id', () async {
    final resolution = await resolver.resolve('not a repo', inLibrary: {});

    expect(resolution, isA<RepoNotFound>());
    expect(resolution.repo, 'not a repo');
    verifyNever(() => hub.getModel(any()));
  });

  test('finds nothing when the Hub does not know the repo', () async {
    hubAnswers(HfRepoNotFound(RepoId.tryParse('org/Model-GGUF')!));

    expect(await resolve(), isA<RepoNotFound>());
  });

  test('says why the Hub could not be asked', () async {
    hubAnswers(const HfRequestFailed(message: 'offline'));

    final failed = await resolve() as RepoLookupFailed;

    expect(failed.message, 'offline');
    expect(failed.repo, 'org/Model-GGUF');
  });
}
