import 'package:intentions/intentions.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/model_downloader.dart';

/// One file on its way to disk: live byte progress, then a single outcome.
@PartOf(ModelDownloader)
final class FileTransfer {
  const FileTransfer({required this.progress, required this.outcome});

  final Stream<FileProgress> progress;

  final Future<FileOutcome> outcome;
}

@PartOf(ModelDownloader)
sealed class FileProgress {
  const FileProgress();
}

/// Bytes of the file received so far, including bytes kept from an earlier
/// attempt.
@PartOf(ModelDownloader)
final class FileBytesReceived extends FileProgress {
  const FileBytesReceived(this.cumulative, {this.keptBytes = 0});

  final int cumulative;

  /// The part of [cumulative] that was already on disk before this attempt.
  final int keptBytes;
}

/// Every byte is on disk and the sha256 is being checked.
@PartOf(ModelDownloader)
final class FileVerifying extends FileProgress {
  const FileVerifying();
}

@PartOf(ModelDownloader)
sealed class FileOutcome {
  const FileOutcome();
}

@PartOf(ModelDownloader)
final class FileDownloaded extends FileOutcome {
  const FileDownloaded();
}

/// The bytes did not hash to the expected sha256. The partial file has been
/// deleted.
@PartOf(ModelDownloader)
final class FileChecksumMismatch extends FileOutcome {
  const FileChecksumMismatch({required this.expected, required this.actual});

  final String expected;
  final String actual;
}

/// Stopped on request. Partial bytes are kept for a later resume.
@PartOf(ModelDownloader)
final class FileCancelled extends FileOutcome {
  const FileCancelled();
}

/// Stopped by an HTTP, network or disk error. Partial bytes are kept for a
/// later resume.
@PartOf(ModelDownloader)
final class FileFailed extends FileOutcome {
  const FileFailed(this.reason);

  final DownloadFailure reason;
}
