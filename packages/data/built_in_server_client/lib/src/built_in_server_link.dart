import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// What a loaded model and its agent sessions need of the link to the
/// server.
@PartOf(BuiltInServerClient)
abstract interface class BuiltInServerLink {
  /// Completes with why once this bestie stops holding the session it
  /// holds now, whether it let go, the server ended the session, or the
  /// connection closed; at once when it holds none.
  Future<DisconnectCause> untilDetached();

  Stream<PoolSnapshotEvent> get poolSnapshots;

  /// Unloads the model, keeping the server, unless a load newer than the
  /// [generation]th has started since, which then owns it.
  Future<void> unload(int generation);

  /// Opens a lease for [agent] on behalf of [holder]. A lease another
  /// holder still has under the same id is closed first.
  Future<AgentSessionResult> openLease(Object holder, AgentIdentity agent);

  /// Closes the lease of [agentId] if [holder] is the one holding it.
  Future<void> closeLease(Object holder, String agentId);

  /// Closes every lease [holder] still has.
  Future<void> releaseLeases(Object holder);
}
