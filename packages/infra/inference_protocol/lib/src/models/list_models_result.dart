import 'package:inference_protocol/src/models/inference_failure.dart';
import 'package:inference_protocol/src/models/inference_model.dart';

/// The outcome of asking an endpoint which models it serves.
sealed class ListModelsResult {
  const ListModelsResult();
}

final class ModelsListed extends ListModelsResult {
  const ModelsListed(this.models);

  final List<InferenceModel> models;
}

final class ModelsListFailed extends ListModelsResult {
  const ModelsListFailed(this.failure);

  final InferenceFailure failure;
}
