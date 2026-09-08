import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/mapping/sampling_mapper.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('toInferenceSampling', () {
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
        toInferenceSampling(options, maxOutputTokens: 512),
        const InferenceSampling(
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
        toInferenceSampling(const SamplingOptions(seed: 0)),
        const InferenceSampling(),
      );
    });
  });

  group('toInferenceReasoning', () {
    test('maps mode names to request settings', () {
      const expectations = {
        'minimal': InferenceReasoningEffort(InferenceEffort.minimal),
        'low': InferenceReasoningEffort(InferenceEffort.low),
        ' low ': InferenceReasoningEffort(InferenceEffort.low),
        'medium': InferenceReasoningEffort(InferenceEffort.medium),
        'high': InferenceReasoningEffort(InferenceEffort.high),
        'xhigh': InferenceReasoningEffort(InferenceEffort.xhigh),
        'max': InferenceReasoningEffort(InferenceEffort.max),
        'off': InferenceReasoningDisabled(),
        'on': InferenceReasoningEnabled(),
        'auto': InferenceReasoningDefault(),
        'none': InferenceReasoningDefault(),
        'adaptive': InferenceReasoningDefault(),
        'bogus': InferenceReasoningDefault(),
        '': InferenceReasoningDefault(),
      };
      for (final entry in expectations.entries) {
        expect(toInferenceReasoning(entry.key), entry.value, reason: entry.key);
      }
    });
  });
}
