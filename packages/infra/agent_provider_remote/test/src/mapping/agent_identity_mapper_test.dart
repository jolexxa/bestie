import 'package:agent_provider_remote/src/mapping/agent_identity_mapper.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  test('names each agent by its handle id and kind', () {
    expect(
      toAgentIdentity(primaryHandle),
      const AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
    );
    expect(
      toAgentIdentity(subagentHandle),
      const AgentIdentity(id: 'subagent:2', kind: AgentIdentityKind.subagent),
    );
  });
}
