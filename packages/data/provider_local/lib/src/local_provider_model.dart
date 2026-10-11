import 'package:agent_runtime/agent_runtime.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/bestie_server_dialect.dart';
import 'package:provider_local/src/local_agent_sessions.dart';
import 'package:provider_local/src/local_connection.dart';
import 'package:provider_local/src/local_server_link.dart';
import 'package:provider_local/src/models/local_server_connection.dart';
import 'package:provider_local/src/server_api.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// A model the local server loaded for this bestie, served over the owner
/// session it was loaded on.
@PartOf(LocalConnection)
final class LocalProviderModel implements ProviderModel {
  LocalProviderModel({
    required LocalServerLink link,
    required int generation,
    required LocalServerAttached attached,
    required ModelReady ready,
    required String modelId,
  }) : _link = link,
       _generation = generation,
       contextWindow = ready.contextSize,
       maxAgents = ready.maxAgents,
       deviceBytes = ready.deviceBytes,
       runtime = CompletionAgentRuntime(
         client: OpenAiCompletionClient(
           baseUrl: ServerApi.urlFor(attached.port, '/v1'),
           headers: {bestieOwnerHeader: attached.ownerToken},
           dialect: const BestieServerDialect(),
           clientFactory: http.Client.new,
         ),
         sessions: LocalAgentSessions(link: link),
         options: AgentRuntimeOptions(
           modelId: modelId,
           contextWindow: ready.contextSize,
           maxAgents: ready.maxAgents,
         ),
       ),
       lost = link.untilDetached();

  final LocalServerLink _link;
  final int _generation;

  @override
  final int contextWindow;

  @override
  final int maxAgents;

  @override
  final int deviceBytes;

  @override
  final AgentRuntime runtime;

  @override
  final Future<void> lost;

  /// Hands the server back so another bestie can use it, unless a newer
  /// load already took it over.
  @override
  Future<void> release() async {
    await runtime.dispose();
    await _link.releaseLoad(_generation);
  }
}
