import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/downloads/download_data.dart';
import 'package:local_models_repository/src/downloads/download_input.dart';
import 'package:local_models_repository/src/downloads/download_logic.dart';
import 'package:local_models_repository/src/downloads/download_output.dart';
import 'package:local_models_repository/src/downloads/download_plan.dart';
import 'package:local_models_repository/src/downloads/download_queue_change.dart';
import 'package:local_models_repository/src/downloads/file_removal.dart';
import 'package:local_models_repository/src/downloads/ledger_writer.dart';
import 'package:local_models_repository/src/local_models_repository.dart';
import 'package:local_models_repository/src/models/library_results.dart';
import 'package:local_models_repository/src/models/model_download.dart';
import 'package:local_models_repository/src/models/model_library.dart';
import 'package:local_models_repository/src/models/model_source.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:path/path.dart' as p;

/// Every download bestie knows about: the ones in flight, waiting, stopped
/// or finished but not yet listed, each run by its own [DownloadLogic], and
/// the completed ones, remembered so their models read as downloaded. It
/// alone decides whether a download may start.
///
/// Up to [maxActive] downloads transfer at once, oldest first. The ledger is
/// saved whenever a download changes state, so a restart resumes whatever
/// was queued or transferring. Only the window holding the ledger's lock
/// runs downloads; any other reads the ledger and changes nothing.
@PartOf(LocalModelsRepository)
class DownloadQueue {
  DownloadQueue({
    required String modelsDir,
    required ModelDownloader downloader,
    required DownloadLedgerStore ledger,
    required FileSystem fileSystem,
    required Clock clock,
    LedgerWriter? writer,
  }) : _modelsDir = modelsDir,
       _downloader = downloader,
       _ledger = ledger,
       _fileSystem = fileSystem,
       _clock = clock,
       _writer = writer ?? LedgerWriter(ledger) {
    _writes = _writer.written.listen(_onWritten);
  }

  /// Two let the next download start while one finishes without crowding
  /// the connection, since each already fetches in parallel ranges.
  static const maxActive = 2;

  /// What an interrupted transfer leaves beside each file.
  static const _leftovers = ['', '.part', '.part.meta', '.part.meta.tmp'];

  final String _modelsDir;
  final ModelDownloader _downloader;
  final DownloadLedgerStore _ledger;
  final FileSystem _fileSystem;
  final Clock _clock;
  final LedgerWriter _writer;
  late final StreamSubscription<StoreWriteResult> _writes;

  final _logics = <String, DownloadLogic>{};
  final _bindings = <String, LogicBlockBinding<DownloadState>>{};
  final _completed = <String, DownloadPlan>{};
  final _changes = StreamController<DownloadQueueChange>.broadcast(sync: true);
  DownloadsStatus _status = const DownloadsStarting();

  Stream<DownloadQueueChange> get changes => _changes.stream;

  DownloadsStatus get status => _status;

  /// Downloads still in the queue, oldest first.
  List<ModelDownload> get downloads => [
    for (final logic in _logics.values) logic.value.snapshot,
  ];

  /// Completed downloads by the path of their first file.
  Map<String, DownloadedSource> get downloadedSources => {
    for (final plan in _completed.values) plan.firstPath: plan.source,
  };

  /// Every file of every download still in the queue.
  Set<String> get queuedPaths => {
    for (final logic in _logics.values) ...logic.value.data.plan.paths,
  };

  /// Downloads in the queue, and completed ones whose model is on disk.
  Set<String> get knownIds => {
    ..._logics.keys,
    for (final plan in _completed.values)
      if (_fileSystem.isFileSync(plan.firstPath)) plan.id,
  };

  /// Takes the ledger's lock and picks the ledger up: completed downloads
  /// are remembered, and the rest return to where they stood, with the
  /// queued ones starting again. Without the lock, only the completed ones
  /// are read. Call again while [status] is not writable to try again.
  Future<LedgerRestoreResult> restore() async {
    final result = switch (await _ledger.lock()) {
      LedgerLockHeld() => await _readCompleted(),
      LedgerLockAcquired() || LedgerLockFailed() => await _restore(),
    };
    _announce();
    return result;
  }

  /// Queues [record] unless it is already known, unsafe, or would replace a
  /// file bestie did not download.
  DownloadRequestResult enqueue(DownloadRecord record) =>
      switch (DownloadPlan.of(record, modelsDir: _modelsDir)) {
        _ when !_status.writable => DownloadsUnavailable(record.id),
        _ when knownIds.contains(record.id) => DownloadAlreadyQueued(
          record.id,
        ),
        DownloadPlanInvalid(:final reason) => DownloadRejected(
          record.id,
          reason: reason,
        ),
        DownloadPlanned(:final plan) => _accept(plan),
      };

  CancelDownloadResult cancel(String downloadId) {
    if (_logics[downloadId] case final logic? when logic.value.cancellable) {
      logic.input(const CancelDownload());
      return const CancelRequested();
    }
    return const NothingToCancel();
  }

  ResumeDownloadResult resume(String downloadId) {
    if (_logics[downloadId] case final logic? when logic.value.resumable) {
      logic.input(const ResumeDownload());
      return const ResumeQueued();
    }
    return const NothingToResume();
  }

  /// Stops a download in the queue and deletes its files, partial or whole,
  /// forgetting it once they are gone.
  Future<DiscardDownloadResult> discard(String downloadId) async {
    final logic = _logics[downloadId];
    if (logic == null) return const NothingToDiscard();
    logic.input(const CancelDownload());
    await logic.task;
    return switch (await _deleteFiles(logic.value.data.plan)) {
      FilesRemoved(:final freedBytes) => _forget(
        downloadId,
        DownloadDiscarded(freedBytes: freedBytes),
      ),
      FileRemovalFailed(:final path, :final error) => DiscardFailed(
        path: path,
        error: error,
      ),
    };
  }

  /// Deletes a completed download's files, forgetting it once they are
  /// gone.
  Future<DeleteModelResult> deleteCompleted(String downloadId) async {
    if (!_status.writable) return const DeleteRefusedReadOnly();
    final plan = _completed[downloadId];
    if (plan == null) return const NothingToDelete();
    return switch (await _deleteFiles(plan)) {
      FilesRemoved(:final freedBytes) => _forget(
        downloadId,
        ModelDeleted(freedBytes: freedBytes),
      ),
      FileRemovalFailed(:final path, :final error) => DeleteFailed(
        path: path,
        error: error,
      ),
    };
  }

  /// A scan finished: finished downloads whose first file it listed become
  /// completed, and the rest are marked unlisted.
  void reconcile(Set<String> listedPaths) {
    for (final logic in _finished) {
      final path = logic.value.data.plan.firstPath;
      if (listedPaths.contains(path)) {
        _retire(logic);
      } else {
        logic.input(const ListingFailed(UnlistedFileMissing()));
      }
    }
    _announce();
  }

  /// A scan failed, so the finished downloads it should have listed are
  /// marked unlisted.
  void scanFailed(String error) {
    for (final logic in _finished) {
      logic.input(ListingFailed(UnlistedScanFailed(error)));
    }
  }

  /// Stops every transfer without recording it, so the next start resumes
  /// them, and lets go of the ledger's lock.
  Future<void> dispose() async {
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    for (final logic in _logics.values) {
      logic
        ..input(const CancelDownload())
        ..dispose();
    }
    _bindings.clear();
    _logics.clear();
    await _writes.cancel();
    await _writer.close();
    await _ledger.unlock();
    await _changes.close();
  }

  List<DownloadLogic> get _finished => [
    for (final logic in _logics.values)
      if (logic.value.finished) logic,
  ];

  Future<LedgerRestoreResult> _readCompleted() async {
    final records = switch (await _ledger.read()) {
      StoreLoaded(:final value) => value.downloads,
      _ => const <DownloadRecord>[],
    };
    _completed.clear();
    for (final record in records) {
      if (DownloadPlan.of(record, modelsDir: _modelsDir) case DownloadPlanned(
        :final plan,
      ) when record.status == DownloadRecordStatus.completed) {
        _completed[plan.id] = plan;
      }
    }
    _status = const DownloadsManagedElsewhere();
    return const LedgerManagedElsewhere();
  }

  Future<LedgerRestoreResult> _restore() async =>
      switch (await _ledger.read()) {
        StoreLoaded(:final value) => _adopt(value.downloads),
        StoreAbsent() => _adopt(const []),
        StoreCorrupt(:final reason) => await _setAside(reason),
        StoreUnreadable(:final reason) => _unreadable(reason),
      };

  LedgerRestoreResult _adopt(List<DownloadRecord> records) {
    _completed.clear();
    final dropped = <DroppedDownload>[];
    for (final record in records) {
      switch (DownloadPlan.of(record, modelsDir: _modelsDir)) {
        case DownloadPlanInvalid(:final reason):
          dropped.add(DroppedDownload(downloadId: record.id, reason: reason));
        case DownloadPlanned(:final plan)
            when record.status == DownloadRecordStatus.completed:
          _completed[plan.id] = plan;
        case DownloadPlanned(:final plan):
          _track(plan);
      }
    }
    _status = const DownloadsReady();
    _settle();
    return LedgerRestored(dropped: dropped);
  }

  Future<LedgerRestoreResult> _setAside(String reason) async =>
      switch (await _ledger.setAside(_clock.now())) {
        StoreSetAside(:final movedTo) => _startOver(reason, movedTo),
        StoreSetAsideFailed(reason: final failure) => _unreadable(failure),
      };

  LedgerRestoreResult _startOver(String reason, String movedTo) {
    _adopt(const []);
    _status = DownloadsLedgerSetAside(reason: reason, movedTo: movedTo);
    return LedgerSetAside(reason, movedTo: movedTo);
  }

  LedgerRestoreResult _unreadable(String reason) {
    _status = DownloadsLedgerUnreadable(reason);
    return LedgerUnreadable(reason);
  }

  /// Files the ledger owns are the download's own to replace; anything
  /// else at a target path belongs to the user.
  DownloadRequestResult _accept(DownloadPlan plan) {
    final owned = _completed[plan.id]?.paths ?? const [];
    final occupied = plan.paths.where(
      (path) =>
          !owned.contains(path) &&
          _fileSystem.typeSync(path, followLinks: false) !=
              FileSystemEntityType.notFound,
    );
    if (occupied.isNotEmpty) {
      return DownloadTargetOccupied(plan.id, path: occupied.first);
    }
    _completed.remove(plan.id);
    _track(plan);
    _settle();
    return DownloadAccepted(plan.id);
  }

  void _track(DownloadPlan plan) {
    final logic = DownloadLogic(
      data: DownloadData(plan),
      downloader: _downloader,
    )..start();
    _logics[plan.id] = logic;
    _bindings[plan.id] = logic.bind()
      ..onState<DownloadState>((_) => _settle())
      ..onState<DownloadInstalledState>(
        (_) => _changes.add(DownloadFinished(plan.id)),
      )
      ..onOutput<DownloadUpdated>((_) => _announce());
  }

  void _retire(DownloadLogic logic) {
    final plan = logic.value.data.plan.withRecord(logic.value.record);
    _completed[plan.id] = plan;
    _logics.remove(plan.id);
    _drop(plan.id, logic);
  }

  Result _forget<Result>(String downloadId, Result result) {
    _completed.remove(downloadId);
    if (_logics.remove(downloadId) case final logic?) _drop(downloadId, logic);
    _persist();
    _announce();
    return result;
  }

  void _drop(String downloadId, DownloadLogic logic) {
    _bindings.remove(downloadId)?.dispose();
    logic.dispose();
  }

  /// Fills free download slots, saves where everything stands, and tells
  /// listeners.
  void _settle() {
    final active = _logics.values.where((logic) => logic.value.active).length;
    final next = _logics.values
        .where((logic) => logic.value.waiting)
        .take(math.max(0, maxActive - active))
        .toList();
    for (final logic in next) {
      logic.input(const StartDownload());
    }
    _persist();
    _announce();
  }

  Future<FileRemoval> _deleteFiles(DownloadPlan plan) async {
    final files = [
      for (final path in plan.paths)
        for (final suffix in _leftovers) _fileSystem.file('$path$suffix'),
    ].where((file) => file.existsSync()).toList();
    final freedBytes = files.fold(0, (sum, file) => sum + file.lengthSync());
    try {
      for (final file in files) {
        await file.delete();
      }
    } on FileSystemException catch (error) {
      return FileRemovalFailed(
        path: error.path ?? plan.firstPath,
        error: error.message,
      );
    }
    await _removeEmptyFolders(plan);
    return FilesRemoved(freedBytes);
  }

  /// Removes the folders the download's files sat in, deepest first, up to
  /// but not including the models folder, leaving any that still hold
  /// something.
  Future<void> _removeEmptyFolders(DownloadPlan plan) async {
    final folders = {
      for (final path in plan.paths)
        for (
          var folder = p.dirname(path);
          p.isWithin(_modelsDir, folder);
          folder = p.dirname(folder)
        )
          folder,
    }.toList()..sort((first, second) => second.length.compareTo(first.length));
    for (final folder in folders) {
      try {
        await _fileSystem.directory(folder).delete();
      } on FileSystemException {
        continue;
      }
    }
  }

  void _persist() {
    if (!_status.writable) return;
    _writer.save(
      DownloadLedger(
        version: DownloadLedger.currentVersion,
        downloads: [
          for (final plan in _completed.values) plan.record,
          for (final logic in _logics.values) logic.value.record,
        ],
      ),
    );
  }

  void _onWritten(StoreWriteResult result) {
    _status = switch (result) {
      StoreWriteFailed(:final reason) => DownloadsLedgerNotSaved(reason),
      StoreWritten() when _status is DownloadsLedgerNotSaved =>
        const DownloadsReady(),
      StoreWritten() => _status,
    };
    _announce();
  }

  void _announce() => _changes.add(const DownloadsUpdated());
}
