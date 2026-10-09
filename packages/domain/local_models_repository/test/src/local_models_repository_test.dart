import 'package:clock/clock.dart';
import 'package:file/memory.dart';
import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:test/test.dart';

import 'support/download_fixtures.dart';
import 'support/fixtures.dart';

class _MockHub extends Mock implements HubClient {}

class _MockDownloader extends Mock implements ModelDownloader {}

class _MockIndexStore extends Mock implements ModelIndexStore {}

class _MockLedgerStore extends Mock implements DownloadLedgerStore {}

const _doneId = 'org/Done-GGUF:Done-Q4_K_M.gguf';
const _donePath = '/models/org/Done-GGUF/Done-Q4_K_M.gguf';
const _newId = 'org/New-GGUF:New-Q4_K_M.gguf';
const _newPath = '/models/org/New-GGUF/New-Q4_K_M.gguf';

/// Makes the next scan throw while `/boom` exists.
const _boom = '/boom';

/// A file system whose scans throw while [_boom] exists.
MemoryFileSystem _failingScansWhileBoom() {
  late final MemoryFileSystem system;
  return system = MemoryFileSystem.test(
    opHandle: (path, operation) {
      if (operation == FileSystemOp.exists &&
          path.endsWith('Beta-Q4_K_M.gguf') &&
          system.file(_boom).existsSync()) {
        throw StateError('disk gone');
      }
    },
  );
}

void main() {
  late _MockHub hub;
  late _MockDownloader downloader;
  late _MockIndexStore indexStore;
  late _MockLedgerStore ledgerStore;
  late MemoryFileSystem fileSystem;
  late List<ScriptedRun> runs;
  late List<ModelIndex> indexes;
  late LocalModelsRepository repository;

  setUpAll(() {
    registerFallbackValue(const DownloadJob(directory: '', files: []));
    registerFallbackValue(DownloadLedger.empty);
    registerFallbackValue(const ModelIndex(version: 1, models: []));
    registerFallbackValue(RepoId.tryParse('a/b'));
  });

  setUp(() {
    hub = _MockHub();
    downloader = _MockDownloader();
    indexStore = _MockIndexStore();
    ledgerStore = _MockLedgerStore();
    fileSystem = _failingScansWhileBoom();
    runs = [];
    indexes = [];
    when(() => downloader.start(any())).thenAnswer((_) {
      final transfer = ScriptedRun();
      runs.add(transfer);
      return transfer.run;
    });
    when(() => indexStore.write(any())).thenAnswer((invocation) async {
      indexes.add(invocation.positionalArguments.single as ModelIndex);
      return const StoreWritten();
    });
    when(() => ledgerStore.lock()).thenAnswer(
      (_) async => const LedgerLockAcquired(),
    );
    when(() => ledgerStore.unlock()).thenAnswer((_) async {});
    when(() => ledgerStore.write(any())).thenAnswer(
      (_) async => const StoreWritten(),
    );
    when(() => ledgerStore.read()).thenAnswer(
      (_) async => StoreLoaded(
        DownloadLedger(
          version: DownloadLedger.currentVersion,
          downloads: [
            downloadRecord(
              id: _doneId,
              repo: 'org/Done-GGUF',
              status: DownloadRecordStatus.completed,
              files: const [
                DownloadRecordFile(
                  path: 'Done-Q4_K_M.gguf',
                  url: 'https://hf.test/Done-Q4_K_M.gguf',
                  bytes: 100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    when(
      () => hub.resolveFileUrl(any(), any(), revision: any(named: 'revision')),
    ).thenAnswer(
      (invocation) => Uri.parse(
        'https://hf.test/${invocation.positionalArguments[1] as String}',
      ),
    );
    when(() => hub.getModel(any())).thenAnswer(
      (_) async => const HfRepoResolved(
        HfModel(
          id: 'org/New-GGUF',
          sha: 'abc',
          siblings: [
            SiblingInfo(
              relativeFilename: 'New-Q4_K_M.gguf',
              lfs: LfsInfo(sha256: 'feed', size: 100),
            ),
          ],
        ),
      ),
    );

    writeGguf(fileSystem, _donePath, name: 'Done');
    writeGguf(fileSystem, '/models/Loose-Q4_K_M.gguf', name: 'Loose');
    writeGguf(fileSystem, '/mine/b/Beta-Q4_K_M.gguf', name: 'Beta');
    writeGguf(fileSystem, '/mine/a/Alpha-Q4_K_M.gguf', name: 'alpha');
    writeGguf(
      fileSystem,
      '/mine/Aardvark-Q4_K_M.gguf',
      name: 'Aardvark',
      architecture: 'granitehybrid',
    );

    repository = LocalModelsRepository(
      modelsDir: '/models/',
      folders: ['/mine/./'],
      hub: hub,
      downloader: downloader,
      indexStore: indexStore,
      ledgerStore: ledgerStore,
      fileSystem: fileSystem,
      clock: Clock.fixed(DateTime(2026, 10, 4)),
    );
  });

  tearDown(() => repository.dispose());

  List<String> names(Iterable<LocalModel> models) => [
    for (final model in models) model.displayName,
  ];

  LocalModel modelNamed(String name) => repository.current.models.singleWhere(
    (model) => model.displayName == name,
  );

  Future<RepoQuant> newQuant() async =>
      (await repository.resolveRepo('org/New-GGUF') as RepoResolved)
          .quants
          .single;

  Future<void> settle() async {
    await pumpEventQueue();
    await repository.rescan();
  }

  group('searchRepos', () {
    test('asks the Hub for GGUF repos, twenty at a time', () async {
      when(
        () => hub.searchModels(
          search: any(named: 'search'),
          filter: any(named: 'filter'),
          sort: any(named: 'sort'),
          direction: any(named: 'direction'),
          limit: any(named: 'limit'),
          expand: any(named: 'expand'),
        ),
      ).thenAnswer(
        (_) async => const HfSearchSucceeded(
          PaginatedResponse(items: [HfModel(id: 'org/Found-GGUF')]),
        ),
      );

      final result = await repository.searchRepos('found');

      expect(
        (result as RepoSearchSucceeded).repos.single.repo,
        'org/Found-GGUF',
      );
      verify(
        () => hub.searchModels(
          search: 'found',
          filter: 'gguf',
          sort: 'downloads',
          direction: SortDirection.descending,
          limit: 20,
          expand: any(named: 'expand'),
        ),
      ).called(1);
    });
  });

  group('start', () {
    test('opens loading rather than empty', () {
      expect(repository.current.status, isA<LibraryLoading>());
      expect(repository.current.downloadsStatus, isA<DownloadsStarting>());
    });

    test('lists downloaded models apart from those found', () async {
      expect(await repository.start(), isA<LedgerRestored>());

      final library = repository.current;
      expect(library.status, isA<LibraryReady>());
      expect(library.downloadsStatus, isA<DownloadsReady>());
      expect(names(library.downloaded), ['Done']);
      expect(names(library.inFolders), ['alpha', 'Beta', 'Loose', 'Aardvark']);
      expect(library.scanning, isFalse);
      final done = library.downloaded.single.source as DownloadedSource;
      expect(done.downloadId, _doneId);
      expect(done.repo, 'org/Done-GGUF');
      expect((modelNamed('Beta').source as ScannedSource).root, '/mine');
    });

    test('marks what sits in the models folder unasked as untracked', () async {
      await repository.start();

      expect(
        (modelNamed('Loose').source as UntrackedSource).root,
        '/models',
      );
    });

    test('shows the scan while it runs', () async {
      final scanning = <bool>[];
      repository.library.listen((library) => scanning.add(library.scanning));

      await repository.start();
      await pumpEventQueue();

      expect(scanning, containsAllInOrder([false, true, false]));
    });

    test('indexes every runnable model', () async {
      await repository.start();

      final index = indexes.single;
      expect(index.version, ModelIndex.currentVersion);
      expect(
        index.models.map((entry) => entry.displayName),
        ['Done', 'alpha', 'Beta', 'Loose'],
      );
    });

    test('lists one copy of a file found twice, the download first', () async {
      fileSystem.directory('/mine/c').createSync();
      fileSystem.directory('/mine/z').createSync();
      fileSystem.file(_donePath).copySync('/mine/c/Done-Q4_K_M.gguf');
      fileSystem
          .file('/mine/b/Beta-Q4_K_M.gguf')
          .copySync(
            '/mine/z/Beta-Q4_K_M.gguf',
          );

      await repository.start();

      expect(names(repository.current.downloaded), ['Done']);
      expect(names(repository.current.inFolders), [
        'alpha',
        'Beta',
        'Loose',
        'Aardvark',
      ]);
      expect(
        modelNamed('Beta').path,
        '/mine/b/Beta-Q4_K_M.gguf',
      );
    });

    test('says why a scan failed, keeping what it had', () async {
      await repository.start();
      fileSystem.file(_boom).createSync();

      await repository.rescan();

      final library = repository.current;
      expect(
        (library.status as LibraryScanFailed).error,
        contains('disk gone'),
      );
      expect(names(library.downloaded), ['Done']);

      fileSystem.file(_boom).deleteSync();
      await repository.rescan();

      expect(repository.current.status, isA<LibraryReady>());
    });

    test('says when the ledger could not be read', () async {
      when(
        () => ledgerStore.read(),
      ).thenAnswer((_) async => const StoreUnreadable('locked'));

      expect(await repository.start(), isA<LedgerUnreadable>());

      expect(
        repository.current.downloadsStatus,
        isA<DownloadsLedgerUnreadable>(),
      );
      expect(
        (modelNamed('Done').source as UntrackedSource).root,
        '/models',
      );
    });
  });

  group('index', () {
    test('is not written before the first scan lands', () async {
      repository.setReasoningOverrides(const {});
      await pumpEventQueue();

      verifyNever(() => indexStore.write(any()));
    });

    test('is written only when it changes', () async {
      await repository.start();
      await repository.rescan();

      expect(indexes, hasLength(1));
    });

    test('is written again after a failed write', () async {
      when(() => indexStore.write(any())).thenAnswer(
        (_) async => const StoreWriteFailed('disk full'),
      );
      await repository.start();
      when(() => indexStore.write(any())).thenAnswer((invocation) async {
        indexes.add(invocation.positionalArguments.single as ModelIndex);
        return const StoreWritten();
      });

      await repository.rescan();

      expect(indexes, hasLength(1));
    });
  });

  test('applies the reasoning the user chose', () async {
    await repository.start();
    final beta = modelNamed('Beta') as SupportedModel;

    repository.setReasoningOverrides({beta.id: const ModelReasoningNone()});
    await repository.rescan();

    final overridden = modelNamed('Beta') as SupportedModel;
    expect(overridden.reasoning, const ModelReasoningNone());
    expect(overridden.detectedReasoning, const ModelReasoningToggle());
    expect(
      indexes.last.models
          .singleWhere((entry) => entry.localId == beta.id)
          .reasoning,
      const ModelReasoningNone(),
    );
  });

  test('scans the folders it is given', () async {
    await repository.start();
    writeGguf(fileSystem, '/other/Gamma-Q4_K_M.gguf', name: 'Gamma');

    await repository.setFolders(['/other']);

    expect(names(repository.current.inFolders), ['Gamma', 'Loose']);
  });

  group('deleteModel', () {
    test('refuses a model found in a folder', () async {
      await repository.start();

      final result = await repository.deleteModel(modelNamed('Beta').id);

      expect((result as DeleteRefusedScanned).root, '/mine');
      expect(fileSystem.file('/mine/b/Beta-Q4_K_M.gguf').existsSync(), isTrue);
    });

    test('refuses a file bestie did not download', () async {
      await repository.start();

      final result = await repository.deleteModel(modelNamed('Loose').id);

      expect(
        (result as DeleteRefusedUntracked).path,
        '/models/Loose-Q4_K_M.gguf',
      );
      expect(fileSystem.file('/models/Loose-Q4_K_M.gguf').existsSync(), isTrue);
    });

    test('removes a downloaded model and its index entry', () async {
      await repository.start();

      final result = await repository.deleteModel(modelNamed('Done').id);

      expect(result, isA<ModelDeleted>());
      expect(fileSystem.file(_donePath).existsSync(), isFalse);
      expect(repository.current.downloaded, isEmpty);
      await settle();
      expect(repository.current.downloaded, isEmpty);
      expect(
        indexes.last.models.map((entry) => entry.displayName),
        isNot(contains('Done')),
      );
    });

    test('is never undone by a scan that started before it', () async {
      await repository.start();
      final doneId = modelNamed('Done').id;
      final rescanning = repository.rescan();
      final seen = <List<String>>[];

      await repository.deleteModel(doneId);
      final listening = repository.library.listen(
        (library) => seen.add(names(library.models)),
      );
      await rescanning;
      await settle();
      await listening.cancel();

      expect(seen, isNotEmpty);
      expect(seen, everyElement(isNot(contains('Done'))));
    });

    test('refuses while another window runs downloads', () async {
      when(() => ledgerStore.lock()).thenAnswer(
        (_) async => const LedgerLockHeld(),
      );
      await repository.start();

      final result = await repository.deleteModel(modelNamed('Done').id);

      expect(result, isA<DeleteRefusedReadOnly>());
      expect(names(repository.current.downloaded), ['Done']);
    });

    test('has nothing to delete for an unknown id', () async {
      await repository.start();

      expect(await repository.deleteModel('nope'), isA<NothingToDelete>());
    });
  });

  group('downloads', () {
    test('resolves a repo, noting what is already in the library', () async {
      await repository.start();

      final quant = await newQuant();

      expect(quant.inLibrary, isFalse);
      expect(
        quant.files.single.url,
        Uri.parse('https://hf.test/New-Q4_K_M.gguf'),
      );
    });

    test('queues a quant once, however quickly it is asked twice', () async {
      await repository.start();
      final quant = await newQuant();

      final first = repository.download(quant);
      final second = repository.download(quant);

      expect(await first, isA<DownloadAccepted>());
      expect(await second, isA<DownloadAlreadyQueued>());
      expect(runs, hasLength(1));
      expect(repository.current.downloading.single.id, _newId);
      expect((await newQuant()).inLibrary, isTrue);
      final job =
          verify(() => downloader.start(captureAny())).captured.single
              as DownloadJob;
      expect(job.directory, '/models/org/New-GGUF');
      expect(job.files.single.sha256, 'feed');
    });

    test("hides a download's files until it lands", () async {
      await repository.start();
      await repository.download(await newQuant());
      writeGguf(fileSystem, _newPath, name: 'New');

      await repository.rescan();

      expect(names(repository.current.models), isNot(contains('New')));
    });

    test('never replaces a file it did not download', () async {
      writeGguf(fileSystem, _newPath, name: 'Mine');
      await repository.start();

      final result = await repository.download(await newQuant());

      expect((result as DownloadTargetOccupied).path, _newPath);
      expect(runs, isEmpty);
      expect(
        (modelNamed('Mine').source as UntrackedSource).root,
        '/models',
      );
    });

    test('lists a finished download once a scan finds it', () async {
      await repository.start();
      final quant = await newQuant();
      await repository.download(quant);
      writeGguf(fileSystem, _newPath, name: 'New');

      await runs.single.settle(const DownloadCompleted());
      await repository.library.firstWhere(
        (library) => library.downloading.isEmpty,
      );

      final source = modelNamed('New').source as DownloadedSource;
      expect(source.downloadId, _newId);
      expect(names(repository.current.downloaded), ['Done', 'New']);
      expect(await repository.download(quant), isA<DownloadAlreadyQueued>());
    });

    test('keeps a finished download whose model a scan missed', () async {
      await repository.start();
      await repository.download(await newQuant());

      await runs.single.settle(const DownloadCompleted());
      await settle();

      final download = repository.current.needsAttention.single;
      expect(download.id, _newId);
      expect(
        (download.status as DownloadUnlistedStatus).reason,
        isA<UnlistedFileMissing>(),
      );
    });

    test('pauses, resumes and lists stopped downloads apart', () async {
      await repository.start();
      await repository.download(await newQuant());

      expect(repository.cancel(_newId), isA<CancelRequested>());
      await runs.single.settle(const DownloadCancelled());
      await pumpEventQueue();

      expect(repository.current.downloading, isEmpty);
      expect(
        repository.current.needsAttention.single.status,
        isA<DownloadPausedStatus>(),
      );

      expect(repository.resume(_newId), isA<ResumeQueued>());
      await pumpEventQueue();

      expect(repository.current.needsAttention, isEmpty);
      expect(runs, hasLength(2));
    });

    test('discards an unfinished download', () async {
      await repository.start();
      await repository.download(await newQuant());
      runs.single.cancelsWhenAsked();

      final result = await repository.discardDownload(_newId);

      expect(result, isA<DownloadDiscarded>());
      expect(repository.current.downloading, isEmpty);
    });

    group('while another window runs them', () {
      setUp(() {
        when(() => ledgerStore.lock()).thenAnswer(
          (_) async => const LedgerLockHeld(),
        );
      });

      test('shows the library without changing it', () async {
        expect(await repository.start(), isA<LedgerManagedElsewhere>());

        expect(
          repository.current.downloadsStatus,
          isA<DownloadsManagedElsewhere>(),
        );
        expect(names(repository.current.downloaded), ['Done']);
        expect(
          await repository.download(await newQuant()),
          isA<DownloadsUnavailable>(),
        );
        verifyNever(() => ledgerStore.write(any()));
      });

      test('takes over once that window lets go', () async {
        await repository.start();
        when(() => ledgerStore.lock()).thenAnswer(
          (_) async => const LedgerLockAcquired(),
        );

        await repository.rescan();

        expect(repository.current.downloadsStatus, isA<DownloadsReady>());
      });

      test('takes over on a download once that window lets go', () async {
        await repository.start();
        when(() => ledgerStore.lock()).thenAnswer(
          (_) async => const LedgerLockAcquired(),
        );

        final result = await repository.download(await newQuant());

        expect(result, isA<DownloadAccepted>());
        expect(repository.current.downloadsStatus, isA<DownloadsReady>());
        expect(runs, hasLength(1));
      });
    });
  });

  test('closes the library on dispose', () async {
    await repository.start();
    final done = expectLater(repository.library, emitsThrough(emitsDone));

    await repository.dispose();

    await done;
  });
}
