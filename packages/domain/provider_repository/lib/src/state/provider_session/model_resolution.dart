import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/models/resolved_model.dart';

/// What looking up the chosen model in its provider's listing found.
@model
sealed class ModelResolution {
  const ModelResolution();

  /// Finds [model] in what [client] lists and settles its facts.
  static Future<ModelResolution> of(
    ProviderModelRef model, {
    required ProviderClient client,
    required String providerName,
  }) async => switch (await client.models()) {
    ProviderModelsFailed(:final failure) => ModelUnresolved(failure),
    ProviderModelsListed(:final models) => _find(
      model,
      models,
      providerName: providerName,
    ),
  };

  static ModelResolution _find(
    ProviderModelRef model,
    List<ProviderModelInfo> listed, {
    required String providerName,
  }) {
    final entry = listed
        .where((entry) => entry.id == model.modelId)
        .firstOrNull;
    if (entry == null) {
      return ModelUnresolved(
        ProviderRejected(
          'Model "${model.modelId}" is not offered by $providerName.',
        ),
      );
    }
    final contextWindow = entry.contextLength;
    if (contextWindow == null) {
      return ModelUnresolved(
        ProviderResponseMalformed(
          '$providerName did not report a context window for '
          '"${model.modelId}".',
        ),
      );
    }
    return ModelFound(
      ResolvedModel(
        ref: model,
        name: entry.name,
        providerName: providerName,
        contextWindow: contextWindow,
        supportsTools: entry.supportsTools,
        reasoning: entry.reasoning,
      ),
    );
  }
}

/// The provider lists the model with everything an agent needs.
@model
final class ModelFound extends ModelResolution {
  const ModelFound(this.model);

  final ResolvedModel model;
}

/// The model cannot run as chosen.
@model
final class ModelUnresolved extends ModelResolution {
  const ModelUnresolved(this.failure);

  final ProviderFailure failure;
}
