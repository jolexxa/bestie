import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';

/// Names the agent behind [handle] to the completion endpoint.
AgentIdentity toAgentIdentity(AgentHandle handle) => AgentIdentity(
  id: handle.id,
  kind: switch (handle.kind) {
    AgentKind.primary => AgentIdentityKind.primary,
    AgentKind.subagent => AgentIdentityKind.subagent,
  },
);
