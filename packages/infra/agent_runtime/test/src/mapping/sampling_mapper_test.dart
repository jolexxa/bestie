import 'package:agent_runtime/src/mapping/sampling_mapper.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('toCompletionSampling', () {
    test('keeps the OpenAI-compatible knobs and drops the rest', () {
      const options = SamplingOptions(
        seed: 7,
        topK: 40,
        topP: 0.9,
        minP: 0.1,
        temperature: 0.6,
        typicalP: 0.8,
        penaltyRepeat: 1.1,
        penaltyLastN: 64,
        penaltyFreq: 0.2,
        penaltyPresent: 0.3,
      );

      expect(
        toCompletionSampling(options, maxOutputTokens: 512),
        const CompletionSampling(
          temperature: 0.6,
          topP: 0.9,
          frequencyPenalty: 0.2,
          presencePenalty: 0.3,
          seed: 7,
          maxOutputTokens: 512,
        ),
      );
    });

    test('treats seed zero as unset', () {
      expect(
        toCompletionSampling(const SamplingOptions(seed: 0)),
        const CompletionSampling(),
      );
    });
  });

  group('toCompletionReasoning', () {
    test('maps mode names to request settings', () {
      const expectations = {
        'minimal': CompletionReasoningEffort(CompletionEffort.minimal),
        'low': CompletionReasoningEffort(CompletionEffort.low),
        ' low ': CompletionReasoningEffort(CompletionEffort.low),
        'medium': CompletionReasoningEffort(CompletionEffort.medium),
        'high': CompletionReasoningEffort(CompletionEffort.high),
        'xhigh': CompletionReasoningEffort(CompletionEffort.xhigh),
        'max': CompletionReasoningEffort(CompletionEffort.max),
        'off': CompletionReasoningDisabled(),
        'on': CompletionReasoningEnabled(),
        'auto': CompletionReasoningDefault(),
        'none': CompletionReasoningDefault(),
        'adaptive': CompletionReasoningDefault(),
        'bogus': CompletionReasoningDefault(),
        '': CompletionReasoningDefault(),
      };
      for (final entry in expectations.entries) {
        expect(
          toCompletionReasoning(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });
}
