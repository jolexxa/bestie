import 'dart:async';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/src/downloads/download_queue.dart';
import 'package:local_models_repository/src/downloads/download_queue_change.dart';
import 'package:local_models_repository/src/models/library_results.dart';
import 'package:local_models_repository/src/models/local_model.dart';
import 'package:local_models_repository/src/models/model_library.dart';
import 'package:local_models_repository/src/models/model_source.dart';
import 'package:local_models_repository/src/models/repo_resolution.dart';
import 'package:local_models_repository/src/models/repo_search.dart';
import 'package:local_models_repository/src/repo_resolver.dart';
import 'package:local_models_repository/src/scan/model_scanner.dart';
import 'package:local_models_repository/src/scan/scan_input.dart';
import 'package:local_models_repository/src/scan/scan_logic.dart';
import 'package:local_models_repository/src/scan/scan_output.dart';
import 'package:local_models_repository/src/search/repo_searcher.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/subjects.dart';

/// The local model library: GGUFs bestie downloaded into its models folder,
/// found by scanning the user's folders, and the downloads on their way in.
///
/// Whenever the library changes, the model index is rewritten to list every
/// model in it that can run, which is all the inference server reads.
@repository
class LocalModelsRepository {
  LocalModelsRepository({
    required String modelsDir,
    required HubClient hub,
    required ModelDownloader downloader,
    required ModelIndexStore indexStore,
    required DownloadLedgerStore ledgerStore,
    List<String> folders = const [],
    FileSystem fileSystem = const LocalFileSystem(),
    Clock clock = const Clock(),
  }) : _modelsDir = fileSystem.path.normalize(modelsDir),
       _paths = fileSystem.path,
       _folders = _normalized(folders, fileSystem.path),
       _indexStore = indexStore,
       _resolver = RepoResolver(hub),
       _searcher = RepoSearcher(hub),
       _downloads = DownloadQueue(
         modelsDir: fileSystem.path.normalize(modelsDir),
         downloader: downloader,
         ledger: ledgerStore,
         fileSystem: fileSystem,
         clock: clock,
       ),
       _scan = ScanLogic(ModelScanner(fileSystem: fileSystem)) {
    _scan.start();
    _scanBinding = _scan.bind()
      ..onOutput<ScanPublished>(_onScanPublished)
      ..onOutput<ScanFailed>(_onScanFailed)
      ..onState<ScanState>((_) => _publish());
    _downloadChanges = _downloads.changes.listen(_onDownloadsChanged);
  }

  final String _modelsDir;
  final p.Context _paths;
  List<String> _folders;
  final ModelIndexStore _indexStore;
  final RepoResolver _resolver;
  final RepoSearcher _searcher;
  final DownloadQueue _downloads;
  final ScanLogic _scan;
  late final LogicBlockBinding<ScanState> _scanBinding;
  late final StreamSubscription<DownloadQueueChange> _downloadChanges;
  final _library = BehaviorSubject<ModelLibrary>.seeded(ModelLibrary.loading);

  /// Null until the first scan lands, so an empty index is never written
  /// over a full one at startup.
  List<LocalModel>? _scanned;
  LibraryStatus _status = const LibraryLoading();
  Map<String, ModelReasoning> _overrides = const {};
  ModelIndex? _writtenIndex;
  Future<void> _indexWrites = Future.value();

  /// The library as it changes, opening with [current].
  Stream<ModelLibrary> get library => _library.stream;

  ModelLibrary get current => _library.value;

  /// Picks the download ledger up and scans every folder.
  Future<LedgerRestoreResult> start() async {
    final restored = await _downloads.restore();
    await _rescan();
    return restored;
  }

  /// Scans the models folder and the user's folders again, first trying the
  /// ledger again if this window could not use it. Completes once a scan
  /// that started after this call has landed and the model index lists
  /// what it found.
  Future<void> rescan() async {
    if (!_downloads.status.writable) await _downloads.restore();
    await _rescan();
  }

  /// Replaces the user's folders and rescans.
  Future<void> setFolders(List<String> folders) {
    _folders = _normalized(folders, _paths);
    return rescan();
  }

  /// Reasoning the user chose per model id, in place of what was detected.
  void setReasoningOverrides(Map<String, ModelReasoning> overrides) {
    _overrides = Map.unmodifiable(overrides);
    _publish();
  }

  /// Hugging Face repos with GGUF files matching [query], most downloaded
  /// first; an empty [query] lists the most downloaded of all.
  Future<RepoSearchResult> searchRepos(
    String query, {
    int limit = 20,
    Duration timeout = const Duration(seconds: 10),
  }) => _searcher.search(query, limit: limit, timeout: timeout);

  Future<RepoResolution> resolveRepo(String repo) =>
      _resolver.resolve(repo, inLibrary: _downloads.knownIds);

  /// Queues [quant] unless it is already downloaded or on its way, first
  /// trying the ledger again if this window could not use it.
  Future<DownloadRequestResult> download(RepoQuant quant) async {
    if (!_downloads.status.writable) await _downloads.restore();
    return _downloads.enqueue(_recordOf(quant));
  }

  CancelDownloadResult cancel(String downloadId) =>
      _downloads.cancel(downloadId);

  /// Resumes a paused download or retries a failed one.
  ResumeDownloadResult resume(String downloadId) =>
      _downloads.resume(downloadId);

  /// Stops a download that has not been listed yet and deletes its files.
  Future<DiscardDownloadResult> discardDownload(String downloadId) =>
      _downloads.discard(downloadId);

  /// Deletes a model bestie downloaded. Models it did not download are
  /// refused.
  Future<DeleteModelResult> deleteModel(String localId) async =>
      switch (current.modelById(localId)) {
        LocalModel(source: ScannedSource(:final root)) => DeleteRefusedScanned(
          root: root,
        ),
        LocalModel(:final path, source: UntrackedSource()) =>
          DeleteRefusedUntracked(path: path),
        LocalModel(source: DownloadedSource(:final downloadId)) => _deleted(
          localId,
          await _downloads.deleteCompleted(downloadId),
        ),
        null => const NothingToDelete(),
      };

  Future<void> dispose() async {
    await _downloadChanges.cancel();
    await _downloads.dispose();
    await _scan.task;
    _scanBinding.dispose();
    _scan.dispose();
    await _indexWrites;
    await _library.close();
  }

  List<String> get _roots => [_modelsDir, ..._folders];

  Future<void> _rescan() async {
    _scan.input(RescanRequested(_roots));
    await _scan.task;
    await _indexWrites;
  }

  /// A deleted model leaves the library at once, and any scan already under
  /// way, which may still have seen it, is dropped for a fresh one.
  DeleteModelResult _deleted(String localId, DeleteModelResult result) {
    if (result is ModelDeleted) {
      _scanned = _scanned?.where((model) => model.id != localId).toList();
      _scan.input(RescanRequested(_roots));
      _publish();
    }
    return result;
  }

  void _onScanPublished(ScanPublished output) {
    _scanned = output.models;
    _status = const LibraryReady();
    _downloads.reconcile({for (final model in output.models) model.path});
    _publish();
  }

  void _onScanFailed(ScanFailed output) {
    _status = LibraryScanFailed(output.error);
    _downloads.scanFailed(output.error);
    _publish();
  }

  void _onDownloadsChanged(DownloadQueueChange change) => switch (change) {
    DownloadsUpdated() => _publish(),
    DownloadFinished() => _scan.input(RescanRequested(_roots)),
  };

  void _publish() {
    final library = _compose();
    _library.add(library);
    if (_scanned != null) _writeIndex(library);
  }

  ModelLibrary _compose() {
    final downloads = _downloads.downloads;
    final queued = _downloads.queuedPaths;
    final downloaded = _downloads.downloadedSources;
    final models = _distinct([
      for (final model in _scanned ?? const <LocalModel>[])
        if (!queued.contains(model.path))
          _attributed(
            model,
            downloaded[model.path],
          ).withReasoningOverride(_overrides[model.id]),
    ]);
    return ModelLibrary(
      downloading: [
        for (final download in downloads)
          if (!download.status.needsAttention) download,
      ],
      needsAttention: [
        for (final download in downloads)
          if (download.status.needsAttention) download,
      ],
      downloaded: _ordered(
        models.where((model) => model.source is DownloadedSource),
      ),
      inFolders: _ordered(
        models.where((model) => model.source is! DownloadedSource),
      ),
      scanning: _scan.value.scanning,
      status: _status,
      downloadsStatus: _downloads.status,
    );
  }

  /// Where the model came from: a download bestie remembers, a file bestie
  /// did not download in its own folder, or a folder of the user's.
  LocalModel _attributed(LocalModel model, DownloadedSource? downloaded) =>
      switch (model.source) {
        _ when downloaded != null => model.withSource(downloaded),
        final ScannedSource source when source.root == _modelsDir =>
          model.withSource(source.untracked),
        _ => model,
      };

  /// One model per id: copies of a file share an id, and the one bestie
  /// downloaded wins, then the one found first.
  static List<LocalModel> _distinct(List<LocalModel> models) {
    final byId = <String, LocalModel>{};
    for (final model in models) {
      byId.update(
        model.id,
        (kept) => model.source is DownloadedSource ? model : kept,
        ifAbsent: () => model,
      );
    }
    return [...byId.values];
  }

  void _writeIndex(ModelLibrary library) {
    final index = ModelIndex(
      version: ModelIndex.currentVersion,
      models: [...library.models.map((model) => model.indexEntry).nonNulls],
    );
    if (index == _writtenIndex) return;
    _writtenIndex = index;
    _indexWrites = _indexWrites.then((_) async {
      if (await _indexStore.write(index) case StoreWriteFailed()) {
        _writtenIndex = null;
      }
    });
  }

  /// Runnable models first, then the rest, each by name.
  static List<LocalModel> _ordered(Iterable<LocalModel> models) =>
      models.toList()
        ..sort((first, second) => _sortKey(first).compareTo(_sortKey(second)));

  static String _sortKey(LocalModel model) =>
      '${model is SupportedModel ? 0 : 1}${model.displayName.toLowerCase()}';

  static List<String> _normalized(List<String> folders, p.Context paths) => [
    for (final folder in folders) paths.normalize(folder),
  ];

  static DownloadRecord _recordOf(RepoQuant quant) => DownloadRecord(
    id: quant.downloadId,
    repo: quant.repo,
    revision: quant.revision,
    quant: quant.label,
    status: DownloadRecordStatus.pending,
    files: [
      for (final file in quant.files)
        DownloadRecordFile(
          path: file.path,
          url: '${file.url}',
          bytes: file.sizeBytes,
          sha256: file.sha256,
        ),
    ],
  );
}
