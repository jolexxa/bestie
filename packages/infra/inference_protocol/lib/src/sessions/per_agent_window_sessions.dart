import 'dart:async';

import 'package:inference_protocol/src/models/agent_identity.dart';
import 'package:inference_protocol/src/sessions/agent_pool_report.dart';
import 'package:inference_protocol/src/sessions/agent_session_result.dart';
import 'package:inference_protocol/src/sessions/agent_sessions.dart';

/// Sessions for endpoints that give every agent a context window of its own:
/// every open succeeds, the primary draws on the whole window, each subagent
/// claims a full window, and nothing is reserved out of the primary's share.
final class PerAgentWindowSessions implements AgentSessions {
  PerAgentWindowSessions({required int contextWindow})
    : _contextWindow = contextWindow;

  final int _contextWindow;
  final Map<String, AgentIdentity> _open = {};
  final _reports = StreamController<AgentPoolReport>.broadcast();

  @override
  Stream<AgentPoolReport> get pool => _reports.stream;

  @override
  Future<AgentSessionResult> open(AgentIdentity agent) async {
    _open[agent.id] = agent;
    _report();
    return AgentSessionOpened(claimedTokens: _claimFor(agent));
  }

  @override
  Future<void> close(AgentIdentity agent) async {
    _open.remove(agent.id);
    _report();
  }

  @override
  Future<void> dispose() async {
    _open.clear();
    await _reports.close();
  }

  int _claimFor(AgentIdentity agent) => switch (agent.kind) {
    AgentIdentityKind.primary => 0,
    AgentIdentityKind.subagent => _contextWindow,
  };

  void _report() => _reports.add(
    AgentPoolReport(
      contextSize: _contextWindow,
      reservedTokens: 0,
      agents: [
        for (final agent in _open.values)
          AgentPoolEntry(agent: agent, claimedTokens: _claimFor(agent)),
      ],
    ),
  );
}
