import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/model_download.dart';
import 'package:model_downloader/model_downloader.dart';

@model
sealed class DownloadInput {
  const DownloadInput();
}

/// A download slot is free for this download.
@model
final class StartDownload extends DownloadInput {
  const StartDownload();
}

/// Stop, keeping what is on disk.
@model
final class CancelDownload extends DownloadInput {
  const CancelDownload();
}

/// Queue a paused or failed download again.
@model
final class ResumeDownload extends DownloadInput {
  const ResumeDownload();
}

@model
final class DownloadAdvanced extends DownloadInput {
  const DownloadAdvanced(this.progress);

  final DownloadProgress progress;
}

/// The transfer ended, one way or another.
@model
final class DownloadSettled extends DownloadInput {
  const DownloadSettled(this.result);

  final DownloadResult result;
}

/// The library did not list the finished download's model.
@model
final class ListingFailed extends DownloadInput {
  const ListingFailed(this.reason);

  final UnlistedReason reason;
}
