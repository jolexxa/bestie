import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/downloads/download_queue.dart';
import 'package:local_models_repository/src/downloads/download_queue_change.dart';
import 'package:local_models_repository/src/downloads/ledger_writer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:test/test.dart';

import '../support/download_fixtures.dart';

class _MockDownloader extends Mock implements ModelDownloader {}

class _MockLedgerStore extends Mock implements DownloadLedgerStore {}

String _idOf(String name) => 'org/$name:$name-Q4_K_M.gguf';

String _pathOf(String name) => '/models/org/$name/$name-Q4_K_M.gguf';

DownloadRecord _record(
  String name, {
  DownloadRecordStatus status = DownloadRecordStatus.pending,
  String? file,
  String? repo,
}) => downloadRecord(
  id: _idOf(name),
  repo: repo ?? 'org/$name',
  status: status,
  files: [
    DownloadRecordFile(
      path: file ?? '$name-Q4_K_M.gguf',
      url: 'https://huggingface.co/org/$name/resolve/abc/$name-Q4_K_M.gguf',
      bytes: 100,
    ),
  ],
);

void main() {
  late _MockDownloader downloader;
  late _MockLedgerStore ledger;
  late MemoryFileSystem fileSystem;
  late Map<String, ScriptedRun> runs;
  late List<DownloadLedger> written;
  late List<DownloadQueueChange> changes;
  late DownloadQueue queue;

  setUpAll(() {
    registerFallbackValue(const DownloadJob(directory: '', files: []));
    registerFallbackValue(DownloadLedger.empty);
    registerFallbackValue(DateTime(2026));
  });

  DownloadQueue queueOn(FileSystem system) {
    final queue = DownloadQueue(
      modelsDir: '/models',
      downloader: downloader,
      ledger: ledger,
      fileSystem: system,
      clock: Clock.fixed(DateTime.utc(2026, 10, 4)),
    );
    addTearDown(queue.dispose);
    return queue;
  }

  setUp(() {
    downloader = _MockDownloader();
    ledger = _MockLedgerStore();
    fileSystem = MemoryFileSystem.test();
    runs = {};
    written = [];
    when(() => downloader.start(any())).thenAnswer((invocation) {
      final job = invocation.positionalArguments.single as DownloadJob;
      final transfer = ScriptedRun();
      runs[job.files.single.relativePath] = transfer;
      return transfer.run;
    });
    when(() => ledger.lock()).thenAnswer(
      (_) async => const LedgerLockAcquired(),
    );
    when(() => ledger.unlock()).thenAnswer((_) async {});
    when(() => ledger.read()).thenAnswer((_) async => const StoreAbsent());
    when(() => ledger.write(any())).thenAnswer((invocation) async {
      written.add(invocation.positionalArguments.single as DownloadLedger);
      return const StoreWritten();
    });
    queue = queueOn(fileSystem);
    changes = [];
    queue.changes.listen(changes.add);
  });

  ScriptedRun runOf(String name) => runs['$name-Q4_K_M.gguf']!;

  void ledgerHolds(List<DownloadRecord> records) =>
      when(() => ledger.read()).thenAnswer(
        (_) async => StoreLoaded(
          DownloadLedger(
            version: DownloadLedger.currentVersion,
            downloads: records,
          ),
        ),
      );

  Future<Map<String, DownloadRecordStatus>> recorded() async {
    await pumpEventQueue();
    return {
      for (final record in written.last.downloads) record.id: record.status,
    };
  }

  void writeFile(String path, [int bytes = 1]) => fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 0));

  group('restore', () {
    test('picks up the ledger, two transfers at a time', () async {
      ledgerHolds([
        _record('done', status: DownloadRecordStatus.completed),
        _record('paused', status: DownloadRecordStatus.paused),
        _record('first'),
        _record('second'),
        _record('third'),
      ]);

      final result = await queue.restore();

      expect((result as LedgerRestored).dropped, isEmpty);
      expect(queue.status, isA<DownloadsReady>());
      expect(runs.keys, ['first-Q4_K_M.gguf', 'second-Q4_K_M.gguf']);
      expect(queue.downloads.map((download) => download.status.runtimeType), [
        DownloadPausedStatus,
        DownloadTransferringStatus,
        DownloadTransferringStatus,
        DownloadQueuedStatus,
      ]);
      final source = queue.downloadedSources[_pathOf('done')]!;
      expect(queue.downloadedSources, hasLength(1));
      expect(source.downloadId, _idOf('done'));
      expect(source.repo, 'org/done');
      expect(source.revision, 'abc');
      expect(source.file, 'done-Q4_K_M.gguf');
      expect(queue.queuedPaths, {
        _pathOf('paused'),
        _pathOf('first'),
        _pathOf('second'),
        _pathOf('third'),
      });
      expect(changes, contains(isA<DownloadsUpdated>()));
    });

    test('starts empty without a ledger', () async {
      await queue.restore();

      expect(queue.downloads, isEmpty);
      expect(queue.downloadedSources, isEmpty);
      expect(await recorded(), isEmpty);
    });

    test('drops records that would write outside their folder', () async {
      ledgerHolds([
        _record('absolute', file: '/etc/passwd'),
        _record('escape', file: '../../outside.gguf'),
        _record('repo', repo: '../models'),
        downloadRecord(id: 'empty', files: const []),
        _record('fine'),
      ]);

      final result = await queue.restore() as LedgerRestored;

      expect(
        {for (final drop in result.dropped) drop.downloadId: drop.reason},
        {
          _idOf('absolute'): isA<InvalidFilePath>().having(
            (reason) => reason.path,
            'path',
            '/etc/passwd',
          ),
          _idOf('escape'): isA<InvalidFilePath>(),
          _idOf('repo'): isA<InvalidRepoId>().having(
            (reason) => reason.repo,
            'repo',
            '../models',
          ),
          'empty': isA<NoDownloadFiles>(),
        },
      );
      expect(runs.keys, ['fine-Q4_K_M.gguf']);
      expect(await recorded(), {_idOf('fine'): DownloadRecordStatus.pending});
    });

    test('sets a corrupt ledger aside and starts over', () async {
      when(
        () => ledger.read(),
      ).thenAnswer((_) async => const StoreCorrupt('not JSON'));
      when(() => ledger.setAside(any())).thenAnswer(
        (_) async => const StoreSetAside('/models/downloads.json.corrupt-x'),
      );

      final result = await queue.restore();

      expect(
        result,
        isA<LedgerSetAside>()
            .having((result) => result.reason, 'reason', 'not JSON')
            .having(
              (result) => result.movedTo,
              'movedTo',
              '/models/downloads.json.corrupt-x',
            ),
      );
      verify(() => ledger.setAside(DateTime.utc(2026, 10, 4))).called(1);
      expect(
        queue.status,
        isA<DownloadsLedgerSetAside>().having(
          (status) => status.movedTo,
          'movedTo',
          '/models/downloads.json.corrupt-x',
        ),
      );
      expect(queue.status.writable, isTrue);
      expect(await recorded(), isEmpty);
    });

    test('keeps a corrupt ledger it cannot move, writing nothing', () async {
      when(
        () => ledger.read(),
      ).thenAnswer((_) async => const StoreCorrupt('not JSON'));
      when(() => ledger.setAside(any())).thenAnswer(
        (_) async => const StoreSetAsideFailed('busy'),
      );

      final result = await queue.restore();

      expect((result as LedgerUnreadable).reason, 'busy');
      await pumpEventQueue();
      verifyNever(() => ledger.write(any()));
    });

    group('of a ledger it cannot read', () {
      setUp(() {
        when(
          () => ledger.read(),
        ).thenAnswer((_) async => const StoreUnreadable('locked'));
      });

      test('keeps the ledger as it is and downloads nothing', () async {
        final result = await queue.restore();

        expect((result as LedgerUnreadable).reason, 'locked');
        expect(
          queue.status,
          isA<DownloadsLedgerUnreadable>().having(
            (status) => status.reason,
            'reason',
            'locked',
          ),
        );
        expect(queue.enqueue(_record('model')), isA<DownloadsUnavailable>());
        await pumpEventQueue();
        verifyNever(() => ledger.write(any()));
        verifyNever(() => downloader.start(any()));
      });

      test('picks the ledger up once it can be read', () async {
        await queue.restore();
        ledgerHolds([_record('model')]);

        expect(await queue.restore(), isA<LedgerRestored>());

        expect(queue.status, isA<DownloadsReady>());
        expect(runs.keys, ['model-Q4_K_M.gguf']);
      });
    });

    group('while another window holds the lock', () {
      setUp(() {
        when(() => ledger.lock()).thenAnswer(
          (_) async => const LedgerLockHeld(),
        );
        ledgerHolds([
          _record('done', status: DownloadRecordStatus.completed),
          _record('theirs'),
        ]);
      });

      test('only reads what is downloaded, changing nothing', () async {
        writeFile(_pathOf('done'));

        final result = await queue.restore();

        expect(result, isA<LedgerManagedElsewhere>());
        expect(queue.status, isA<DownloadsManagedElsewhere>());
        expect(queue.status.writable, isFalse);
        expect(queue.downloadedSources.keys, [_pathOf('done')]);
        expect(queue.downloads, isEmpty);
        expect(queue.enqueue(_record('mine')), isA<DownloadsUnavailable>());
        expect(
          await queue.deleteCompleted(_idOf('done')),
          isA<DeleteRefusedReadOnly>(),
        );
        expect(fileSystem.file(_pathOf('done')).existsSync(), isTrue);
        await pumpEventQueue();
        verifyNever(() => ledger.write(any()));
        verifyNever(() => downloader.start(any()));
      });

      test('reads nothing from a ledger it cannot read', () async {
        when(
          () => ledger.read(),
        ).thenAnswer((_) async => const StoreUnreadable('locked'));

        await queue.restore();

        expect(queue.downloadedSources, isEmpty);
      });

      test('takes over once the lock is free', () async {
        await queue.restore();
        when(() => ledger.lock()).thenAnswer(
          (_) async => const LedgerLockAcquired(),
        );

        await queue.restore();

        expect(queue.status, isA<DownloadsReady>());
        expect(runs.keys, ['theirs-Q4_K_M.gguf']);
      });
    });

    test('runs downloads when the lock file cannot be opened', () async {
      when(() => ledger.lock()).thenAnswer(
        (_) async => const LedgerLockFailed('read-only folder'),
      );

      await queue.restore();

      expect(queue.status, isA<DownloadsReady>());
    });
  });

  group('enqueue', () {
    test('refuses before the ledger is read', () {
      expect(queue.enqueue(_record('model')), isA<DownloadsUnavailable>());
      expect(queue.status, isA<DownloadsStarting>());
      expect(queue.status.writable, isFalse);
    });

    group('once restored', () {
      setUp(() => queue.restore());

      test('starts what it queues and records it', () async {
        final result = queue.enqueue(_record('model'));

        expect(result, isA<DownloadAccepted>());
        expect(result.downloadId, _idOf('model'));
        final job =
            verify(() => downloader.start(captureAny())).captured.single
                as DownloadJob;
        expect(job.directory, '/models/org/model');
        expect(queue.knownIds, {_idOf('model')});
        expect(await recorded(), {
          _idOf('model'): DownloadRecordStatus.pending,
        });
      });

      test('takes a download once, however quickly it is asked twice', () {
        final first = queue.enqueue(_record('model'));
        final second = queue.enqueue(_record('model'));

        expect(first, isA<DownloadAccepted>());
        expect(second, isA<DownloadAlreadyQueued>());
        expect(queue.downloads, hasLength(1));
        verify(() => downloader.start(any())).called(1);
      });

      test('refuses to replace a file it did not download', () async {
        writeFile(_pathOf('model'), 7);

        final result = queue.enqueue(_record('model'));

        expect(
          (result as DownloadTargetOccupied).path,
          _pathOf('model'),
        );
        expect(fileSystem.file(_pathOf('model')).lengthSync(), 7);
        expect(queue.downloads, isEmpty);
        verifyNever(() => downloader.start(any()));
      });

      test('rejects a file that would land outside its folder', () {
        final result = queue.enqueue(
          _record('model', file: '../../../etc/passwd'),
        );

        expect(
          (result as DownloadRejected).reason,
          isA<InvalidFilePath>(),
        );
        verifyNever(() => downloader.start(any()));
      });
    });

    group('of a completed download', () {
      setUp(() async {
        ledgerHolds([
          _record('model', status: DownloadRecordStatus.completed),
        ]);
        await queue.restore();
      });

      test('is refused while its model is on disk', () {
        writeFile(_pathOf('model'));

        expect(
          queue.enqueue(_record('model')),
          isA<DownloadAlreadyQueued>(),
        );
        expect(queue.knownIds, {_idOf('model')});
      });

      test('downloads it again once its model is gone', () {
        expect(queue.knownIds, isEmpty);

        expect(queue.enqueue(_record('model')), isA<DownloadAccepted>());

        expect(queue.downloadedSources, isEmpty);
        expect(
          queue.downloads.single.status,
          isA<DownloadTransferringStatus>(),
        );
      });
    });
  });

  group('once restored', () {
    setUp(() => queue.restore());

    test('starts the next download when one finishes', () async {
      queue
        ..enqueue(_record('first'))
        ..enqueue(_record('second'))
        ..enqueue(_record('third'));
      expect(runs, hasLength(2));

      await runOf('first').settle(const DownloadCompleted());
      await pumpEventQueue();

      expect(runs, hasLength(3));
      expect(
        changes.whereType<DownloadFinished>().single.downloadId,
        _idOf('first'),
      );
      expect(
        (await recorded())[_idOf('first')],
        DownloadRecordStatus.completed,
      );
    });

    test('tells listeners about every bit of progress', () async {
      queue.enqueue(_record('model'));
      await pumpEventQueue();
      changes.clear();

      runOf('model')
        ..advance(10)
        ..advance(20);
      await pumpEventQueue();

      expect(changes, [const DownloadsUpdated(), const DownloadsUpdated()]);
      expect(
        (queue.downloads.single.status as DownloadTransferringStatus)
            .receivedBytes,
        20,
      );
    });

    group('reconcile', () {
      setUp(() async {
        queue.enqueue(_record('model'));
        await runOf('model').settle(const DownloadCompleted());
        await pumpEventQueue();
        changes.clear();
      });

      test('retires a finished download once a scan lists it', () async {
        queue.reconcile({_pathOf('model')});

        expect(queue.downloads, isEmpty);
        expect(queue.queuedPaths, isEmpty);
        expect(queue.downloadedSources.keys, [_pathOf('model')]);
        expect(changes, [const DownloadsUpdated()]);
        expect(
          await recorded(),
          {_idOf('model'): DownloadRecordStatus.completed},
        );
      });

      test('keeps it, unlisted, when a scan misses it', () {
        queue.reconcile({'/models/other.gguf'});

        expect(
          (queue.downloads.single.status as DownloadUnlistedStatus).reason,
          isA<UnlistedFileMissing>(),
        );
        expect(queue.downloadedSources, isEmpty);
      });

      test('keeps it, unlisted, when the scan fails', () {
        queue.scanFailed('disk gone');

        expect(
          (queue.downloads.single.status as DownloadUnlistedStatus).reason,
          isA<UnlistedScanFailed>().having(
            (reason) => reason.error,
            'error',
            'disk gone',
          ),
        );
      });

      test('leaves downloads that have not finished alone', () {
        queue
          ..enqueue(_record('other'))
          ..reconcile({})
          ..scanFailed('disk gone');

        expect(
          queue.downloads.last.status,
          isA<DownloadTransferringStatus>(),
        );
      });
    });

    group('cancel', () {
      test('pauses a transfer, keeping its place on disk', () async {
        queue.enqueue(_record('model'));

        expect(queue.cancel(_idOf('model')), const CancelRequested());
        expect(runOf('model').cancelRequested.isCompleted, isTrue);

        await runOf('model').settle(const DownloadCancelled());
        await pumpEventQueue();

        expect(queue.downloads.single.status, isA<DownloadPausedStatus>());
        expect(
          (await recorded())[_idOf('model')],
          DownloadRecordStatus.paused,
        );
      });

      test('pauses a download still waiting for a slot', () async {
        queue
          ..enqueue(_record('first'))
          ..enqueue(_record('second'))
          ..enqueue(_record('waiting'));

        expect(queue.cancel(_idOf('waiting')), const CancelRequested());
        await pumpEventQueue();

        expect(
          queue.downloads.last.status,
          isA<DownloadPausedStatus>(),
        );
        expect(runs.keys, isNot(contains('waiting-Q4_K_M.gguf')));
      });

      test('has nothing to stop otherwise', () async {
        queue
          ..enqueue(_record('model'))
          ..cancel(_idOf('model'));
        await runOf('model').settle(const DownloadCancelled());
        await pumpEventQueue();

        expect(queue.cancel(_idOf('model')), const NothingToCancel());
        expect(queue.cancel(_idOf('unknown')), const NothingToCancel());
      });
    });

    group('resume', () {
      test('queues a stopped download and starts it', () async {
        queue
          ..enqueue(_record('model'))
          ..cancel(_idOf('model'));
        await runOf('model').settle(const DownloadCancelled());
        await pumpEventQueue();

        expect(queue.resume(_idOf('model')), const ResumeQueued());

        expect(
          queue.downloads.single.status,
          isA<DownloadTransferringStatus>(),
        );
        verify(() => downloader.start(any())).called(2);
      });

      test('has nothing to resume otherwise', () {
        queue.enqueue(_record('model'));

        expect(queue.resume(_idOf('model')), const NothingToResume());
        expect(queue.resume(_idOf('unknown')), const NothingToResume());
      });
    });

    group('discard', () {
      test('stops a transfer, clears what it left and its folders', () async {
        writeFile('/models/org/keep.gguf');
        queue.enqueue(_record('model'));
        runOf('model').cancelsWhenAsked();
        writeFile('${_pathOf('model')}.part', 30);
        writeFile('${_pathOf('model')}.part.meta', 2);

        final result = await queue.discard(_idOf('model'));

        expect((result as DownloadDiscarded).freedBytes, 32);
        expect(fileSystem.directory('/models/org/model').existsSync(), isFalse);
        expect(fileSystem.file('/models/org/keep.gguf').existsSync(), isTrue);
        expect(queue.downloads, isEmpty);
        expect(await recorded(), isEmpty);
      });

      test('has nothing to discard for an unknown download', () async {
        expect(
          await queue.discard(_idOf('unknown')),
          isA<NothingToDiscard>(),
        );
      });
    });

    group('deleteCompleted', () {
      setUp(() async {
        ledgerHolds([
          _record('model', status: DownloadRecordStatus.completed),
        ]);
        await queue.restore();
      });

      test('removes the model and every folder it leaves empty', () async {
        writeFile(_pathOf('model'), 100);

        final result = await queue.deleteCompleted(_idOf('model'));

        expect((result as ModelDeleted).freedBytes, 100);
        expect(fileSystem.directory('/models/org').existsSync(), isFalse);
        expect(fileSystem.directory('/models').existsSync(), isTrue);
        expect(queue.downloadedSources, isEmpty);
        expect(await recorded(), isEmpty);
      });

      test('has nothing to delete for an unknown download', () async {
        expect(
          await queue.deleteCompleted(_idOf('unknown')),
          isA<NothingToDelete>(),
        );
      });
    });
  });

  group('when files cannot be deleted', () {
    late DownloadQueue locked;
    late MemoryFileSystem lockedSystem;

    setUp(() async {
      lockedSystem = MemoryFileSystem.test(
        opHandle: (path, operation) {
          if (operation == FileSystemOp.delete) {
            throw FileSystemException('Permission denied', path);
          }
        },
      );
      ledgerHolds([_record('done', status: DownloadRecordStatus.completed)]);
      locked = queueOn(lockedSystem);
      await locked.restore();
      lockedSystem.file(_pathOf('done'))
        ..createSync(recursive: true)
        ..writeAsStringSync('gguf');
      await pumpEventQueue();
      written.clear();
    });

    test('keeps a model whose file stayed, saying why', () async {
      final result = await locked.deleteCompleted(_idOf('done'));

      expect(
        result,
        isA<DeleteFailed>()
            .having((result) => result.path, 'path', _pathOf('done'))
            .having((result) => result.error, 'error', 'Permission denied'),
      );
      expect(locked.downloadedSources.keys, [_pathOf('done')]);
      await pumpEventQueue();
      expect(written, isEmpty);
    });

    test('keeps a download whose files stayed, stopped', () async {
      locked.enqueue(_record('model'));
      runOf('model').cancelsWhenAsked();
      lockedSystem.file('${_pathOf('model')}.part')
        ..createSync(recursive: true)
        ..writeAsStringSync('part');

      final result = await locked.discard(_idOf('model'));

      expect((result as DiscardFailed).path, '${_pathOf('model')}.part');
      expect(locked.downloads.single.status, isA<DownloadPausedStatus>());
      expect(
        (await recorded())[_idOf('model')],
        DownloadRecordStatus.paused,
      );
    });
  });

  group('saving the ledger', () {
    test('writes once for changes made together', () async {
      await queue.restore();
      await pumpEventQueue();
      written.clear();

      queue
        ..enqueue(_record('first'))
        ..enqueue(_record('second'))
        ..enqueue(_record('third'));
      await pumpEventQueue();

      expect(written, hasLength(1));
      expect(written.single.downloads, hasLength(3));
    });

    test('says when it cannot save, and retries until it can', () {
      fakeAsync((async) {
        when(
          () => ledger.write(any()),
        ).thenAnswer((_) async => const StoreWriteFailed('disk full'));
        final retrying = DownloadQueue(
          modelsDir: '/models',
          downloader: downloader,
          ledger: ledger,
          fileSystem: fileSystem,
          clock: const Clock(),
          writer: LedgerWriter(ledger),
        );
        unawaited(retrying.restore());
        async.flushMicrotasks();

        expect(
          retrying.status,
          isA<DownloadsLedgerNotSaved>().having(
            (status) => status.reason,
            'reason',
            'disk full',
          ),
        );
        expect(retrying.status.writable, isTrue);
        verify(() => ledger.write(any())).called(1);

        when(() => ledger.write(any())).thenAnswer((invocation) async {
          written.add(invocation.positionalArguments.single as DownloadLedger);
          return const StoreWritten();
        });
        async.elapse(const Duration(seconds: 5));

        expect(written, hasLength(1));
        expect(retrying.status, isA<DownloadsReady>());
        unawaited(retrying.dispose());
        async.flushMicrotasks();
      });
    });

    test('keeps the set-aside notice through later saves', () async {
      when(
        () => ledger.read(),
      ).thenAnswer((_) async => const StoreCorrupt('not JSON'));
      when(() => ledger.setAside(any())).thenAnswer(
        (_) async => const StoreSetAside('/moved'),
      );
      await queue.restore();

      queue.enqueue(_record('model'));
      await pumpEventQueue();

      expect(queue.status, isA<DownloadsLedgerSetAside>());
    });
  });

  test('stops every transfer on dispose without recording it', () async {
    await queue.restore();
    queue
      ..enqueue(_record('first'))
      ..enqueue(_record('second'));
    await pumpEventQueue();
    final writes = written.length;

    await queue.dispose();

    expect(runOf('first').cancelRequested.isCompleted, isTrue);
    expect(runOf('second').cancelRequested.isCompleted, isTrue);
    expect(queue.downloads, isEmpty);
    expect(written, hasLength(writes));
    verify(() => ledger.unlock()).called(1);
  });
}
