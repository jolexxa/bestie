import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

part 'download_ledger.mapper.dart';

/// Every download bestie has started and not yet forgotten, finished or not.
@model
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class DownloadLedger with DownloadLedgerMappable {
  const DownloadLedger({required this.version, required this.downloads});

  static const fileName = 'downloads.json';

  /// Beside the ledger; whoever holds its lock may change the ledger.
  static const lockFileName = '.downloads.lock';

  static const currentVersion = 1;

  static const empty = DownloadLedger(version: currentVersion, downloads: []);

  final int version;

  /// In the order they were queued.
  final List<DownloadRecord> downloads;
}

/// One quant of one Hugging Face repo.
@model
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class DownloadRecord with DownloadRecordMappable {
  const DownloadRecord({
    required this.id,
    required this.repo,
    required this.quant,
    required this.files,
    required this.status,
    this.revision,
    this.receivedBytes = 0,
    this.failure,
  });

  final String id;

  /// `namespace/name`.
  final String repo;

  /// The commit the files are pinned to.
  final String? revision;

  /// The quant label, e.g. `Q4_K_M`.
  final String quant;

  /// In download order; a split model's first shard comes first.
  final List<DownloadRecordFile> files;

  final DownloadRecordStatus status;

  /// Bytes on disk when the download last stopped.
  final int receivedBytes;

  /// Why the download last failed.
  final String? failure;
}

@model
@MappableEnum()
enum DownloadRecordStatus {
  /// Queued or in flight; picked up again on the next start.
  pending,

  /// Stopped on request; waits to be resumed.
  paused,

  /// Stopped by an error; waits to be retried.
  failed,

  /// Every file is on disk and verified.
  completed,
}

/// One file of a download.
@model
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class DownloadRecordFile with DownloadRecordFileMappable {
  const DownloadRecordFile({
    required this.path,
    required this.url,
    required this.bytes,
    this.sha256,
  });

  /// Relative to the repo, which is also where it lands under the models
  /// folder.
  final String path;

  final String url;

  final int bytes;

  final String? sha256;
}
