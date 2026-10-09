import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

const _primary = AgentIdentity(
  id: 'primary:1',
  kind: AgentIdentityKind.primary,
);
const _helper = AgentIdentity(
  id: 'subagent:2',
  kind: AgentIdentityKind.subagent,
);

void main() {
  group('AgentIdentity', () {
    test('compares by id and kind', () {
      expect(
        _primary,
        const AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
      );
      expect(
        _primary,
        isNot(
          const AgentIdentity(
            id: 'primary:1',
            kind: AgentIdentityKind.subagent,
          ),
        ),
      );
      expect(_primary, isNot(_helper));
      expect(
        _primary.hashCode,
        const AgentIdentity(
          id: 'primary:1',
          kind: AgentIdentityKind.primary,
        ).hashCode,
      );
      expect(_primary.toString(), 'AgentIdentity(primary:1, primary)');
    });
  });

  group('AgentSessionResult', () {
    test('compares an opened session by its claim', () {
      expect(
        const AgentSessionOpened(claimedTokens: 10),
        const AgentSessionOpened(claimedTokens: 10),
      );
      expect(
        const AgentSessionOpened(claimedTokens: 10),
        isNot(const AgentSessionOpened(claimedTokens: 11)),
      );
      expect(
        const AgentSessionOpened(claimedTokens: 10).hashCode,
        const AgentSessionOpened(claimedTokens: 10).hashCode,
      );
      expect(
        const <AgentSessionResult>[
          AgentSessionNoCapacity(),
          AgentSessionInsufficientClaim(),
          AgentSessionFailed(message: 'refused'),
        ],
        [
          isA<AgentSessionNoCapacity>(),
          isA<AgentSessionInsufficientClaim>(),
          isA<AgentSessionFailed>().having(
            (failed) => failed.message,
            'message',
            'refused',
          ),
        ],
      );
    });
  });

  group('AgentPoolReport', () {
    test('carries the context split', () {
      const entry = AgentPoolEntry(agent: _helper, claimedTokens: 256);
      const report = AgentPoolReport(
        contextSize: 1024,
        reservedTokens: 256,
        agents: [entry],
      );

      expect(report.contextSize, 1024);
      expect(report.reservedTokens, 256);
      expect(report.agents, [
        const AgentPoolEntry(agent: _helper, claimedTokens: 256),
      ]);
      expect(
        entry,
        isNot(const AgentPoolEntry(agent: _helper, claimedTokens: 255)),
      );
      expect(
        entry.hashCode,
        const AgentPoolEntry(agent: _helper, claimedTokens: 256).hashCode,
      );
      expect(entry.toString(), 'AgentPoolEntry(subagent:2, 256)');
    });
  });

  group('PerAgentWindowSessions', () {
    test('opens every agent, claiming a full window per subagent', () async {
      final sessions = PerAgentWindowSessions(contextWindow: 1000);

      expect(
        await sessions.open(_primary),
        const AgentSessionOpened(claimedTokens: 0),
      );
      expect(
        await sessions.open(_helper),
        const AgentSessionOpened(claimedTokens: 1000),
      );
    });

    test('reports every open session and nothing reserved', () async {
      final sessions = PerAgentWindowSessions(contextWindow: 1000);
      final reports = <AgentPoolReport>[];
      sessions.pool.listen(reports.add);

      await sessions.open(_primary);
      await sessions.open(_helper);
      await sessions.close(_primary);
      await pumpEventQueue();

      expect(reports, hasLength(3));
      expect(reports.map((report) => report.contextSize), everyElement(1000));
      expect(reports.map((report) => report.reservedTokens), everyElement(0));
      expect(reports[0].agents, [
        const AgentPoolEntry(agent: _primary, claimedTokens: 0),
      ]);
      expect(reports[1].agents, [
        const AgentPoolEntry(agent: _primary, claimedTokens: 0),
        const AgentPoolEntry(agent: _helper, claimedTokens: 1000),
      ]);
      expect(reports[2].agents, [
        const AgentPoolEntry(agent: _helper, claimedTokens: 1000),
      ]);
    });

    test('ends the pool when disposed', () async {
      final sessions = PerAgentWindowSessions(contextWindow: 1000);
      final done = sessions.pool.toList();

      await sessions.open(_primary);
      await sessions.dispose();

      expect(await done, hasLength(1));
    });
  });
}
