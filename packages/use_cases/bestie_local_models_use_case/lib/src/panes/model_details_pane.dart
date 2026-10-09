import 'dart:async';

import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/panes/model_actions.dart';
import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Everything bestie read from one model's GGUF header, where the file came
/// from, and how the server runs it.
@PartOf(LocalModelsUseCase)
class ModelDetailsPane extends Pane {
  ModelDetailsPane({
    required LocalModelsOperations operations,
    required this.localId,
  }) : _operations = operations;

  final LocalModelsOperations _operations;

  final String localId;

  static const List<PaneColumn> _columns = [
    PaneColumn(width: 16),
    PaneColumn(),
  ];

  @override
  String get title =>
      _operations.currentLibrary.modelById(localId)?.displayName ?? localId;

  @override
  PaneFilter get filter => PaneFilter.none;

  @override
  Stream<PaneStatus?> get status =>
      Rx.combineLatest2(_operations.inUseIds, _operations.server, _bandOf);

  @override
  Stream<PaneContent> content(String query) => Rx.combineLatest2(
    _operations.library,
    _operations.inUseIds,
    (library, running) => switch (library.modelById(localId)) {
      null => const PaneContent([
        PaneSection(
          rows: [],
          notes: [
            PaneNote.blank(),
            PaneNote([
              PaneSpan(
                'This model is no longer in the library.',
                PaneTone.muted,
              ),
            ]),
          ],
        ),
      ]),
      final model => PaneContent([
        PaneSection(
          columns: _columns,
          rows: _rowsOf(model, inUse: running == localId),
        ),
      ]),
    },
  );

  PaneStatus? _bandOf(String? running, LocalServerStatus server) =>
      switch (server) {
        _ when running != localId => null,
        ServerServing(
          localId: final loaded,
          :final contextSize,
          :final maxAgents,
          :final deviceBytes,
        )
            when loaded == localId =>
          PaneStatus(
            glyph: '●',
            glyphTone: PaneTone.success,
            spans: [
              const PaneSpan('In use', PaneTone.success),
              const PaneSpan(' · fitted to ', PaneTone.muted),
              PaneSpan('ctx ${groupedLabel(contextSize)}', PaneTone.info),
              PaneSpan(
                ' with $maxAgents agents · ${bytesLabel(deviceBytes)} on the '
                'device',
                PaneTone.muted,
              ),
            ],
          ),
        _ => const PaneStatus(
          glyph: '●',
          glyphTone: PaneTone.success,
          spans: [PaneSpan('In use', PaneTone.success)],
        ),
      };

  List<PaneRow> _rowsOf(LocalModel model, {required bool inUse}) {
    final actions = modelActions(
      _operations,
      model,
      inUse: inUse,
      useLabel: 'Use this model',
    ).where((action) => action.key != const CharKey('i')).toList();
    final facts = <String, PaneSpan>{
      'Name': PaneSpan(model.displayName),
      'File': PaneSpan(
        homePath(model.path, homeDir: _operations.homeDir),
        PaneTone.muted,
      ),
      'Source': PaneSpan(_sourceOf(model.source)),
      ...switch (model) {
        final SupportedModel supported => _supportedFacts(supported),
        UnsupportedModel(:final reason, :final sizeBytes) => {
          'Size': PaneSpan(bytesLabel(sizeBytes)),
          'Problem': PaneSpan(unsupportedLabel(reason), PaneTone.warning),
        },
      },
      'Fingerprint': PaneSpan(model.fingerprint),
    };
    return [
      for (final MapEntry(key: label, :value) in facts.entries)
        PaneRow(
          id: label,
          label: label,
          labelTone: PaneTone.secondary,
          cells: [
            [value],
          ],
          actions: actions,
        ),
    ];
  }

  static Map<String, PaneSpan> _supportedFacts(SupportedModel model) => {
    'Architecture': PaneSpan(
      '${model.architecture} → ${model.profile.displayName} prompt format',
    ),
    if (model.parameterCount case final count?)
      'Parameters': PaneSpan(parametersLabel(count), PaneTone.info),
    'Quant': PaneSpan(
      '${model.quant.label} · ${bytesLabel(model.sizeBytes)}',
    ),
    'Trained context': PaneSpan('${groupedLabel(model.contextLength)} tokens'),
    'Reasoning': PaneSpan(reasoningLabel(model.reasoning)),
    if (samplingLabel(model.sampling) case final sampling?)
      'Sampling': PaneSpan(sampling),
  };

  String _sourceOf(ModelSource source) => switch (source) {
    DownloadedSource(:final repo) => 'Hugging Face · $repo',
    ScannedSource(:final root) =>
      'Your folder · ${homePath(root, homeDir: _operations.homeDir)}',
    UntrackedSource() => "Bestie's models folder · not downloaded by bestie",
  };
}
