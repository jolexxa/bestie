import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('SamplingOptions', () {
    test('defaults every sampler to null', () {
      final options = SamplingOptions(seed: 7);
      expect(options.seed, 7);
      expect(options.topK, isNull);
      expect(options.topP, isNull);
      expect(options.minP, isNull);
      expect(options.temperature, isNull);
      expect(options.typicalP, isNull);
      expect(options.penaltyRepeat, isNull);
      expect(options.penaltyLastN, isNull);
      expect(options.penaltyFreq, isNull);
      expect(options.penaltyPresent, isNull);
    });

    test('carries every sampler it is given', () {
      final options = SamplingOptions(
        seed: 1,
        topK: 40,
        topP: 0.95,
        minP: 0.05,
        temperature: 0.7,
        typicalP: 1,
        penaltyRepeat: 1.1,
        penaltyLastN: 64,
        penaltyFreq: 0.2,
        penaltyPresent: 0.3,
      );
      expect(options.topK, 40);
      expect(options.topP, 0.95);
      expect(options.minP, 0.05);
      expect(options.temperature, 0.7);
      expect(options.typicalP, 1);
      expect(options.penaltyRepeat, 1.1);
      expect(options.penaltyLastN, 64);
      expect(options.penaltyFreq, 0.2);
      expect(options.penaltyPresent, 0.3);
    });

    test('compares by value and copies fields', () {
      final options = SamplingOptions(seed: 3, temperature: 0.4);
      expect(options, SamplingOptions(seed: 3, temperature: 0.4));
      expect(
        options.copyWith(seed: 4),
        SamplingOptions(seed: 4, temperature: 0.4),
      );
    });
  });
}
