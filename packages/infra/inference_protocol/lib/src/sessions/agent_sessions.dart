import 'package:inference_protocol/src/models/agent_identity.dart';
import 'package:inference_protocol/src/sessions/agent_pool_report.dart';
import 'package:inference_protocol/src/sessions/agent_session_result.dart';

/// The per-agent sessions an inference endpoint holds alongside its
/// completions.
abstract interface class AgentSessions {
  /// Asks the endpoint to hold a session for [agent]. Never throws.
  Future<AgentSessionResult> open(AgentIdentity agent);

  /// Releases the session held for [agent].
  Future<void> close(AgentIdentity agent);

  /// How the endpoint divides its context, reported whenever that changes.
  Stream<AgentPoolReport> get pool;

  /// Releases everything the sessions hold and ends [pool].
  Future<void> dispose();
}
