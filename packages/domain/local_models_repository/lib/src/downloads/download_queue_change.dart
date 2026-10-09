import 'package:intentions/intentions.dart';

@model
sealed class DownloadQueueChange {
  const DownloadQueueChange();
}

/// A download moved, made progress, joined or left the queue, or the
/// downloads status changed.
@model
final class DownloadsUpdated extends DownloadQueueChange {
  const DownloadsUpdated();
}

/// A download is verified and on disk; it stays in the queue until a scan
/// lists its model, so its files are never shown twice or not at all.
@model
final class DownloadFinished extends DownloadQueueChange {
  const DownloadFinished(this.downloadId);

  final String downloadId;
}
