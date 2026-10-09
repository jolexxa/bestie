import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';

const downloadId = 'org/model-GGUF:model-Q4_K_M.gguf';

DownloadRecord downloadRecord({
  String id = downloadId,
  String repo = 'org/model-GGUF',
  String quant = 'Q4_K_M',
  DownloadRecordStatus status = DownloadRecordStatus.pending,
  int receivedBytes = 0,
  String? failure,
  List<DownloadRecordFile> files = const [
    DownloadRecordFile(
      path: 'model-Q4_K_M.gguf',
      url:
          'https://huggingface.co/org/model-GGUF/resolve/abc/model-Q4_K_M.gguf',
      bytes: 100,
      sha256: 'feed',
    ),
  ],
}) => DownloadRecord(
  id: id,
  repo: repo,
  revision: 'abc',
  quant: quant,
  files: files,
  status: status,
  receivedBytes: receivedBytes,
  failure: failure,
);

class MockDownloadRun extends Mock implements DownloadRun {}

/// One transfer the test drives by hand.
class ScriptedRun {
  ScriptedRun() {
    when(() => run.progress).thenAnswer((_) => progress.stream);
    when(() => run.result).thenAnswer((_) => result.future);
    when(run.cancel).thenAnswer((_) {
      if (!cancelRequested.isCompleted) cancelRequested.complete();
    });
  }

  final run = MockDownloadRun();
  final progress = StreamController<DownloadProgress>();
  final result = Completer<DownloadResult>();
  final cancelRequested = Completer<void>();

  void advance(
    int receivedBytes, {
    DownloadPhase phase = DownloadPhase.downloading,
    double? speed,
  }) => progress.add(
    DownloadProgress(
      phase: phase,
      receivedBytes: receivedBytes,
      totalBytes: 100,
      speedBytesPerSecond: speed,
    ),
  );

  /// Settles as cancelled as soon as cancelling is asked for.
  void cancelsWhenAsked() => unawaited(
    cancelRequested.future.then((_) => settle(const DownloadCancelled())),
  );

  Future<void> settle(DownloadResult outcome) async {
    result.complete(outcome);
    await progress.close();
  }

  /// The run's future throws instead of settling.
  Future<void> crash(Object error) async {
    result.completeError(error);
    await progress.close();
  }
}
