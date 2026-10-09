import 'package:intentions/intentions.dart';

@model
sealed class DownloadRequestResult {
  const DownloadRequestResult(this.downloadId);

  final String downloadId;
}

/// Queued; it starts once a download slot is free.
@model
final class DownloadAccepted extends DownloadRequestResult {
  const DownloadAccepted(super.downloadId);
}

/// Already downloaded or on its way; nothing changed.
@model
final class DownloadAlreadyQueued extends DownloadRequestResult {
  const DownloadAlreadyQueued(super.downloadId);
}

/// A file bestie did not download sits where the download would land, and
/// downloading would replace it.
@model
final class DownloadTargetOccupied extends DownloadRequestResult {
  const DownloadTargetOccupied(super.downloadId, {required this.path});

  final String path;
}

/// The download names a repo or a file bestie will not fetch.
@model
final class DownloadRejected extends DownloadRequestResult {
  const DownloadRejected(super.downloadId, {required this.reason});

  final InvalidDownload reason;
}

/// This window cannot change downloads right now; the library's downloads
/// status says why.
@model
final class DownloadsUnavailable extends DownloadRequestResult {
  const DownloadsUnavailable(super.downloadId);
}

/// What makes a download unsafe or impossible to fetch.
@model
sealed class InvalidDownload {
  const InvalidDownload();
}

@model
final class InvalidRepoId extends InvalidDownload {
  const InvalidRepoId(this.repo);

  final String repo;
}

/// The file would land outside its repo's folder.
@model
final class InvalidFilePath extends InvalidDownload {
  const InvalidFilePath(this.path);

  final String path;
}

@model
final class NoDownloadFiles extends InvalidDownload {
  const NoDownloadFiles();
}

@model
sealed class CancelDownloadResult {
  const CancelDownloadResult();
}

/// The download stops, keeping what it has so it can resume.
@model
final class CancelRequested extends CancelDownloadResult {
  const CancelRequested();
}

/// No queued or running download has that id.
@model
final class NothingToCancel extends CancelDownloadResult {
  const NothingToCancel();
}

@model
sealed class ResumeDownloadResult {
  const ResumeDownloadResult();
}

/// Queued again; it picks up where it stopped.
@model
final class ResumeQueued extends ResumeDownloadResult {
  const ResumeQueued();
}

/// No paused or failed download has that id.
@model
final class NothingToResume extends ResumeDownloadResult {
  const NothingToResume();
}

@model
sealed class DeleteModelResult {
  const DeleteModelResult();
}

@model
final class ModelDeleted extends DeleteModelResult {
  const ModelDeleted({required this.freedBytes});

  final int freedBytes;
}

/// Models found in the user's folders are never deleted; removing the folder
/// from the library hides them.
@model
final class DeleteRefusedScanned extends DeleteModelResult {
  const DeleteRefusedScanned({required this.root});

  /// The folder the model was found in.
  final String root;
}

/// A file in the models folder that bestie did not download is never
/// deleted; the user removes it themselves.
@model
final class DeleteRefusedUntracked extends DeleteModelResult {
  const DeleteRefusedUntracked({required this.path});

  final String path;
}

/// This window cannot change downloads right now; the library's downloads
/// status says why.
@model
final class DeleteRefusedReadOnly extends DeleteModelResult {
  const DeleteRefusedReadOnly();
}

/// No model has that id.
@model
final class NothingToDelete extends DeleteModelResult {
  const NothingToDelete();
}

/// [path] could not be removed; the library still lists the model.
@model
final class DeleteFailed extends DeleteModelResult {
  const DeleteFailed({required this.path, required this.error});

  final String path;

  final String error;
}

@model
sealed class DiscardDownloadResult {
  const DiscardDownloadResult();
}

/// Stopped and forgotten, with its partial files gone.
@model
final class DownloadDiscarded extends DiscardDownloadResult {
  const DownloadDiscarded({required this.freedBytes});

  final int freedBytes;
}

/// No download in the queue has that id.
@model
final class NothingToDiscard extends DiscardDownloadResult {
  const NothingToDiscard();
}

/// [path] could not be removed; the download stays, stopped.
@model
final class DiscardFailed extends DiscardDownloadResult {
  const DiscardFailed({required this.path, required this.error});

  final String path;

  final String error;
}

/// What starting the library found in the download ledger.
@model
sealed class LedgerRestoreResult {
  const LedgerRestoreResult();
}

/// Every usable download is back where it stood.
@model
final class LedgerRestored extends LedgerRestoreResult {
  const LedgerRestored({this.dropped = const []});

  /// Downloads the ledger listed that were not safe to keep.
  final List<DroppedDownload> dropped;
}

/// Another bestie window runs downloads; this one only reads the ledger.
@model
final class LedgerManagedElsewhere extends LedgerRestoreResult {
  const LedgerManagedElsewhere();
}

/// The ledger could not be used.
@model
sealed class LedgerUnusable extends LedgerRestoreResult {
  const LedgerUnusable(this.reason);

  final String reason;
}

/// The ledger was corrupt; it now sits at [movedTo] and downloads start
/// over from an empty ledger.
@model
final class LedgerSetAside extends LedgerUnusable {
  const LedgerSetAside(super.reason, {required this.movedTo});

  final String movedTo;
}

/// The ledger could not be read, perhaps only for now, so it is left as it
/// is and nothing is written over it.
@model
final class LedgerUnreadable extends LedgerUnusable {
  const LedgerUnreadable(super.reason);
}

@model
final class DroppedDownload {
  const DroppedDownload({required this.downloadId, required this.reason});

  final String downloadId;

  final InvalidDownload reason;
}
