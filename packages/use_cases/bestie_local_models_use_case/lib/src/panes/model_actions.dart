import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/panes/delete_model_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/model_details_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';

/// Enter on a model the app can run: run the app on it and close the
/// palette.
PaneAction useModelAction(
  LocalModelsOperations operations,
  SupportedModel model, {
  String label = 'Use',
}) => PaneAction.primary(
  label: label,
  invoke: () async => switch (operations.use(model.id)) {
    ModelPicked() => const PaneClose(),
    ModelPickRefused(:final reason) => PaneRejected(reason),
  },
);

/// `i`: everything bestie read from the model's GGUF.
PaneAction modelDetailsAction(
  LocalModelsOperations operations,
  LocalModel model,
) => PaneAction(
  key: const CharKey('i'),
  label: 'Details',
  invoke: () async =>
      PanePush(ModelDetailsPane(operations: operations, localId: model.id)),
);

/// `d`: asks before deleting a model bestie downloaded, unless the app is
/// running on it.
PaneAction deleteModelAction(
  LocalModelsOperations operations,
  LocalModel model,
) => PaneAction(
  key: const CharKey('d'),
  label: 'Delete',
  danger: true,
  invoke: () async => operations.inUseId == model.id
      ? PaneRejected(inUseRefusal(model))
      : PanePush(DeleteModelPane(operations: operations, model: model)),
);

/// Why [model] can't be deleted while the app runs on it.
String inUseRefusal(LocalModel model) =>
    'Bestie is running ${model.displayName}; switch to another model before '
    'deleting it';

/// The actions a listed model offers: using it when it can run and isn't
/// already in use, its details, and deleting it when bestie downloaded it.
List<PaneAction> modelActions(
  LocalModelsOperations operations,
  LocalModel model, {
  required bool inUse,
  String useLabel = 'Use',
}) => [
  if (model case final SupportedModel supported when !inUse)
    useModelAction(operations, supported, label: useLabel),
  modelDetailsAction(operations, model),
  if (model.source is DownloadedSource) deleteModelAction(operations, model),
];
