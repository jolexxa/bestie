import 'dart:async';

import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';

/// One repo's quants that bestie can run, each with its size, quality and
/// how well it fits this machine. Enter queues a download and stays.
@PartOf(LocalModelsUseCase)
class QuantPane extends Pane {
  QuantPane({required LocalModelsOperations operations, required this.repo})
    : _operations = operations;

  final LocalModelsOperations _operations;

  final RepoSummary repo;

  late final Future<RepoResolution> _resolution = _operations.resolve(
    repo.repo,
  );

  /// Cells the size bar spans.
  static const barWidth = 18;

  static const List<PaneColumn> _columns = [
    PaneColumn(title: 'Quant', width: 10),
    PaneColumn(title: 'Size', width: 9, align: PaneAlign.end),
    PaneColumn(title: 'Quality', width: 10),
    PaneColumn(title: 'Fit', width: 10),
    PaneColumn(),
  ];

  @override
  String get title => repo.name;

  @override
  PaneFilter get filter => PaneFilter.none;

  @override
  String get backLabel => 'Back to results';

  @override
  Stream<PaneStatus?> get status => Stream.multi((controller) {
    controller.add(_band(const []));
    unawaited(
      _resolution.then((resolution) {
        if (resolution case final RepoResolved resolved) {
          controller.add(_band(_factsOf(resolved)));
        }
        return controller.close();
      }),
    );
  });

  @override
  Stream<PaneContent> content(String query) =>
      Stream<PaneContent>.multi((controller) {
        StreamSubscription<PaneContent>? listing;
        var cancelled = false;
        controller.add(_reading);
        unawaited(
          _resolution.then((resolution) {
            if (cancelled) return;
            listing = _operations.library
                .map((library) => _contentOf(resolution, library))
                .listen(controller.add);
          }),
        );
        controller.onCancel = () {
          cancelled = true;
          return listing?.cancel();
        };
      });

  PaneStatus _band(List<PaneSpan> facts) => PaneStatus(
    spans: [PaneSpan(repo.owner, PaneTone.muted), ...facts],
  );

  List<PaneSpan> _factsOf(RepoResolved resolved) => [
    for (final fact in [
      if (resolved.architecture case final architecture?)
        PaneSpan(architecture, PaneTone.info),
      if (resolved.parameterCount case final count?)
        PaneSpan('${parametersLabel(count)} params', PaneTone.info),
      if (resolved.contextLength case final context?)
        PaneSpan('${contextLabel(context)} context', PaneTone.muted),
    ]) ...[const PaneSpan(' · ', PaneTone.subtle), fact],
  ];

  static const _reading = PaneContent([
    PaneSection(
      rows: [],
      notes: [
        PaneNote.blank(),
        PaneNote([
          PaneSpan('∷ ', PaneTone.secondary),
          PaneSpan('Reading the repo and its GGUF files…'),
        ]),
        PaneNote([
          PaneSpan(
            '  Checking which quants this machine can run',
            PaneTone.muted,
          ),
        ]),
      ],
    ),
  ]);

  PaneContent _contentOf(RepoResolution resolution, ModelLibrary library) =>
      switch (resolution) {
        RepoResolved(:final quants) => PaneContent([
          PaneSection(
            columns: _columns,
            rows: [for (final quant in quants) _rowOf(quant, library)],
          ),
        ]),
        RepoNotFound(:final repo) => _failed(
          "Hugging Face has no repo called $repo, or it's private.",
          const [],
        ),
        RepoLookupFailed(:final message) => _failed(
          "Couldn't read the repo from Hugging Face.",
          [
            PaneNote([PaneSpan('  $message', PaneTone.muted)]),
          ],
        ),
        RepoUnrunnable(:final reason) => _failed(
          "There's nothing in this repo bestie can run yet.",
          unrunnableNotes(reason),
        ),
      };

  static PaneContent _failed(String headline, List<PaneNote> explanation) =>
      PaneContent([
        PaneSection(
          rows: const [],
          notes: [
            const PaneNote.blank(),
            PaneNote([
              const PaneSpan('✕ ', PaneTone.danger),
              PaneSpan(headline, PaneTone.danger),
            ]),
            if (explanation.isNotEmpty) const PaneNote.blank(),
            ...explanation,
          ],
        ),
      ]);

  PaneRow _rowOf(RepoQuant quant, ModelLibrary library) {
    final memory = _operations.memoryBytes;
    final standing = _standingOf(quant, library);
    final share = quant.sizeBytes / (memory * ModelFit.tightShare);
    final filled = (barWidth * share).round().clamp(1, barWidth);
    final tier = tierSpan(quant.tier);
    return PaneRow(
      id: quant.downloadId,
      label: quant.label,
      labelTone: standing == null ? PaneTone.plain : PaneTone.muted,
      cells: [
        [
          PaneSpan(
            bytesLabel(quant.sizeBytes),
            standing == null ? PaneTone.plain : PaneTone.muted,
          ),
        ],
        [if (standing == null) tier else PaneSpan(tier.text, PaneTone.muted)],
        [
          standing ??
              fitSpan(
                ModelFit.estimate(
                  modelBytes: quant.sizeBytes,
                  availableBytes: memory,
                ),
              ),
        ],
        [
          PaneSpan('━' * filled, standing == null ? tier.tone : PaneTone.muted),
          PaneSpan('─' * (barWidth - filled), PaneTone.subtle),
        ],
      ],
      actions: [
        if (standing == null)
          PaneAction.primary(
            label: 'Download',
            invoke: () => _download(quant),
          ),
      ],
    );
  }

  /// Where the library already has [quant], or null when it doesn't.
  static PaneSpan? _standingOf(RepoQuant quant, ModelLibrary library) {
    final downloaded = {
      for (final model in library.downloaded)
        if (model.source case DownloadedSource(:final downloadId)) downloadId,
    };
    final queued = {
      for (final download in [
        ...library.downloading,
        ...library.needsAttention,
      ])
        download.id,
    };
    return switch (quant.downloadId) {
      final id when downloaded.contains(id) => const PaneSpan(
        'installed',
        PaneTone.muted,
      ),
      final id when queued.contains(id) => const PaneSpan(
        'queued',
        PaneTone.loading,
      ),
      _ => null,
    };
  }

  Future<PaneActionResult> _download(RepoQuant quant) async =>
      switch (await _operations.download(quant)) {
        DownloadAccepted() || DownloadAlreadyQueued() => const PaneStay(),
        DownloadTargetOccupied(:final path) => PaneRejected(
          "A file bestie didn't download is already at "
          '${homePath(path, homeDir: _operations.homeDir)}',
        ),
        DownloadRejected(:final reason) => PaneRejected(switch (reason) {
          InvalidRepoId(:final repo) => '$repo is not a repo bestie can fetch',
          InvalidFilePath(:final path) => '$path would land outside the repo',
          NoDownloadFiles() => 'This quant has no files to download',
        }),
        DownloadsUnavailable() => PaneRejected(
          downloadsUnavailableReason(
            _operations.currentLibrary.downloadsStatus,
          ),
        ),
      };
}
