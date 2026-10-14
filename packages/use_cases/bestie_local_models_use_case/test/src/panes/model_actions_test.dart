import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/panes/delete_model_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/model_actions.dart';
import 'package:bestie_local_models_use_case/src/panes/model_details_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  late MockLocalModelsOperations operations;

  setUp(() {
    operations = MockLocalModelsOperations();
    stubOperations(operations);
  });

  List<String> keysOf(List<PaneAction> actions) => [
    for (final action in actions)
      switch (action.key) {
        PrimaryKey() => '↵ ${action.label}',
        CharKey(:final char) => '$char ${action.label}',
      },
  ];

  test('a downloaded model offers use, details and delete', () {
    expect(keysOf(modelActions(operations, supportedModel(), inUse: false)), [
      '↵ Use',
      'i Details',
      'd Delete',
    ]);
  });

  test('a model in use offers its details and deleting it', () {
    expect(keysOf(modelActions(operations, supportedModel(), inUse: true)), [
      'i Details',
      'd Delete',
    ]);
  });

  test('a model in your folders is never deleted by bestie', () {
    final folderModel = supportedModel(
      source: const ScannedSource(root: '$homeDir/models'),
    );
    expect(keysOf(modelActions(operations, folderModel, inUse: false)), [
      '↵ Use',
      'i Details',
    ]);
  });

  test('an unsupported model cannot be used', () {
    expect(keysOf(modelActions(operations, unsupportedModel(), inUse: false)), [
      'i Details',
    ]);
  });

  test('the use label can be reworded', () {
    expect(
      modelActions(
        operations,
        supportedModel(),
        inUse: false,
        useLabel: 'Use this model',
      ).first.label,
      'Use this model',
    );
  });

  test('use runs the app on the model and closes the palette', () async {
    when(() => operations.use('qwen3-8b')).thenReturn(const ModelPicked());
    final result = await useModelAction(operations, supportedModel()).invoke();
    expect(result, isA<PaneClose>());
  });

  test('use says why the model could not be picked', () async {
    when(
      () => operations.use('qwen3-8b'),
    ).thenReturn(const ModelPickRefused('turn in progress'));
    final result = await useModelAction(operations, supportedModel()).invoke();
    expect((result as PaneRejected).reason, 'turn in progress');
  });

  test('details opens the model details', () async {
    final result = await modelDetailsAction(
      operations,
      supportedModel(),
    ).invoke();
    expect((result as PanePush).pane, isA<ModelDetailsPane>());
    expect((result.pane as ModelDetailsPane).localId, 'qwen3-8b');
  });

  test('delete refuses the model the app runs on', () async {
    stubOperations(operations, inUseId: 'qwen3-8b');
    final result = await deleteModelAction(
      operations,
      supportedModel(),
    ).invoke();
    expect(
      (result as PaneRejected).reason,
      'Bestie is running Qwen 3 8B; switch to another model before deleting '
      'it',
    );
  });

  test('delete asks first', () async {
    final model = supportedModel();
    final action = deleteModelAction(operations, model);
    expect(action.danger, isTrue);
    final result = await action.invoke();
    expect(((result as PanePush).pane as DeleteModelPane).model, same(model));
  });
}
