import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/local_server_link.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// One agent provider's leases on the local server, held over the owner
/// session, with the pool the session reports.
@PartOf(LocalInferenceClient)
final class LocalAgentSessions implements AgentSessions {
  LocalAgentSessions({required LocalServerLink link}) : _link = link {
    _snapshots = link.poolSnapshots.listen(
      (snapshot) => _reports.add(reportOf(snapshot)),
    );
  }

  final LocalServerLink _link;
  final _reports = StreamController<AgentPoolReport>.broadcast();
  late final StreamSubscription<PoolSnapshotEvent> _snapshots;

  @override
  Stream<AgentPoolReport> get pool => _reports.stream;

  @override
  Future<AgentSessionResult> open(AgentIdentity agent) =>
      _link.openLease(this, agent);

  @override
  Future<void> close(AgentIdentity agent) => _link.closeLease(this, agent.id);

  @override
  Future<void> dispose() async {
    await _snapshots.cancel();
    await _link.releaseLeases(this);
    await _reports.close();
  }

  /// The pool as the provider reads it: subagent and borrowed claims are what
  /// the primary cannot use.
  static AgentPoolReport reportOf(PoolSnapshotEvent snapshot) =>
      AgentPoolReport(
        contextSize: snapshot.contextSize,
        reservedTokens: snapshot.agents
            .where((agent) => agent.kind == AgentLeaseKind.subagent)
            .fold(
              snapshot.borrowedTokens,
              (reserved, agent) => reserved + agent.claimedTokens,
            ),
        agents: [
          for (final agent in snapshot.agents)
            AgentPoolEntry(
              agent: AgentIdentity(
                id: agent.id,
                kind: switch (agent.kind) {
                  AgentLeaseKind.primary => AgentIdentityKind.primary,
                  AgentLeaseKind.subagent => AgentIdentityKind.subagent,
                },
              ),
              claimedTokens: agent.claimedTokens,
            ),
        ],
      );
}
