import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/server_api.dart';

/// The agent leases held over one owner session, and which holder holds
/// each. They go with the session, since the server frees every lease when
/// it ends. Requests reach the server in the order they were made, so a
/// lease handed from one holder to another is closed before it is opened
/// again.
@PartOf(LocalInferenceClient)
final class SessionLeases {
  SessionLeases({required ServerApi api, required LocalServerAttached owner})
    : _api = api,
      _owner = owner;

  final ServerApi _api;
  final LocalServerAttached _owner;
  final Map<String, Object> _holders = {};
  Future<void> _requests = Future.value();

  /// Opens a lease for [agent] on behalf of [holder], first closing one
  /// another holder still has under the same id.
  Future<AgentSessionResult> open(Object holder, AgentIdentity agent) =>
      _inOrder(() async {
        if (_holders[agent.id] case final other?
            when !identical(other, holder)) {
          await _api.closeLease(_owner, agent.id);
        }
        final opened = await _api.openLease(_owner, agent);
        if (opened is AgentSessionOpened) {
          _holders[agent.id] = holder;
        } else {
          _holders.remove(agent.id);
        }
        return opened;
      });

  /// Closes the lease of [agentId] if [holder] is the one holding it.
  Future<void> close(Object holder, String agentId) => _inOrder(() async {
    if (!identical(_holders[agentId], holder)) return;
    _holders.remove(agentId);
    await _api.closeLease(_owner, agentId);
  });

  /// Closes every lease [holder] still has.
  Future<void> closeAll(Object holder) => Future.wait([
    for (final MapEntry(key: agentId, value: held) in _holders.entries)
      if (identical(held, holder)) close(holder, agentId),
  ]);

  Future<T> _inOrder<T>(Future<T> Function() request) {
    final result = _requests.then((_) => request());
    _requests = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
