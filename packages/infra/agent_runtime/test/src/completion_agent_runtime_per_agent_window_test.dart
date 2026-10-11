import 'package:agent_runtime/agent_runtime.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers.dart';

final class _MockCompletionClient extends Mock implements CompletionClient {}

void main() {
  group('CompletionAgentRuntime.perAgentWindow', () {
    const options = AgentRuntimeOptions(
      modelId: 'm',
      contextWindow: 1000,
      maxAgents: 3,
    );

    test('serves on the client with the options it was given', () async {
      final client = _MockCompletionClient();
      final runtime = CompletionAgentRuntime.perAgentWindow(
        client: client,
        options: options,
      );
      addTearDown(runtime.dispose);

      expect(runtime.client, same(client));
      expect(runtime.options, same(options));
      expect(runtime.maxAgents, 3);
    });

    test('gives every subagent a whole window of its own', () async {
      final runtime = CompletionAgentRuntime.perAgentWindow(
        client: _MockCompletionClient(),
        options: options,
      );
      addTearDown(runtime.dispose);
      final snapshots = <ContextPoolSnapshot>[];
      runtime.pool.listen(snapshots.add);

      expect(
        await runtime.startPrimary(config: config()),
        isA<StartPrimaryStarted>(),
      );
      expect(
        await runtime.startSubagent(config: config(), label: 'a'),
        isA<StartSubagentStarted>(),
      );
      expect(
        await runtime.startSubagent(config: config(), label: 'b'),
        isA<StartSubagentStarted>(),
      );
      await pumpEventQueue();

      final latest = snapshots.last;
      expect(latest.contextSize, 1000);
      expect(latest.reservedClaims, 0);
      expect(
        latest.leases
            .where((lease) => lease.handle.kind == AgentKind.subagent)
            .map((lease) => lease.claimTokens),
        [1000, 1000],
      );
    });
  });
}
