import 'package:intentions/intentions.dart';
import 'package:model_downloader/src/download_progress.dart';
import 'package:model_downloader/src/model_downloader.dart';

/// Job progress as it crosses back from the download isolate, before speed
/// is measured.
@PartOf(ModelDownloader)
final class TransferProgress {
  const TransferProgress({
    required this.phase,
    required this.receivedBytes,
    required this.transferredBytes,
  });

  final DownloadPhase phase;

  /// Bytes on disk across the job, including bytes kept from an earlier
  /// attempt.
  final int receivedBytes;

  /// Bytes this attempt has fetched over the network.
  final int transferredBytes;
}
