import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:meta/meta.dart';
import 'package:model_downloader/src/download_command_handler.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/download_job.dart';
import 'package:model_downloader/src/download_progress.dart';
import 'package:model_downloader/src/download_result.dart';
import 'package:model_downloader/src/transfer_progress.dart';

/// Downloads model files, each job on its own background isolate so socket
/// and disk work never competes with the UI isolate.
///
/// Partial files survive cancellation and failure; starting the same job
/// again resumes where it stopped.
@dataSource
class ModelDownloader {
  ModelDownloader({
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
    Clock clock = const Clock(),
    @visibleForTesting
    IsolateCommandHandler<DownloadJob, DownloadResult>? commandHandler,
  }) : _isolateSpawner = isolateSpawner,
       _clock = clock,
       _commandHandler = commandHandler ?? const DownloadCommandHandler().call;

  final IsolateSpawner _isolateSpawner;
  final Clock _clock;
  final IsolateCommandHandler<DownloadJob, DownloadResult> _commandHandler;

  DownloadRun start(DownloadJob job) {
    final progress = StreamController<DownloadProgress>();
    final cancelRequested = Completer<void>();
    return DownloadRun._(
      progress: progress.stream,
      result: _run(job, progress, cancelRequested.future),
      cancelRequested: cancelRequested,
    );
  }

  Future<DownloadResult> _run(
    DownloadJob job,
    StreamController<DownloadProgress> progress,
    Future<void> cancelRequested,
  ) async {
    final spawn = await IsolateWorker.spawn<DownloadJob, DownloadResult>(
      commandHandler: _commandHandler,
      isolateSpawner: _isolateSpawner,
      debugName: 'model-download',
    );
    final result = switch (spawn) {
      IsolateSpawnFailed(:final message) => DownloadFailed(
        DownloadWorkerError(message),
      ),
      IsolateSpawnSucceeded(:final worker) => await _transfer(
        worker,
        job,
        progress,
        cancelRequested,
      ),
    };
    unawaited(progress.close());
    return result;
  }

  Future<DownloadResult> _transfer(
    IsolateWorker<DownloadJob, DownloadResult> worker,
    DownloadJob job,
    StreamController<DownloadProgress> progress,
    Future<void> cancelRequested,
  ) async {
    final speed = _SpeedMeter(_clock);
    final subscription = worker.events.cast<TransferProgress>().listen(
      (transfer) => progress.add(
        DownloadProgress(
          phase: transfer.phase,
          receivedBytes: transfer.receivedBytes,
          totalBytes: job.totalBytes,
          speedBytesPerSecond: speed.measure(transfer.transferredBytes),
        ),
      ),
    );
    final run = worker.sendCancellable(job);
    unawaited(cancelRequested.then((_) => run.cancel()));
    final result = await run.result;
    await subscription.cancel();
    await worker.close();
    return switch (result) {
      IsolateSucceeded(:final value) => value,
      IsolateFailed(:final message) => DownloadFailed(
        DownloadWorkerError(message),
      ),
    };
  }
}

/// A download in flight: progress while it runs, then exactly one result.
@model
interface class DownloadRun {
  DownloadRun._({
    required this.progress,
    required this.result,
    required Completer<void> cancelRequested,
  }) : _cancelRequested = cancelRequested;

  /// Job-wide progress. Closes when [result] completes.
  final Stream<DownloadProgress> progress;

  final Future<DownloadResult> result;

  final Completer<void> _cancelRequested;

  /// Asks the download to stop. It settles as [DownloadCancelled] unless it
  /// finishes first.
  void cancel() {
    if (!_cancelRequested.isCompleted) _cancelRequested.complete();
  }
}

/// Average speed of the bytes this attempt transferred since it started.
class _SpeedMeter {
  _SpeedMeter(this._clock) : _startedAt = _clock.now();

  final Clock _clock;
  final DateTime _startedAt;

  double? measure(int transferredBytes) {
    final elapsed = _clock.now().difference(_startedAt).inMicroseconds;
    if (elapsed <= 0) return null;
    return math.max(0, transferredBytes) *
        Duration.microsecondsPerSecond /
        elapsed;
  }
}
