import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/local_model.dart';
import 'package:local_models_repository/src/models/model_download.dart';

/// Everything in the local model library, in the sections the Installed pane
/// shows. Within a model section, runnable models come first by name, then
/// the ones bestie cannot run.
@model
final class ModelLibrary {
  const ModelLibrary({
    this.downloading = const [],
    this.needsAttention = const [],
    this.downloaded = const [],
    this.inFolders = const [],
    this.scanning = false,
    this.status = const LibraryLoading(),
    this.downloadsStatus = const DownloadsStarting(),
  });

  /// Before anything is known, so nothing reads as empty yet.
  static const loading = ModelLibrary();

  /// Queued, transferring, verifying or just installed, in queue order.
  final List<ModelDownload> downloading;

  /// Paused, failed or unlisted, waiting on the user.
  final List<ModelDownload> needsAttention;

  /// Downloaded by bestie into its models folder.
  final List<LocalModel> downloaded;

  /// Found in the user's folders, or put in the models folder by hand.
  final List<LocalModel> inFolders;

  /// Whether a scan is under way, so the lists may be about to change.
  final bool scanning;

  final LibraryStatus status;

  final DownloadsStatus downloadsStatus;

  bool get isEmpty =>
      downloading.isEmpty &&
      needsAttention.isEmpty &&
      downloaded.isEmpty &&
      inFolders.isEmpty;

  Iterable<LocalModel> get models => [...downloaded, ...inFolders];

  Iterable<SupportedModel> get runnable => models.whereType<SupportedModel>();

  LocalModel? modelById(String id) =>
      models.where((model) => model.id == id).firstOrNull;
}

/// How far the library's model lists can be trusted.
@model
sealed class LibraryStatus {
  const LibraryStatus();
}

/// No scan has finished yet.
@model
final class LibraryLoading extends LibraryStatus {
  const LibraryLoading();
}

/// The lists are what the latest scan found.
@model
final class LibraryReady extends LibraryStatus {
  const LibraryReady();
}

/// The latest scan failed; the lists are what an earlier one found, if any
/// did.
@model
final class LibraryScanFailed extends LibraryStatus {
  const LibraryScanFailed(this.error);

  final String error;
}

/// Whether this window can download, and what it needs the user to know
/// about the download ledger.
@model
sealed class DownloadsStatus {
  const DownloadsStatus();

  /// Whether downloads may start, stop or be deleted from this window.
  bool get writable => true;
}

/// The ledger has not been read yet.
@model
final class DownloadsStarting extends DownloadsStatus {
  const DownloadsStarting();

  @override
  bool get writable => false;
}

@model
final class DownloadsReady extends DownloadsStatus {
  const DownloadsReady();
}

/// Another bestie window runs downloads; this one shows the library without
/// changing it.
@model
final class DownloadsManagedElsewhere extends DownloadsStatus {
  const DownloadsManagedElsewhere();

  @override
  bool get writable => false;
}

/// The ledger was corrupt and was moved to [movedTo]; downloads it listed
/// are forgotten, and their files show as untracked.
@model
final class DownloadsLedgerSetAside extends DownloadsStatus {
  const DownloadsLedgerSetAside({required this.reason, required this.movedTo});

  final String reason;

  final String movedTo;
}

/// The ledger could not be read, so nothing is written over it and nothing
/// downloads until it can be.
@model
final class DownloadsLedgerUnreadable extends DownloadsStatus {
  const DownloadsLedgerUnreadable(this.reason);

  final String reason;

  @override
  bool get writable => false;
}

/// Downloads run, but the ledger could not be saved; a restart would lose
/// what changed since the last save. Saving is retried.
@model
final class DownloadsLedgerNotSaved extends DownloadsStatus {
  const DownloadsLedgerNotSaved(this.reason);

  final String reason;
}
