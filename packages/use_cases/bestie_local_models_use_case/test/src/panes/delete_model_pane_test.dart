import 'package:bestie_local_models_use_case/src/panes/delete_model_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  late MockLocalModelsOperations operations;
  final model = supportedModel(
    displayName: 'Gemma 4 26B-A4B Instruct',
    path: '$homeDir/.bestie/models/gemma-4-26b-a4b-it-q4_k_m-91be0c44.gguf',
    sizeBytes: 15640000000,
  );

  setUp(() {
    operations = MockLocalModelsOperations();
    stubOperations(operations);
  });

  DeleteModelPane pane() =>
      DeleteModelPane(operations: operations, model: model);

  test('names the model it deletes and has no filter', () {
    expect(pane().title, 'Delete Gemma 4 26B-A4B Instruct');
    expect(pane().filter, PaneFilter.none);
  });

  test('says Enter deletes and Esc cancels', () async {
    final band = await pane().status.single;
    expect(spansText(band!.spans), '⚠ Enter to delete · Esc to cancel');
    expect(band.spans.single.tone, PaneTone.danger);
  });

  test('says what it frees, where, and that it can come back', () async {
    final content = await pane().content('').single;
    final section = content.sections.single;
    expect(section.notes.map(noteText), [
      '',
      'This frees 15.64 GB by deleting',
      '~/.bestie/models/gemma-4-26b-a4b-it-q4_k_m-91be0c44.gguf',
      '',
      'You can download it again from Download models at any time.',
      '',
    ]);
    final row = section.rows.single;
    expect(row.glyph, '✕');
    expect(row.label, 'Delete Gemma 4 26B-A4B Instruct');
    expect(actionOf(row, const PrimaryKey()).danger, isTrue);
  });

  Future<PaneActionResult> deleting(DeleteModelResult result) async {
    when(() => operations.delete(model.id)).thenAnswer((_) async => result);
    final content = await pane().content('').single;
    return actionOf(content.rows.single, const PrimaryKey()).invoke();
  }

  test('goes back once the model is gone', () async {
    expect(await deleting(const ModelDeleted(freedBytes: 1)), isA<PanePop>());
    expect(await deleting(const NothingToDelete()), isA<PanePop>());
  });

  test('refuses the model the app runs on without deleting it', () async {
    stubOperations(operations, inUseId: model.id);
    final content = await pane().content('').single;

    final result = await actionOf(
      content.rows.single,
      const PrimaryKey(),
    ).invoke();

    expect(
      (result as PaneRejected).reason,
      'Bestie is running Gemma 4 26B-A4B Instruct; switch to another model '
      'before deleting it',
    );
    verifyNever(() => operations.delete(any()));
  });

  test('says why it would not delete', () async {
    Future<String> reasonFor(DeleteModelResult result) async =>
        (await deleting(result) as PaneRejected).reason;

    expect(
      await reasonFor(const DeleteRefusedScanned(root: '$homeDir/models')),
      'Bestie never deletes files in your folders; remove ~/models from your '
      'model folders to hide it',
    );
    expect(
      await reasonFor(const DeleteRefusedUntracked(path: '/x')),
      "Bestie didn't download this file, so it leaves deleting it to you",
    );
    expect(
      await reasonFor(
        const DeleteFailed(path: '$homeDir/a.gguf', error: 'EPERM'),
      ),
      "Couldn't delete ~/a.gguf: EPERM",
    );
    when(() => operations.currentLibrary).thenReturn(
      ModelLibrary.loading,
    );
    expect(
      await reasonFor(const DeleteRefusedReadOnly()),
      'Downloads are still starting up',
    );
  });
}
