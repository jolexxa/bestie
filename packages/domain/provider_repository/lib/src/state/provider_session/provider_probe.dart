import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind, InferenceProtocolId;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/models/resolved_model.dart';
import 'package:provider_repository/src/state/provider_session/provider_connection.dart';

/// What probing a provider with the user's settings found.
@model
sealed class ProbeOutcome {
  const ProbeOutcome();
}

/// The provider accepted the key and offers the model.
@model
final class ProbeSucceeded extends ProbeOutcome {
  const ProbeSucceeded({required this.model, required this.keyInfo});

  final ResolvedModel model;

  /// Null when the provider has no key metadata to offer.
  final ProviderKeyInfo? keyInfo;
}

/// The provider cannot be used with the current settings.
@model
final class ProbeFailed extends ProbeOutcome {
  const ProbeFailed(this.failure);

  final ProviderFailure failure;
}

/// Checks that [connection] speaks the protocol we run, accepts its key,
/// and lists [model], settling the model's facts from that listing.
Future<ProbeOutcome> probeProvider(
  ProviderConnection connection, {
  required ProviderModelRef model,
}) async {
  final provider = connection.provider;
  if (!provider.endpoints.containsKey(InferenceProtocolId.openAiCompat)) {
    return ProbeFailed(
      ProviderFailure(
        kind: InferenceFailureKind.badRequest,
        message:
            '${provider.displayName} offers no OpenAI-compatible endpoint.',
      ),
    );
  }
  final keyInfo = switch (await provider.keyInfo()) {
    KeyInfoFailed(:final failure) => failure,
    KeyInfoFetched(:final keyInfo) => keyInfo,
    KeyInfoUnsupported() => null,
  };
  if (keyInfo is ProviderFailure) return ProbeFailed(keyInfo);
  return switch (await connection.models) {
    ProviderModelsFailed(:final failure) => ProbeFailed(failure),
    ProviderModelsListed(:final models) => _resolve(
      connection,
      model: model,
      listed: models,
      keyInfo: keyInfo as ProviderKeyInfo?,
    ),
  };
}

ProbeOutcome _resolve(
  ProviderConnection connection, {
  required ProviderModelRef model,
  required List<ProviderModel> listed,
  required ProviderKeyInfo? keyInfo,
}) {
  final displayName = connection.provider.displayName;
  final entry = listed.where((entry) => entry.id == model.modelId).firstOrNull;
  if (entry == null) {
    return ProbeFailed(
      ProviderFailure(
        kind: InferenceFailureKind.badRequest,
        message: 'Model "${model.modelId}" is not offered by $displayName.',
      ),
    );
  }
  final contextWindow =
      entry.contextLength ?? connection.account.fallbackContextWindow;
  if (contextWindow == null) {
    return ProbeFailed(
      ProviderFailure(
        kind: InferenceFailureKind.malformedResponse,
        message:
            '$displayName did not report a context window for '
            '"${model.modelId}".',
      ),
    );
  }
  return ProbeSucceeded(
    model: ResolvedModel(
      ref: model,
      name: entry.name,
      contextWindow: contextWindow,
      supportsTools: entry.supportsTools,
      reasoning: entry.reasoning,
    ),
    keyInfo: keyInfo,
  );
}
