import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/panes/model_actions.dart';
import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';

/// Asks before deleting a downloaded model's files; Enter deletes and goes
/// back, Esc keeps them.
@PartOf(LocalModelsUseCase)
class DeleteModelPane extends Pane {
  DeleteModelPane({
    required LocalModelsOperations operations,
    required this.model,
  }) : _operations = operations;

  final LocalModelsOperations _operations;

  final LocalModel model;

  @override
  String get title => 'Delete ${model.displayName}';

  @override
  PaneFilter get filter => PaneFilter.none;

  @override
  Stream<PaneStatus?> get status => Stream.value(
    const PaneStatus(
      spans: [PaneSpan('⚠ Enter to delete · Esc to cancel', PaneTone.danger)],
    ),
  );

  @override
  Stream<PaneContent> content(String query) => Stream.value(
    PaneContent([
      PaneSection(
        notes: [
          const PaneNote.blank(),
          PaneNote([
            const PaneSpan('This frees '),
            PaneSpan(bytesLabel(model.sizeBytes), PaneTone.emphasis),
            const PaneSpan(' by deleting'),
          ]),
          PaneNote([
            PaneSpan(
              homePath(model.path, homeDir: _operations.homeDir),
              PaneTone.muted,
            ),
          ]),
          const PaneNote.blank(),
          const PaneNote([
            PaneSpan(
              'You can download it again from Download models at any time.',
              PaneTone.muted,
            ),
          ]),
          const PaneNote.blank(),
        ],
        rows: [
          PaneRow(
            id: model.id,
            glyph: '✕',
            glyphTone: PaneTone.danger,
            label: 'Delete ${model.displayName}',
            labelTone: PaneTone.danger,
            actions: [
              PaneAction.primary(
                label: 'Delete',
                danger: true,
                invoke: _delete,
              ),
            ],
          ),
        ],
      ),
    ]),
  );

  Future<PaneActionResult> _delete() async {
    if (_operations.inUseId == model.id) {
      return PaneRejected(inUseRefusal(model));
    }
    return switch (await _operations.delete(model.id)) {
      ModelDeleted() || NothingToDelete() => const PanePop(),
      DeleteRefusedScanned(:final root) => PaneRejected(
        'Bestie never deletes files in your folders; remove '
        '${homePath(root, homeDir: _operations.homeDir)} from your model '
        'folders to hide it',
      ),
      DeleteRefusedUntracked() => const PaneRejected(
        "Bestie didn't download this file, so it leaves deleting it to you",
      ),
      DeleteRefusedReadOnly() => PaneRejected(
        downloadsUnavailableReason(
          _operations.currentLibrary.downloadsStatus,
        ),
      ),
      DeleteFailed(:final path, :final error) => PaneRejected(
        "Couldn't delete ${homePath(path, homeDir: _operations.homeDir)}: "
        '$error',
      ),
    };
  }
}
