import 'package:intentions/intentions.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/download_job.dart';

/// How a download job ended.
@model
sealed class DownloadResult {
  const DownloadResult();
}

/// Every file is on disk and, where a sha256 was given, verified.
@model
final class DownloadCompleted extends DownloadResult {
  const DownloadCompleted();
}

/// Stopped on request. Partial files are kept, so starting the same job
/// again resumes it.
@model
final class DownloadCancelled extends DownloadResult {
  const DownloadCancelled();
}

/// [file] did not hash to its expected sha256 and was deleted.
@model
final class DownloadChecksumMismatch extends DownloadResult {
  const DownloadChecksumMismatch({
    required this.file,
    required this.expected,
    required this.actual,
  });

  final DownloadFile file;
  final String expected;
  final String actual;
}

/// Stopped by an error. Partial files are kept, so starting the same job
/// again resumes it.
@model
final class DownloadFailed extends DownloadResult {
  const DownloadFailed(this.reason, {this.file});

  final DownloadFailure reason;

  /// A sentence describing [reason], fit to show the person who started the
  /// download.
  String get message => reason.message;

  /// The file being fetched when the error happened, if any.
  final DownloadFile? file;
}
