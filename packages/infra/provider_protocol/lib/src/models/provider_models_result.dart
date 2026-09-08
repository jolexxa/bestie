import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_model.dart';

/// The outcome of asking a provider for its model catalog.
sealed class ProviderModelsResult {
  const ProviderModelsResult();
}

final class ProviderModelsListed extends ProviderModelsResult {
  const ProviderModelsListed(this.models);

  final List<ProviderModel> models;
}

final class ProviderModelsFailed extends ProviderModelsResult {
  const ProviderModelsFailed(this.failure);

  final ProviderFailure failure;
}
