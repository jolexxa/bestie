import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/panes/model_actions.dart';
import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:bestie_local_models_use_case/src/wording/server_band.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Downloads on their way, everything in the models folder and the user's
/// folders, and the local server's band.
@PartOf(LocalModelsUseCase)
class InstalledPane extends Pane {
  InstalledPane({
    required LocalModelsOperations operations,
    required this.downloadCommand,
    required this.addFolderCommand,
  }) : _operations = operations;

  final LocalModelsOperations _operations;

  /// Where the empty state sends the user to find a model.
  final Command downloadCommand;

  /// Where the empty state sends the user to add a folder of GGUFs.
  final Command addFolderCommand;

  @override
  String get title => 'Installed';

  @override
  String get placeholder => 'Filter models…';

  @override
  Stream<PaneStatus?> get status => Rx.combineLatest3(
    _operations.server,
    _operations.failures,
    _operations.library,
    (server, failure, library) => serverBand(
      server,
      failure: failure,
      nameOf: (localId) => modelName(library, localId),
      freeBytes: _operations.freeMemoryBytes,
      retry: _retryServer,
    ),
  );

  late final PaneAction _retryServer = PaneAction(
    key: const CharKey('r'),
    label: 'Retry',
    invoke: () async {
      _operations.retryServer();
      return const PaneStay();
    },
  );

  @override
  Stream<PaneContent> content(String query) => Rx.combineLatest2(
    _operations.library.where(
      (library) => library.status is! LibraryLoading,
    ),
    _operations.inUseIds,
    _contentOf,
  );

  PaneContent _contentOf(ModelLibrary library, String? running) {
    if (library.isEmpty) return _empty(library.status);
    final inUse = [
      for (final model in library.models)
        if (model.id == running) model,
    ];
    List<LocalModel> resting(List<LocalModel> models) => [
      for (final model in models)
        if (model.id != running) model,
    ];
    return PaneContent([
      ?_downloadsNote(library.downloadsStatus),
      ?_section('Downloading', [
        for (final download in library.downloading) _downloadRow(download),
      ]),
      ?_section('Needs attention', [
        for (final download in library.needsAttention) _downloadRow(download),
      ]),
      ?_section('In use', [
        for (final model in inUse) _modelRow(model, inUse: true),
      ]),
      ?_section('Downloaded', [
        for (final model in resting(library.downloaded))
          _modelRow(model, inUse: false),
      ]),
      ?_section('In your folders', [
        for (final model in resting(library.inFolders))
          _modelRow(model, inUse: false),
      ]),
    ]);
  }

  static PaneSection? _section(String title, List<PaneRow> rows) => rows.isEmpty
      ? null
      : PaneSection(title: title, count: rows.length, rows: rows);

  PaneContent _empty(LibraryStatus status) => PaneContent([
    PaneSection(
      notes: [
        const PaneNote.blank(),
        if (status case LibraryScanFailed(:final error))
          PaneNote([
            PaneSpan("Couldn't scan for models: $error", PaneTone.danger),
          ])
        else
          const PaneNote([
            PaneSpan('No local models yet.', PaneTone.emphasis),
          ]),
        const PaneNote([
          PaneSpan(
            'Download one from Hugging Face, or point bestie at a folder of '
            'GGUFs you already have.',
            PaneTone.muted,
          ),
        ]),
        const PaneNote.blank(),
      ],
      rows: [
        PaneRow(
          id: 'download',
          glyph: '↓',
          glyphTone: PaneTone.primary,
          label: 'Download a model',
          tint: PaneTint.primary,
          detail: const [
            PaneSpan('Search Hugging Face for GGUF models', PaneTone.muted),
          ],
          actions: [
            PaneAction.primary(
              label: 'Open',
              invoke: () async => PaneOpenCommand(downloadCommand),
            ),
          ],
        ),
        PaneRow(
          id: 'add-folder',
          glyph: '⊕',
          label: 'Add a model folder',
          detail: const [
            PaneSpan(
              'Bestie scans it and its subfolders for .gguf files',
              PaneTone.muted,
            ),
          ],
          actions: [
            PaneAction.primary(
              label: 'Open',
              invoke: () async => PaneOpenCommand(addFolderCommand),
            ),
          ],
        ),
      ],
    ),
  ]);

  static PaneSection? _downloadsNote(DownloadsStatus status) {
    final note = switch (status) {
      DownloadsStarting() || DownloadsReady() => null,
      DownloadsManagedElsewhere() =>
        'Another bestie window runs downloads; this one only shows them.',
      DownloadsLedgerSetAside(:final movedTo) =>
        'The download list was damaged and was set aside at $movedTo.',
      DownloadsLedgerUnreadable(:final reason) =>
        "Downloads are paused: the download list can't be read ($reason).",
      DownloadsLedgerNotSaved(:final reason) =>
        "Downloads run, but the download list couldn't be saved ($reason).",
    };
    return note == null
        ? null
        : PaneSection(
            rows: const [],
            notes: [
              PaneNote([PaneSpan('⚠ $note', PaneTone.warning)]),
            ],
          );
  }

  /// A download's row, whichever section the library put it in.
  PaneRow _downloadRow(ModelDownload download) => switch (download.status) {
    DownloadTransferringStatus(
      :final receivedBytes,
      :final speedBytesPerSecond,
    ) =>
      _rowFor(
        download,
        glyph: '◐',
        tone: PaneTone.loading,
        detail: [
          PaneSpan(
            '${bytesLabel(receivedBytes)} of '
            '${bytesLabel(download.totalBytes)}',
          ),
          if (speedBytesPerSecond case final speed? when speed > 0) ...[
            const PaneSpan(' · ', PaneTone.subtle),
            PaneSpan(speedLabel(speed), PaneTone.loading),
            const PaneSpan(' · ', PaneTone.subtle),
            PaneSpan(
              remainingLabel(
                Duration(
                  seconds: ((download.totalBytes - receivedBytes) / speed)
                      .round(),
                ),
              ),
              PaneTone.muted,
            ),
          ],
        ],
        progress: PaneFraction(_shareOf(download, receivedBytes)),
        actions: [_cancel(download)],
      ),
    DownloadVerifyingStatus() => _rowFor(
      download,
      glyph: '◉',
      tone: PaneTone.info,
      detail: const [PaneSpan('Verifying checksum…', PaneTone.info)],
      actions: [_cancel(download)],
    ),
    DownloadQueuedStatus(:final receivedBytes) => _rowFor(
      download,
      glyph: '◌',
      tone: PaneTone.muted,
      detail: [
        PaneSpan(
          receivedBytes == 0
              ? 'Queued'
              : 'Queued · ${_percentOf(download, receivedBytes)} kept',
          PaneTone.muted,
        ),
      ],
      actions: [_cancel(download)],
    ),
    DownloadInstalledStatus() => _rowFor(
      download,
      glyph: '✓',
      tone: PaneTone.success,
      detail: const [
        PaneSpan('Downloaded · adding it to the library…', PaneTone.muted),
      ],
      actions: const [],
    ),
    DownloadPausedStatus(:final receivedBytes) => _rowFor(
      download,
      glyph: '◑',
      tone: PaneTone.warning,
      detail: [
        PaneSpan(
          'Paused at ${_percentOf(download, receivedBytes)}',
          PaneTone.warning,
        ),
        const PaneSpan(' · ', PaneTone.subtle),
        const PaneSpan('[r] resumes where it stopped', PaneTone.muted),
      ],
      actions: [_resume(download, 'Resume'), _discard(download)],
    ),
    DownloadFailedStatus(reason: DownloadChecksumFailed(:final file)) =>
      _rowFor(
        download,
        glyph: '◑',
        tone: PaneTone.warning,
        detail: [
          PaneSpan("Checksum didn't match for $file", PaneTone.danger),
          const PaneSpan(' · ', PaneTone.subtle),
          const PaneSpan('[r] downloads it again', PaneTone.muted),
        ],
        actions: [_resume(download, 'Retry'), _discard(download)],
      ),
    DownloadFailedStatus(:final reason, :final receivedBytes) => _rowFor(
      download,
      glyph: '◑',
      tone: PaneTone.warning,
      detail: [
        PaneSpan(
          'Failed at ${_percentOf(download, receivedBytes)}: '
          '${reason.detail}',
          PaneTone.danger,
        ),
        const PaneSpan(' · ', PaneTone.subtle),
        const PaneSpan('[r] retries', PaneTone.muted),
      ],
      actions: [_resume(download, 'Retry'), _discard(download)],
    ),
    DownloadUnlistedStatus(:final reason) => _rowFor(
      download,
      glyph: '◑',
      tone: PaneTone.warning,
      detail: [
        PaneSpan(switch (reason) {
          UnlistedScanFailed(:final error) =>
            'Downloaded, but scanning for it failed: $error',
          UnlistedFileMissing() => 'Downloaded, but its file is gone',
        }, PaneTone.warning),
      ],
      actions: [_discard(download)],
    ),
  };

  static PaneRow _rowFor(
    ModelDownload download, {
    required String glyph,
    required PaneTone tone,
    required List<PaneSpan> detail,
    required List<PaneAction> actions,
    PaneProgress? progress,
  }) => PaneRow(
    id: download.id,
    glyph: glyph,
    glyphTone: tone,
    label: downloadName(download.repo),
    keywords: '${download.repo} ${download.quant}',
    trailing: [
      PaneSpan(
        '${download.quant} · ${bytesLabel(download.totalBytes)}',
        PaneTone.muted,
      ),
    ],
    detail: detail,
    progress: progress,
    actions: actions,
  );

  PaneAction _cancel(ModelDownload download) => PaneAction(
    key: const CharKey('x'),
    label: 'Cancel',
    danger: true,
    invoke: () async => switch (_operations.cancel(download.id)) {
      CancelRequested() => const PaneStay(),
      NothingToCancel() => const PaneRejected(
        'That download is no longer running',
      ),
    },
  );

  PaneAction _resume(ModelDownload download, String label) => PaneAction(
    key: const CharKey('r'),
    label: label,
    invoke: () async => switch (_operations.resume(download.id)) {
      ResumeQueued() => const PaneStay(),
      NothingToResume() => const PaneRejected(
        'That download is no longer waiting',
      ),
    },
  );

  PaneAction _discard(ModelDownload download) => PaneAction(
    key: const CharKey('x'),
    label: 'Discard',
    danger: true,
    invoke: () async => switch (await _operations.discard(download.id)) {
      DownloadDiscarded() || NothingToDiscard() => const PaneStay(),
      DiscardFailed(:final path, :final error) => PaneRejected(
        "Couldn't delete ${homePath(path, homeDir: _operations.homeDir)}: "
        '$error',
      ),
    },
  );

  PaneRow _modelRow(LocalModel model, {required bool inUse}) {
    final supported = model is SupportedModel;
    return PaneRow(
      id: model.id,
      glyph: switch (model) {
        SupportedModel() when inUse => '●',
        SupportedModel() => '○',
        UnsupportedModel() => '⊘',
      },
      glyphTone: inUse ? PaneTone.success : PaneTone.muted,
      label: model.displayName,
      labelTone: supported ? PaneTone.plain : PaneTone.muted,
      tint: inUse ? PaneTint.primary : PaneTint.none,
      keywords: '${model.displayName} ${model.path}',
      trailing: [
        PaneSpan(switch (model) {
          SupportedModel(:final quant, :final sizeBytes) =>
            '${quant.label} · ${bytesLabel(sizeBytes)}',
          UnsupportedModel(:final sizeBytes) => bytesLabel(sizeBytes),
        }, PaneTone.muted),
      ],
      detail: switch (model) {
        UnsupportedModel(:final reason) => [
          PaneSpan(unsupportedLabel(reason), PaneTone.warning),
        ],
        SupportedModel(source: DownloadedSource(:final repo)) => [
          PaneSpan('Downloaded from $repo', PaneTone.muted),
        ],
        SupportedModel(:final path) => [
          PaneSpan(
            homePath(path, homeDir: _operations.homeDir),
            PaneTone.muted,
          ),
        ],
      },
      actions: [
        if (inUse)
          PaneAction.primary(
            label: 'Using',
            invoke: () async => const PaneStay(),
          ),
        ...modelActions(_operations, model, inUse: inUse),
      ],
    );
  }

  static double _shareOf(ModelDownload download, int receivedBytes) =>
      download.totalBytes == 0 ? 0 : receivedBytes / download.totalBytes;

  static String _percentOf(ModelDownload download, int receivedBytes) =>
      '${(_shareOf(download, receivedBytes) * 100).round()}%';
}
