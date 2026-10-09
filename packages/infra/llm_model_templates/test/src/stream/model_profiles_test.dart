import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

void main() {
  group('ModelProfiles', () {
    test('profileFor returns qwen3 profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.qwen3);

      expect(profile, same(ModelProfiles.qwen3));
    });

    test('profileFor returns qwen35 profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.qwen35);

      expect(profile, same(ModelProfiles.qwen35));
      expect(profile.formatter, isA<Qwen35PromptFormatter>());
    });

    test('qwen35 uses XmlToolCallExtractor with think and function tags', () {
      final parser = ModelProfiles.qwen35StreamParser;
      expect(parser, isNotNull);

      final profile = ModelProfiles.qwen35;
      expect(profile.streamParser, same(parser));
      expect(profile.tags, contains('<think>'));
      expect(profile.tags, contains('</think>'));
      expect(profile.tags, contains('<tool_call>'));
      expect(profile.tags, contains('</tool_call>'));
      expect(profile.tags, contains('<function='));
      expect(profile.tags, contains('</function>'));
    });

    test('profileFor returns qwen25 profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.qwen25);

      expect(profile, same(ModelProfiles.qwen25));
    });

    test('profileFor returns qwen3Coder profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.qwen3Coder);

      expect(profile, same(ModelProfiles.qwen3Coder));
    });

    test('qwen3Coder uses XmlToolCallExtractor stream parser', () {
      final parser = ModelProfiles.qwen3CoderStreamParser;
      expect(parser, isNotNull);

      final profile = ModelProfiles.qwen3Coder;
      expect(profile.streamParser, same(parser));
      expect(profile.tags, isNotEmpty);
    });

    test('profileFor returns gptOss profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.gptOss);

      expect(profile, same(ModelProfiles.gptOss));
      expect(profile.formatter, isA<HarmonyPromptFormatter>());
    });

    test('profileFor returns gemma4 profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.gemma4);

      expect(profile, same(ModelProfiles.gemma4));
      expect(profile.formatter, isA<Gemma4PromptFormatter>());
    });

    test('gemma4 uses GemmaToolCallExtractor stream parser', () {
      final parser = ModelProfiles.gemma4StreamParser;
      expect(parser, isNotNull);

      final profile = ModelProfiles.gemma4;
      expect(profile.streamParser, same(parser));
      expect(profile.tags, isNotEmpty);
      expect(profile.tags, contains('<|tool_call>'));
      expect(profile.tags, contains('<tool_call|>'));
    });

    test('profileFor returns glm4 profile', () {
      final profile = ModelProfiles.profileFor(ModelProfileId.glm4);

      expect(profile, same(ModelProfiles.glm4));
      expect(profile.formatter, isA<GlmPromptFormatter>());
    });

    test('glm4 uses GlmToolCallExtractor stream parser', () {
      final parser = ModelProfiles.glm4StreamParser;
      expect(parser, isNotNull);

      final profile = ModelProfiles.glm4;
      expect(profile.streamParser, same(parser));
      expect(profile.tags, isNotEmpty);
      expect(profile.tags, contains('<tool_call>'));
      expect(profile.tags, contains('</tool_call>'));
      expect(profile.tags, contains('<think>'));
      expect(profile.tags, contains('</think>'));
    });
  });
}
