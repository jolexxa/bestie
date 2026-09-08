import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('AgentPrefillProgress carries the prompt position', () {
    const handle = AgentHandle(id: 'a', kind: AgentKind.primary);
    final event = AgentPrefillProgress(
      timestamp: DateTime.utc(2025),
      agent: handle,
      completed: 40,
      total: 100,
    );

    expect(event.agent, handle);
    expect(event.completed, 40);
    expect(event.total, 100);
    expect(event, isA<AgentRuntimeEvent>());
  });
}
