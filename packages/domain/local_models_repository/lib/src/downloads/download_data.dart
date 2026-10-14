import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/downloads/download_plan.dart';
import 'package:local_models_repository/src/models/model_download.dart';
import 'package:model_downloader/model_downloader.dart';

/// Mutable state shared across one download's states.
@model
final class DownloadData {
  DownloadData(this.plan)
    : receivedBytes = plan.record.receivedBytes,
      failure = switch (plan.record.failure) {
        final detail? => DownloadFailedEarlier(detail),
        null => null,
      };

  /// What to fetch and where it lands.
  final DownloadPlan plan;

  int receivedBytes;

  double? speedBytesPerSecond;

  /// Why the download last failed.
  DownloadFailureReason? failure;

  /// Why a finished download's model is not listed, once a scan says so.
  UnlistedReason unlisted = const UnlistedFileMissing();

  DownloadRun? run;

  StreamSubscription<DownloadProgress>? progress;

  /// Lets go of the transfer that just settled or was abandoned.
  void endTransfer() {
    unawaited(progress?.cancel());
    run = null;
    progress = null;
    speedBytesPerSecond = null;
  }
}
