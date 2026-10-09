import 'package:dart_mappable/dart_mappable.dart';
import 'package:llm_model_profiles/llm_model_profiles.dart';
import 'package:test/test.dart';

void main() {
  group('ModelProfileId', () {
    test('serializes to its family string and back', () {
      const families = {
        ModelProfileId.qwen3: 'qwen3',
        ModelProfileId.qwen35: 'qwen35',
        ModelProfileId.qwen25: 'qwen25',
        ModelProfileId.gptOss: 'gpt_oss',
        ModelProfileId.qwen3Coder: 'qwen3_coder',
        ModelProfileId.gemma4: 'gemma4',
        ModelProfileId.glm4: 'glm4',
      };
      for (final MapEntry(key: profile, value: family) in families.entries) {
        expect(profile.toValue(), family);
        expect(ModelProfileIdMapper.fromValue(family), profile);
      }
    });

    test('names every family for display', () {
      expect(
        ModelProfileId.values.map((profile) => profile.displayName),
        [
          'Qwen 3',
          'Qwen 3.5',
          'Qwen 2.5',
          'GPT-OSS',
          'Qwen 3 Coder',
          'Gemma 4',
          'GLM-4',
        ],
      );
    });

    test('refuses a family it does not know', () {
      expect(
        () => ModelProfileIdMapper.fromValue('llama'),
        throwsA(isA<MapperException>()),
      );
    });
  });
}
