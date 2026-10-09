import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/downloads/download_data.dart';
import 'package:local_models_repository/src/downloads/download_input.dart';
import 'package:local_models_repository/src/downloads/download_logic.dart';
import 'package:local_models_repository/src/downloads/download_output.dart';
import 'package:local_models_repository/src/downloads/download_plan.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/download_fixtures.dart';

class _MockDownloader extends Mock implements ModelDownloader {}

void main() {
  late _MockDownloader downloader;
  late ScriptedRun transfer;
  late List<DownloadJob> jobs;

  setUpAll(() {
    registerFallbackValue(const DownloadJob(directory: '', files: []));
  });

  setUp(() {
    downloader = _MockDownloader();
    transfer = ScriptedRun();
    jobs = [];
    when(() => downloader.start(any())).thenAnswer((invocation) {
      jobs.add(invocation.positionalArguments.single as DownloadJob);
      return transfer.run;
    });
  });

  DownloadLogic logicFor(DownloadRecord record) {
    final plan =
        (DownloadPlan.of(record, modelsDir: '/models', paths: p.posix)
                as DownloadPlanned)
            .plan;
    final logic = DownloadLogic(
      data: DownloadData(plan),
      downloader: downloader,
    )..start();
    addTearDown(logic.dispose);
    return logic;
  }

  DownloadLogic started() =>
      logicFor(downloadRecord())..input(const StartDownload());

  ModelDownloadStatus statusOf(DownloadLogic logic) =>
      logic.value.snapshot.status;

  group('picks up where the ledger left it', () {
    test('queued, keeping the bytes an earlier run left', () {
      final record = downloadRecord(receivedBytes: 41);
      final logic = logicFor(record);

      expect(
        statusOf(logic),
        isA<DownloadQueuedStatus>().having(
          (status) => status.receivedBytes,
          'receivedBytes',
          41,
        ),
      );
      expect(logic.value.record, record);
      verifyNever(() => downloader.start(any()));
    });

    test('paused, with what it had', () {
      final logic = logicFor(
        downloadRecord(status: DownloadRecordStatus.paused, receivedBytes: 40),
      );

      expect((statusOf(logic) as DownloadPausedStatus).receivedBytes, 40);
      expect(logic.value.record.status, DownloadRecordStatus.paused);
      expect(logic.value.record.receivedBytes, 40);
    });

    test('failed, with what the ledger said about why', () {
      final logic = logicFor(
        downloadRecord(
          status: DownloadRecordStatus.failed,
          receivedBytes: 10,
          failure: 'connection reset',
        ),
      );

      final status = statusOf(logic) as DownloadFailedStatus;
      expect(
        status.reason,
        isA<DownloadFailedEarlier>().having(
          (reason) => reason.detail,
          'detail',
          'connection reset',
        ),
      );
      expect(status.receivedBytes, 10);
      expect(logic.value.record.failure, 'connection reset');
    });

    test('failed, even when the ledger never said why', () {
      final logic = logicFor(
        downloadRecord(status: DownloadRecordStatus.failed),
      );

      expect(
        (statusOf(logic) as DownloadFailedStatus).reason.detail,
        isEmpty,
      );
    });

    test('installed', () {
      final logic = logicFor(
        downloadRecord(status: DownloadRecordStatus.completed),
      );

      expect(statusOf(logic), isA<DownloadInstalledStatus>());
      expect(logic.value.record.status, DownloadRecordStatus.completed);
    });
  });

  test('describes itself for the library', () {
    final snapshot = logicFor(downloadRecord()).value.snapshot;

    expect(snapshot.id, downloadId);
    expect(snapshot.repo, 'org/model-GGUF');
    expect(snapshot.quant, 'Q4_K_M');
    expect(snapshot.totalBytes, 100);
  });

  test('transfers every file into the repo folder once started', () {
    final logic = started();

    expect(statusOf(logic), isA<DownloadTransferringStatus>());
    expect(logic.value.record.status, DownloadRecordStatus.pending);
    final job = jobs.single;
    expect(job.directory, '/models/org/model-GGUF');
    final file = job.files.single;
    expect(file.relativePath, 'model-Q4_K_M.gguf');
    expect(file.url, endsWith('/model-Q4_K_M.gguf'));
    expect(file.bytes, 100);
    expect(file.sha256, 'feed');
  });

  test('reports every bit of progress with bytes and speed', () async {
    final logic = started();
    var updates = 0;
    logic.bind().onOutput<DownloadUpdated>((_) => updates++);

    transfer.advance(10, speed: 5);
    await pumpEventQueue();
    transfer.advance(20, speed: 6);
    await pumpEventQueue();

    expect(updates, 2);
    final status = statusOf(logic) as DownloadTransferringStatus;
    expect(status.receivedBytes, 20);
    expect(status.speedBytesPerSecond, 6);
  });

  test('keeps following progress across verifying and the next file', () async {
    final logic = started();

    transfer.advance(50, phase: DownloadPhase.verifying);
    await pumpEventQueue();
    expect(
      (statusOf(logic) as DownloadVerifyingStatus).receivedBytes,
      50,
    );

    transfer.advance(50, phase: DownloadPhase.verifying);
    await pumpEventQueue();
    expect(statusOf(logic), isA<DownloadVerifyingStatus>());

    transfer.advance(60);
    await pumpEventQueue();
    transfer.advance(70);
    await pumpEventQueue();

    expect(
      (statusOf(logic) as DownloadTransferringStatus).receivedBytes,
      70,
    );
    verify(() => downloader.start(any())).called(1);
  });

  test('installs once every file is verified', () async {
    final logic = started();
    transfer.advance(100, phase: DownloadPhase.verifying);
    await pumpEventQueue();

    await transfer.settle(const DownloadCompleted());
    await logic.task;

    expect(statusOf(logic), isA<DownloadInstalledStatus>());
    expect(logic.value.record.status, DownloadRecordStatus.completed);
    expect(logic.value.record.receivedBytes, 100);
  });

  test('pauses with what it has when cancelled mid-transfer', () async {
    final logic = started();
    transfer.advance(40);
    await pumpEventQueue();

    logic.input(const CancelDownload());

    expect(transfer.cancelRequested.isCompleted, isTrue);
    expect(statusOf(logic), isA<DownloadTransferringStatus>());

    await transfer.settle(const DownloadCancelled());
    await logic.task;

    expect((statusOf(logic) as DownloadPausedStatus).receivedBytes, 40);
    expect(logic.value.record.status, DownloadRecordStatus.paused);
  });

  test('pauses instead of installing when cancelled mid-verify', () async {
    final logic = started();
    transfer.advance(100, phase: DownloadPhase.verifying);
    await pumpEventQueue();

    logic.input(const CancelDownload());

    expect(transfer.cancelRequested.isCompleted, isTrue);
    await transfer.settle(const DownloadCancelled());
    await logic.task;

    expect((statusOf(logic) as DownloadPausedStatus).receivedBytes, 100);
    expect(logic.value.record.status, DownloadRecordStatus.paused);
    expect(logic.value.finished, isFalse);
  });

  test('pauses straight away when cancelled while queued', () {
    final logic = logicFor(downloadRecord())..input(const CancelDownload());

    expect(statusOf(logic), isA<DownloadPausedStatus>());
    verifyNever(() => downloader.start(any()));
  });

  group('fails', () {
    Future<DownloadFailureReason> reasonAfter(
      Future<void> Function() settle,
    ) async {
      final logic = started();
      await settle();
      await logic.task;
      return (statusOf(logic) as DownloadFailedStatus).reason;
    }

    test('with the reason a transfer gives', () async {
      const failure = DownloadNetworkError('connection reset');

      final reason = await reasonAfter(
        () => transfer.settle(const DownloadFailed(failure)),
      );

      expect((reason as DownloadTransferFailed).failure, failure);
      expect(reason.detail, 'Network error: connection reset');
    });

    test('when a file does not match its checksum', () async {
      final reason = await reasonAfter(
        () => transfer.settle(
          const DownloadChecksumMismatch(
            file: DownloadFile(
              url: 'u',
              relativePath: 'model-Q4_K_M.gguf',
              bytes: 100,
            ),
            expected: 'feed',
            actual: 'beef',
          ),
        ),
      );

      expect((reason as DownloadChecksumFailed).file, 'model-Q4_K_M.gguf');
      expect(reason.detail, 'checksum mismatch: model-Q4_K_M.gguf');
    });

    test('as a worker error when the run throws', () async {
      final reason = await reasonAfter(
        () => transfer.crash(StateError('isolate died')),
      );

      final failure = (reason as DownloadTransferFailed).failure;
      expect(
        (failure as DownloadWorkerError).detail,
        contains('isolate died'),
      );
    });
  });

  test('queues again on resume, forgetting the failure', () {
    final logic = logicFor(
      downloadRecord(status: DownloadRecordStatus.failed, failure: 'x'),
    )..input(const ResumeDownload());

    expect(statusOf(logic), isA<DownloadQueuedStatus>());
    expect(logic.value.record.failure, isNull);
  });

  test('ignores progress that arrives after it stopped', () async {
    final logic = started();

    await transfer.settle(const DownloadCancelled());
    await logic.task;
    logic.input(
      const DownloadAdvanced(
        DownloadProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 99,
          totalBytes: 100,
        ),
      ),
    );

    expect(statusOf(logic), isA<DownloadPausedStatus>());
    expect(logic.value.record.receivedBytes, 0);
  });

  group('once installed', () {
    late DownloadLogic logic;

    setUp(() {
      logic = logicFor(downloadRecord(status: DownloadRecordStatus.completed));
    });

    test('stays installed until told its model is unlisted', () {
      logic
        ..input(const CancelDownload())
        ..input(const ResumeDownload());

      expect(statusOf(logic), isA<DownloadInstalledStatus>());
    });

    test('says why its model is unlisted, and keeps it current', () {
      final updates = <DownloadUpdated>[];
      logic
        ..bind().onOutput<DownloadUpdated>(updates.add)
        ..input(const ListingFailed(UnlistedFileMissing()));

      expect(
        (statusOf(logic) as DownloadUnlistedStatus).reason,
        isA<UnlistedFileMissing>(),
      );
      expect(statusOf(logic).needsAttention, isTrue);
      expect(logic.value.record.status, DownloadRecordStatus.completed);

      logic.input(const ListingFailed(UnlistedScanFailed('disk gone')));

      expect(
        (statusOf(logic) as DownloadUnlistedStatus).reason,
        isA<UnlistedScanFailed>().having(
          (reason) => reason.error,
          'error',
          'disk gone',
        ),
      );
      expect(updates, hasLength(1));
    });
  });
}
