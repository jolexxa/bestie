import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/downloads/download_data.dart';
import 'package:local_models_repository/src/downloads/download_input.dart';
import 'package:local_models_repository/src/downloads/download_output.dart';
import 'package:local_models_repository/src/downloads/download_queue.dart';
import 'package:local_models_repository/src/models/model_download.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';

// ── Base state ──────────────────────────────────────────────

/// Where one download stands: queued → transferring ⇄ verifying →
/// installed, then unlisted if the library does not find its model, or
/// stopped as paused or failed until it is resumed.
@model
sealed class DownloadState extends StateLogic<DownloadState> {
  DownloadData get data => get<DownloadData>();

  ModelDownloader get downloader => get<ModelDownloader>();

  /// How the ledger records this state.
  DownloadRecordStatus get recordStatus;

  ModelDownloadStatus get status;

  /// Whether it waits for a download slot.
  bool get waiting => false;

  /// Whether it holds a download slot.
  bool get active => false;

  /// Whether every file is on disk and verified.
  bool get finished => false;

  bool get cancellable => false;

  bool get resumable => false;

  /// Why it failed, while it stands failed.
  DownloadFailureReason? get failure => null;

  DownloadRecord get record => data.plan.record.copyWith(
    status: recordStatus,
    receivedBytes: data.receivedBytes,
    failure: failure?.detail,
  );

  ModelDownload get snapshot => ModelDownload(
    id: data.plan.id,
    repo: data.plan.record.repo,
    quant: data.plan.record.quant,
    totalBytes: data.plan.totalBytes,
    status: status,
  );
}

// ── Compound states ─────────────────────────────────────────

/// A transfer is running and holds a download slot until it settles. It
/// owns the run and its progress for as long as it lasts, across every hop
/// between transferring and verifying.
@model
sealed class DownloadActiveState extends DownloadState {
  DownloadActiveState() {
    onEnter(() {
      final run = data.run = downloader.start(data.plan.job);
      data.progress = run.progress.listen(null);
      async(run.result)
          .input(DownloadSettled.new)
          .errorInput(
            (error) => DownloadSettled(
              DownloadFailed(DownloadWorkerError('$error')),
            ),
          );
    });
    onExit(() => data.endTransfer());

    on<CancelDownload>((_) {
      data.run?.cancel();
      return toSelf();
    });
    on<DownloadSettled>(
      (input) => switch (input.result) {
        DownloadCompleted() => install(),
        DownloadCancelled() => to<DownloadPausedState>(),
        DownloadChecksumMismatch(:final file) => fail(
          DownloadChecksumFailed(file.relativePath),
        ),
        DownloadFailed(:final reason) => fail(DownloadTransferFailed(reason)),
      },
    );
  }

  @override
  DownloadRecordStatus get recordStatus => DownloadRecordStatus.pending;

  @override
  bool get active => true;

  @override
  bool get cancellable => true;

  /// Sends the run's progress to this state. A state drops the inputs it
  /// sends once it has been left, so each one that is entered takes the
  /// progress over.
  void receiveProgress() => data.progress?.onData(
    (progress) => input(DownloadAdvanced(progress)),
  );

  /// Keeps the received bytes and speed current, reporting every change.
  Transition advance(DownloadProgress progress, Transition next) {
    data
      ..receivedBytes = progress.receivedBytes
      ..speedBytesPerSecond = progress.speedBytesPerSecond;
    output(const DownloadUpdated());
    return next;
  }

  Transition install() {
    data.receivedBytes = data.plan.totalBytes;
    return to<DownloadInstalledState>();
  }

  Transition fail(DownloadFailureReason reason) {
    data.failure = reason;
    return to<DownloadFailedState>();
  }
}

/// Stopped short of installing; waits for the user to resume it.
@model
sealed class DownloadStoppedState extends DownloadState {
  DownloadStoppedState() {
    on<ResumeDownload>((_) => to<DownloadQueuedState>());
  }

  @override
  bool get resumable => true;
}

/// Every file is on disk and verified; the download stays until the
/// library lists its model.
@model
sealed class DownloadFinishedState extends DownloadState {
  @override
  DownloadRecordStatus get recordStatus => DownloadRecordStatus.completed;

  @override
  bool get finished => true;

  void noteUnlisted(ListingFailed input) => data.unlisted = input.reason;
}

// ── Concrete states ─────────────────────────────────────────

@model
final class DownloadQueuedState extends DownloadState {
  DownloadQueuedState() {
    on<StartDownload>((_) => to<DownloadTransferringState>());
    on<CancelDownload>((_) => to<DownloadPausedState>());
  }

  @override
  DownloadRecordStatus get recordStatus => DownloadRecordStatus.pending;

  @override
  ModelDownloadStatus get status =>
      DownloadQueuedStatus(receivedBytes: data.receivedBytes);

  @override
  bool get waiting => true;

  @override
  bool get cancellable => true;
}

@model
final class DownloadTransferringState extends DownloadActiveState {
  DownloadTransferringState() {
    onEnter(receiveProgress);

    on<DownloadAdvanced>(
      (input) => advance(input.progress, switch (input.progress.phase) {
        DownloadPhase.verifying => to<DownloadVerifyingState>(),
        DownloadPhase.downloading => toSelf(),
      }),
    );
  }

  @override
  ModelDownloadStatus get status => DownloadTransferringStatus(
    receivedBytes: data.receivedBytes,
    speedBytesPerSecond: data.speedBytesPerSecond,
  );
}

/// A file is on disk and its checksum is being checked; a split model goes
/// back to transferring for its next file.
@model
final class DownloadVerifyingState extends DownloadActiveState {
  DownloadVerifyingState() {
    onEnter(receiveProgress);

    on<DownloadAdvanced>(
      (input) => advance(input.progress, switch (input.progress.phase) {
        DownloadPhase.downloading => to<DownloadTransferringState>(),
        DownloadPhase.verifying => toSelf(),
      }),
    );
  }

  @override
  ModelDownloadStatus get status =>
      DownloadVerifyingStatus(receivedBytes: data.receivedBytes);
}

@model
final class DownloadInstalledState extends DownloadFinishedState {
  DownloadInstalledState() {
    on<ListingFailed>((input) {
      noteUnlisted(input);
      return to<DownloadUnlistedState>();
    });
  }

  @override
  ModelDownloadStatus get status => const DownloadInstalledStatus();
}

@model
final class DownloadUnlistedState extends DownloadFinishedState {
  DownloadUnlistedState() {
    on<ListingFailed>((input) {
      noteUnlisted(input);
      output(const DownloadUpdated());
      return toSelf();
    });
  }

  @override
  ModelDownloadStatus get status => DownloadUnlistedStatus(data.unlisted);
}

@model
final class DownloadPausedState extends DownloadStoppedState {
  @override
  DownloadRecordStatus get recordStatus => DownloadRecordStatus.paused;

  @override
  ModelDownloadStatus get status =>
      DownloadPausedStatus(receivedBytes: data.receivedBytes);
}

@model
final class DownloadFailedState extends DownloadStoppedState {
  @override
  DownloadRecordStatus get recordStatus => DownloadRecordStatus.failed;

  @override
  ModelDownloadStatus get status =>
      DownloadFailedStatus(reason: failure, receivedBytes: data.receivedBytes);

  /// A ledger that recorded the failure without saying why leaves nothing
  /// to tell.
  @override
  DownloadFailureReason get failure =>
      data.failure ?? const DownloadFailedEarlier('');
}

// ── Logic block ─────────────────────────────────────────────

/// One download's lifecycle, picking up where the ledger left it.
@PartOf(DownloadQueue)
final class DownloadLogic extends LogicBlock<DownloadState> {
  DownloadLogic({
    required DownloadData data,
    required ModelDownloader downloader,
  }) {
    set(data);
    set(downloader);

    set(DownloadQueuedState());
    set(DownloadTransferringState());
    set(DownloadVerifyingState());
    set(DownloadInstalledState());
    set(DownloadUnlistedState());
    set(DownloadPausedState());
    set(DownloadFailedState());
  }

  @override
  Transition getInitialState() =>
      switch (get<DownloadData>().plan.record.status) {
        DownloadRecordStatus.pending => to<DownloadQueuedState>(),
        DownloadRecordStatus.paused => to<DownloadPausedState>(),
        DownloadRecordStatus.failed => to<DownloadFailedState>(),
        DownloadRecordStatus.completed => to<DownloadInstalledState>(),
      };
}
