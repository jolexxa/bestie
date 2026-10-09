import 'package:inference_backends/inference_backends.dart';
import 'package:test/test.dart';

void main() {
  group('EngineSampling', () {
    test('equal field values compare equal with matching hashCodes', () {
      const a = EngineSampling(seed: 7, temperature: 0.5, topK: 40);
      const b = EngineSampling(seed: 7, temperature: 0.5, topK: 40);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a differing field breaks equality', () {
      const base = EngineSampling(seed: 7, temperature: 0.5);

      expect(base, isNot(const EngineSampling(seed: 8, temperature: 0.5)));
      expect(base, isNot(const EngineSampling(seed: 7, temperature: 0.6)));
    });

    test('leaves every field unset by default', () {
      const sampling = EngineSampling();

      expect(sampling.seed, isNull);
      expect(sampling.temperature, isNull);
    });
  });
}
