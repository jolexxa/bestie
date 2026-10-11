import 'dart:async';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final class _MockAgentRuntime extends Mock implements AgentRuntime {}

void main() {
  group('HostedProviderModel', () {
    test('runs agents on the runtime it was given', () {
      final runtime = _MockAgentRuntime();
      final model = HostedProviderModel(
        runtime: runtime,
        contextWindow: 8192,
        maxAgents: 3,
      );

      expect(model.runtime, same(runtime));
      expect(model.contextWindow, 8192);
      expect(model.maxAgents, 3);
      expect(model.deviceBytes, isNull);
    });

    test('is never lost and releases its runtime', () {
      fakeAsync((async) {
        final runtime = _MockAgentRuntime();
        when(
          runtime.dispose,
        ).thenAnswer((_) async => const DisposeRuntimeSucceeded());
        final model = HostedProviderModel(
          runtime: runtime,
          contextWindow: 8192,
          maxAgents: 3,
        );
        var lost = false;
        unawaited(model.lost.then((_) => lost = true));
        var released = false;
        unawaited(model.release().then((_) => released = true));

        async.elapse(const Duration(days: 1));

        expect(lost, isFalse);
        expect(released, isTrue);
        verify(runtime.dispose).called(1);
      });
    });
  });
}
