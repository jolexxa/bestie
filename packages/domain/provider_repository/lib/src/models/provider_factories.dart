import 'package:agent_provider_protocol/agent_provider_protocol.dart'
    show AgentProvider;
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceClient, InferenceEndpoint;
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart' show Provider;
import 'package:provider_repository/src/models/provider_account.dart';

/// Builds the hosted provider for a usable account.
typedef ProviderFactory = Provider Function(ProviderAccount account);

/// Builds an inference client for one of a provider's endpoints.
typedef InferenceClientFactory =
    InferenceClient Function(InferenceEndpoint endpoint);

/// Builds the agent provider that runs agents over an inference client.
typedef RemoteAgentProviderSpawner =
    AgentProvider Function({
      required InferenceClient client,
      required String modelId,
      required int contextWindow,
      required int maxAgents,
    });

/// The concrete pieces the session assembles, injected so the repository
/// never names a data source.
@model
final class ProviderSessionFactories {
  const ProviderSessionFactories({
    required this.providerFactory,
    required this.inferenceClientFactory,
    required this.agentProviderSpawner,
  });

  final ProviderFactory providerFactory;
  final InferenceClientFactory inferenceClientFactory;
  final RemoteAgentProviderSpawner agentProviderSpawner;
}
