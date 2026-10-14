import 'package:intentions/intentions.dart';
import 'package:model_downloader/model_downloader.dart';

/// One quant of a Hugging Face repo on its way into the library.
@model
final class ModelDownload {
  const ModelDownload({
    required this.id,
    required this.repo,
    required this.quant,
    required this.totalBytes,
    required this.status,
  });

  final String id;

  /// `namespace/name`.
  final String repo;

  /// The quant label, e.g. `Q4_K_M`.
  final String quant;

  final int totalBytes;

  final ModelDownloadStatus status;
}

/// Where a download stands.
@model
sealed class ModelDownloadStatus {
  const ModelDownloadStatus();

  /// Whether the download waits on the user.
  bool get needsAttention => false;
}

/// Waiting for a free download slot.
@model
final class DownloadQueuedStatus extends ModelDownloadStatus {
  const DownloadQueuedStatus({this.receivedBytes = 0});

  /// Bytes an interrupted attempt left on disk, which the next one keeps.
  final int receivedBytes;
}

@model
final class DownloadTransferringStatus extends ModelDownloadStatus {
  const DownloadTransferringStatus({
    required this.receivedBytes,
    this.speedBytesPerSecond,
  });

  /// Including bytes kept from an earlier attempt.
  final int receivedBytes;

  /// This attempt's average, once it has one.
  final double? speedBytesPerSecond;
}

/// A file is on disk and its checksum is being checked.
@model
final class DownloadVerifyingStatus extends ModelDownloadStatus {
  const DownloadVerifyingStatus({required this.receivedBytes});

  final int receivedBytes;
}

/// Verified and about to show up as a downloaded model.
@model
final class DownloadInstalledStatus extends ModelDownloadStatus {
  const DownloadInstalledStatus();
}

/// Verified, but the library has not listed the model, so the download
/// stays until a scan finds it or the user discards it.
@model
final class DownloadUnlistedStatus extends ModelDownloadStatus {
  const DownloadUnlistedStatus(this.reason);

  final UnlistedReason reason;

  @override
  bool get needsAttention => true;
}

/// Stopped by the user; resuming picks up where it stopped.
@model
final class DownloadPausedStatus extends ModelDownloadStatus {
  const DownloadPausedStatus({required this.receivedBytes});

  final int receivedBytes;

  @override
  bool get needsAttention => true;
}

/// Stopped by an error; retrying picks up where it stopped.
@model
final class DownloadFailedStatus extends ModelDownloadStatus {
  const DownloadFailedStatus({
    required this.reason,
    required this.receivedBytes,
  });

  final DownloadFailureReason reason;

  final int receivedBytes;

  @override
  bool get needsAttention => true;
}

/// Why a download stopped with an error.
@model
sealed class DownloadFailureReason {
  const DownloadFailureReason();

  /// One line for logs and the download ledger.
  String get detail;
}

@model
final class DownloadTransferFailed extends DownloadFailureReason {
  const DownloadTransferFailed(this.failure);

  final DownloadFailure failure;

  @override
  String get detail => failure.message;
}

/// [file] did not hash to its expected sha256 and was deleted.
@model
final class DownloadChecksumFailed extends DownloadFailureReason {
  const DownloadChecksumFailed(this.file);

  /// Relative to the repo.
  final String file;

  @override
  String get detail => 'checksum mismatch: $file';
}

/// A failure an earlier run recorded, known only by its [detail].
@model
final class DownloadFailedEarlier extends DownloadFailureReason {
  const DownloadFailedEarlier(this.detail);

  @override
  final String detail;
}

/// Why a finished download's model is not in the library.
@model
sealed class UnlistedReason {
  const UnlistedReason();
}

/// The scan that should have listed it failed.
@model
final class UnlistedScanFailed extends UnlistedReason {
  const UnlistedScanFailed(this.error);

  final String error;
}

/// A scan finished without finding its first file.
@model
final class UnlistedFileMissing extends UnlistedReason {
  const UnlistedFileMissing();
}
