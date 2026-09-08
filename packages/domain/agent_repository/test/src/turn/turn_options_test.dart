import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

void main() {
  group('TurnOptions', () {
    test('baseline runs deterministically with automatic reasoning', () {
      const options = TurnOptions.baseline('be brief');

      expect(options.systemPrompt, 'be brief');
      expect(options.sampling, const SamplingOptions(seed: 0));
      expect(options.reasoningMode, 'auto');
      expect(options.compactionReasoningMode, 'auto');
    });

    test('maps onto an agent config with the run-time extras', () {
      const tool = ToolDefinition(
        onProgress: 'Running',
        onSuccess: 'Ran',
        onError: 'Failed',
        name: 'search',
        description: 'search the web',
        parameters: {},
      );
      const options = TurnOptions(
        systemPrompt: 'prompt',
        sampling: SamplingOptions(seed: 3, temperature: 0.2),
        reasoningMode: 'high',
        compactionReasoningMode: 'low',
      );

      final config = options.toAgentConfig(
        compactionRatio: 0.7,
        tools: const [tool],
      );

      expect(config.systemPrompt, 'prompt');
      expect(config.sampling.seed, 3);
      expect(config.sampling.temperature, 0.2);
      expect(config.reasoningMode, 'high');
      expect(config.compactionReasoningMode, 'low');
      expect(config.compactionRatio, 0.7);
      expect(config.tools, [tool]);
      expect(config.isValid, isTrue);
    });

    test('compares by value', () {
      const a = TurnOptions.baseline('p');
      const b = TurnOptions.baseline('p');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const TurnOptions.baseline('q')));
    });
  });
}
