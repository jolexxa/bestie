import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart';

/// Names the agent behind [handle] to the inference endpoint.
AgentIdentity toAgentIdentity(AgentHandle handle) => AgentIdentity(
  id: handle.id,
  kind: switch (handle.kind) {
    AgentKind.primary => AgentIdentityKind.primary,
    AgentKind.subagent => AgentIdentityKind.subagent,
  },
);
