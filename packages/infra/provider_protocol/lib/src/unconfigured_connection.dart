import 'package:provider_protocol/src/models/credits_result.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_model_load.dart';
import 'package:provider_protocol/src/models/provider_model_load_request.dart';
import 'package:provider_protocol/src/models/provider_models_result.dart';
import 'package:provider_protocol/src/provider_connection.dart';

/// A provider the user has not given what it needs yet: it lists nothing,
/// and everything else fails with [failure].
final class UnconfiguredConnection implements ProviderConnection {
  const UnconfiguredConnection(this.failure);

  /// What the user still has to set.
  final ProviderFailure failure;

  @override
  Future<ProviderModelsResult> models() async => const ProviderModelsListed([]);

  @override
  Future<CreditsResult> credits() async => CreditsFailed(failure);

  @override
  ProviderModelLoad load(ProviderModelLoadRequest request) =>
      ProviderModelLoad.settled(ProviderModelLoadFailed(failure));

  @override
  Future<void> close() async {}
}
