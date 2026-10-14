import 'package:completion_protocol/completion_protocol.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/built_in_agent_sessions.dart';
import 'package:provider_local/src/built_in_server_client.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

void main() {
  const primary = AgentIdentity(
    id: 'primary:1',
    kind: AgentIdentityKind.primary,
  );
  const subagent = AgentIdentity(
    id: 'subagent:2',
    kind: AgentIdentityKind.subagent,
  );
  const snapshot = PoolSnapshotEvent(
    contextSize: 8192,
    maxAgents: 3,
    agents: [
      PoolAgent(
        id: 'primary:1',
        kind: AgentLeaseKind.primary,
        claimedTokens: 0,
        usedTokens: 900,
      ),
      PoolAgent(
        id: 'subagent:2',
        kind: AgentLeaseKind.subagent,
        claimedTokens: 2048,
        usedTokens: 100,
      ),
      PoolAgent(
        id: 'subagent:3',
        kind: AgentLeaseKind.subagent,
        claimedTokens: 1024,
        usedTokens: 0,
      ),
    ],
  );

  late FakeServer server;
  late BuiltInServerClient client;

  setUp(() async {
    server = FakeServer();
    client = server.client();
    await client
        .load(
          const ProviderModelLoadRequest(
            modelId: 'qwen',
            contextWindow: 40960,
            maxAgents: 3,
          ),
        )
        .result;
  });

  tearDown(() => client.close());

  test('reports the pool with the subagent claims reserved', () {
    final report = BuiltInAgentSessions.reportOf(snapshot);

    expect(report.contextSize, 8192);
    expect(report.reservedTokens, 3072);
    expect(report.agents.map((entry) => entry.agent), [
      primary,
      subagent,
      const AgentIdentity(id: 'subagent:3', kind: AgentIdentityKind.subagent),
    ]);
    expect(report.agents.map((entry) => entry.claimedTokens), [0, 2048, 1024]);
    expect(report.agents.map((entry) => entry.usedTokens), [900, 100, 0]);
  });

  test('reserves borrowed claims alongside the subagent claims', () {
    final borrowing = PoolSnapshotEvent(
      contextSize: snapshot.contextSize,
      maxAgents: snapshot.maxAgents,
      agents: snapshot.agents,
      borrowedTokens: 512,
    );

    expect(BuiltInAgentSessions.reportOf(borrowing).reservedTokens, 3584);
  });

  test('streams the pool the owner session reports', () async {
    final sessions = BuiltInAgentSessions(link: client);
    final reports = sessions.pool.toList();

    server.emit(snapshot);
    await pumpEventQueue();
    await sessions.dispose();

    expect(
      (await reports).map((report) => report.reservedTokens),
      [3072],
    );
  });

  test('opens and closes leases on the server', () async {
    final sessions = BuiltInAgentSessions(link: client);

    expect(await sessions.open(primary), isA<AgentSessionOpened>());
    await sessions.close(primary);

    expect(server.callsTo(bestieAgentPath(primary.id)), [
      'POST ${bestieAgentPath(primary.id)}',
      'DELETE ${bestieAgentPath(primary.id)}',
    ]);
  });

  test('releases only its own leases when disposed', () async {
    final sessions = BuiltInAgentSessions(link: client);
    final others = BuiltInAgentSessions(link: client);
    await sessions.open(primary);
    await others.open(subagent);

    await sessions.dispose();

    expect(
      server.callsTo(bestieAgentPath(primary.id)).last,
      'DELETE ${bestieAgentPath(primary.id)}',
    );
    expect(server.callsTo(bestieAgentPath(subagent.id)), [
      'POST ${bestieAgentPath(subagent.id)}',
    ]);
    await others.dispose();
  });
}
