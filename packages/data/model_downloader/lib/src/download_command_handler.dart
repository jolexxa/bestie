import 'package:file/local.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:model_downloader/src/chunked_file_downloader.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/download_job.dart';
import 'package:model_downloader/src/download_progress.dart';
import 'package:model_downloader/src/download_result.dart';
import 'package:model_downloader/src/file_transfer.dart';
import 'package:model_downloader/src/model_downloader.dart';
import 'package:model_downloader/src/transfer_progress.dart';

/// Runs a [DownloadJob] on the download isolate, one file after another,
/// sending [TransferProgress] back through the request's event sink.
///
/// Byte progress is forwarded at most once per [progressStepBytes] so the
/// isolate port is not flooded with an event per network packet.
@PartOf(ModelDownloader)
class DownloadCommandHandler {
  const DownloadCommandHandler({
    ChunkedFileDownloader Function() engineFactory = localEngine,
    this.progressStepBytes = 512 * 1024,
    this.workersPerFile = 24,
  }) : _engineFactory = engineFactory;

  /// Builds the engine against the real file system and network. Called
  /// inside the download isolate.
  static ChunkedFileDownloader localEngine() => ChunkedFileDownloader(
    fileSystem: const LocalFileSystem(),
    client: http.Client(),
  );

  final ChunkedFileDownloader Function() _engineFactory;
  final int progressStepBytes;
  final int workersPerFile;

  Future<DownloadResult> call(
    DownloadJob job,
    IsolateRequestContext context,
  ) async {
    if (job.files.where(job.escapes).firstOrNull case final escaping?) {
      return DownloadFailed(
        DownloadUnsafePath(
          relativePath: escaping.relativePath,
          directory: job.directory,
        ),
        file: escaping,
      );
    }
    final engine = _engineFactory();
    final tally = _JobTally();
    try {
      for (final file in job.files) {
        final outcome = await _download(engine, job, file, tally, context);
        switch (outcome) {
          case FileDownloaded():
            tally.completeFile(file);
          case FileChecksumMismatch(:final expected, :final actual):
            return DownloadChecksumMismatch(
              file: file,
              expected: expected,
              actual: actual,
            );
          case FileCancelled():
            return const DownloadCancelled();
          case FileFailed(:final reason):
            return DownloadFailed(reason, file: file);
        }
      }
      return const DownloadCompleted();
    } finally {
      engine.close();
    }
  }

  Future<FileOutcome> _download(
    ChunkedFileDownloader engine,
    DownloadJob job,
    DownloadFile file,
    _JobTally tally,
    IsolateRequestContext context,
  ) async {
    final transfer = engine.download(
      url: file.url,
      targetPath: job.targetPathFor(file),
      expectedBytes: file.bytes,
      expectedSha256: file.sha256,
      workers: workersPerFile,
      cancellation: context.cancellationToken,
    );
    var lastSent = -progressStepBytes;
    final delivered = transfer.progress.listen((progress) {
      switch (progress) {
        case FileBytesReceived(:final cumulative, :final keptBytes):
          tally.receive(cumulative, keptBytes);
          if (cumulative - lastSent < progressStepBytes &&
              cumulative != file.bytes) {
            return;
          }
          lastSent = cumulative;
          context.events.emit(tally.progress(DownloadPhase.downloading));
        case FileVerifying():
          context.events.emit(
            tally.progress(DownloadPhase.verifying, fileBytes: file.bytes),
          );
      }
    }).asFuture<void>();
    final outcome = await transfer.outcome;
    await delivered;
    return outcome;
  }
}

/// Running totals across a job's files: every byte on disk, and the bytes
/// actually transferred by this attempt.
class _JobTally {
  int _completedBytes = 0;
  int _completedTransferredBytes = 0;
  int _fileBytes = 0;
  int _fileTransferredBytes = 0;

  void receive(int cumulative, int keptBytes) {
    _fileBytes = cumulative;
    _fileTransferredBytes = cumulative - keptBytes;
  }

  void completeFile(DownloadFile file) {
    _completedBytes += file.bytes;
    _completedTransferredBytes += _fileTransferredBytes;
    _fileBytes = 0;
    _fileTransferredBytes = 0;
  }

  /// Progress so far, counting the current file as [fileBytes] when given.
  TransferProgress progress(DownloadPhase phase, {int? fileBytes}) =>
      TransferProgress(
        phase: phase,
        receivedBytes: _completedBytes + (fileBytes ?? _fileBytes),
        transferredBytes: _completedTransferredBytes + _fileTransferredBytes,
      );
}
