import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import 'formatter_golden_fixtures.dart';

void main() {
  group('Gemma4PromptFormatter golden', () {
    test('matches representative tool conversation exactly', () {
      final prompt = const Gemma4PromptFormatter().format(
        messages: goldenMessages,
        tools: const [goldenTool],
        reasoningMode: 'on',
      );

      final expected = goldenLines([
        '<|turn>system',
        '<|think|>',
        goldenLine([
          'You are helpful.<|tool>declaration:search_web{description:<|"|>',
          'Search the web<|"|>,parameters:{properties:{limit:{description:',
          '<|"|>Max results<|"|>,type:<|"|>INTEGER<|"|>},query:{',
          'description:<|"|>Search query<|"|>,type:<|"|>STRING<|"|>}},',
          'required:[<|"|>query<|"|>],type:<|"|>OBJECT<|"|>}}',
          '<tool|><turn|>',
        ]),
        '<|turn>user',
        'Find facts about cows.<turn|>',
        '<|turn>model',
        '<|channel>thought',
        'Need current facts.',
        goldenLine([
          '<channel|><|tool_call>call:search_web{limit:2,query:<|"|>cows<|"|>}',
          '<tool_call|><|tool_response>response:search_web{value:<|"|>',
          'Cows are domesticated bovines.<|"|>}<tool_response|>',
          'I will search.<turn|>',
        ]),
        'Cows are domesticated bovines.<turn|>',
        '<|turn>model',
        '',
      ]);

      expect(prompt, expected);
    });
  });
}
