import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import 'formatter_golden_fixtures.dart';

void main() {
  group('HarmonyPromptFormatter golden', () {
    test('matches representative tool conversation exactly', () {
      final prompt = const HarmonyPromptFormatter().format(
        messages: goldenMessages,
        tools: const [goldenTool],
        reasoningMode: 'medium',
      );

      final expected = goldenLines([
        '<|start|>system<|message|>You are ChatGPT, a large language model trained by OpenAI.',
        'Knowledge cutoff: 2024-06',
        '',
        'Reasoning: medium',
        '',
        '# Valid channels: analysis, commentary, final. Channel must be included for every message.',
        "Calls to these tools must go to the commentary channel: 'functions'.<|end|><|start|>developer<|message|># Instructions",
        '',
        'You are helpful.',
        '',
        '# Tools',
        '',
        '## functions',
        '',
        'namespace functions {',
        '',
        '// Search the web',
        'type search_web = (_: {',
        '// Search query',
        'query: string,',
        '// Max results',
        'limit?: number,',
        '}) => any;',
        '',
        '} // namespace functions<|end|><|start|>user<|message|>Find facts about cows.<|end|><|start|>assistant<|channel|>commentary to=functions.search_web <|constrain|>json<|message|>{"query":"cows","limit":2}<|call|><|start|>functions.search_web to=assistant<|channel|>commentary<|message|>"Cows are domesticated bovines."<|end|><|start|>assistant<|channel|>final<|message|>Cows are domesticated bovines.<|end|><|start|>assistant',
      ]);

      expect(prompt, expected);
    });
  });
}
