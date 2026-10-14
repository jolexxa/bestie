import 'package:agent_runtime/agent_runtime.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:built_in_server_client/src/bestie_server_dialect.dart';
import 'package:built_in_server_client/src/built_in_agent_sessions.dart';
import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/built_in_server_link.dart';
import 'package:built_in_server_client/src/disconnect_wording.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/server_api.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// A model the local server loaded for this bestie, served over the owner
/// session it was loaded on.
@PartOf(BuiltInServerClient)
final class BuiltInServerModel implements ProviderModel {
  BuiltInServerModel({
    required BuiltInServerLink link,
    required int generation,
    required BuiltInServerAttached attached,
    required ModelReady ready,
    required String modelId,
    required DisconnectWording wording,
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
         sessions: BuiltInAgentSessions(link: link),
         options: AgentRuntimeOptions(
           modelId: modelId,
           contextWindow: ready.contextSize,
           maxAgents: ready.maxAgents,
         ),
       ),
       lost = link.untilDetached().then(wording.failureFor);

  final BuiltInServerLink _link;
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
  final Future<ProviderFailure> lost;

  /// Frees the model's memory, keeping the server, unless a newer load
  /// already took it over.
  @override
  Future<void> release() async {
    await runtime.dispose();
    await _link.unload(_generation);
  }
}
