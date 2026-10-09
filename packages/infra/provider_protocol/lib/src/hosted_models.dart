import 'package:inference_protocol/inference_protocol.dart';
import 'package:provider_protocol/src/models/model_activation.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/provider.dart';

/// Models served on demand by a hosted endpoint: there is nothing to load,
/// the listing changes only when it is fetched again, and every agent gets a
/// context window of its own.
mixin HostedModels implements Provider {
  /// Where each protocol's completions are served.
  Map<InferenceProtocolId, InferenceEndpoint> get endpoints;

  @override
  Set<InferenceProtocolId> get protocols => endpoints.keys.toSet();

  @override
  Stream<void> get modelsChanged => const Stream.empty();

  @override
  ModelActivation activate(ModelActivationRequest request) => ModelActivation(
    progress: const Stream.empty(),
    result: Future.value(switch (endpoints[request.protocol]) {
      final endpoint? => ModelActivated(
        contextWindow: request.contextWindow,
        endpoint: endpoint,
      ),
      null => ModelActivationFailed(
        ProviderFailure(
          kind: InferenceFailureKind.badRequest,
          message: '$displayName offers no ${request.protocol.name} endpoint.',
        ),
      ),
    }),
  );

  @override
  AgentSessions openSessions({required int contextWindow}) =>
      PerAgentWindowSessions(contextWindow: contextWindow);

  @override
  Future<void> deactivate() async {}
}
