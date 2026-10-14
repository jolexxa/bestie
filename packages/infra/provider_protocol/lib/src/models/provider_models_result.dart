import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_model_info.dart';

/// The outcome of asking a provider which models it lists.
sealed class ProviderModelsResult {
  const ProviderModelsResult();
}

final class ProviderModelsListed extends ProviderModelsResult {
  const ProviderModelsListed(this.models);

  final List<ProviderModelInfo> models;
}

final class ProviderModelsFailed extends ProviderModelsResult {
  const ProviderModelsFailed(this.failure);

  final ProviderFailure failure;
}
