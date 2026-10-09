import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// What the provider and the agent sessions need of the link to the server.
@PartOf(LocalInferenceClient)
abstract interface class LocalServerLink {
  /// Completes once this bestie stops holding the session it holds now,
  /// whether it let go, the server ended the session, or the client closed;
  /// at once when it holds none.
  Future<void> untilDetached();

  Stream<ModelStatus> get modelStatusChanges;

  Stream<PoolSnapshotEvent> get poolSnapshots;

  Future<LocalServerConnection> attach();

  Future<ModelLoadResult> load(ModelLoadRequest request);

  /// Unloads the model and hangs up the owner session, if this bestie holds
  /// it, and forgets why the last attempt to hold it failed.
  Future<void> release();

  /// Opens a lease for [agent] on behalf of [holder]. A lease another
  /// holder still has under the same id is closed first.
  Future<AgentSessionResult> openLease(Object holder, AgentIdentity agent);

  /// Closes the lease of [agentId] if [holder] is the one holding it.
  Future<void> closeLease(Object holder, String agentId);

  /// Closes every lease [holder] still has.
  Future<void> releaseLeases(Object holder);
}
