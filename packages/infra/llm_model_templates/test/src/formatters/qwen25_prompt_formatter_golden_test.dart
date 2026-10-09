import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import 'formatter_golden_fixtures.dart';

void main() {
  group('Qwen25PromptFormatter golden', () {
    test('matches representative tool conversation exactly', () {
      final prompt = const Qwen25PromptFormatter().format(
        messages: goldenMessages,
        tools: const [goldenTool],
        reasoningMode: 'on',
      );

      final expected = goldenLines([
        '<|im_start|>system',
        'You are helpful.',
        '',
        '# Tools',
        '',
        'You may call one or more functions to assist with the user query.',
        '',
        'You are provided with function signatures within <tools></tools> XML tags:',
        '<tools>',
        '',
        goldenLine([
          '{"name":"search_web","description":"Search the web",',
          '"parameters":{"type":"object","properties":{"query":',
          '{"type":"string","description":"Search query"},"limit":',
          '{"type":"integer","description":"Max results"}},',
          '"required":["query"]}}',
        ]),
        '</tools>',
        '',
        'For each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:',
        '<tool_call>',
        '{"name": <function-name>, "arguments": <args-json-object>}',
        '</tool_call><|im_end|>',
        '<|im_start|>user',
        'Find facts about cows.',
        '<|im_end|>',
        '<|im_start|>assistant',
        'I will search.',
        '<tool_call>',
        '{"name": "search_web", "arguments": {"query":"cows","limit":2}}',
        '</tool_call>',
        '<|im_end|>',
        '<|im_start|>user',
        '<tool_response>',
        'Cows are domesticated bovines.',
        '</tool_response>',
        '<|im_end|>',
        '<|im_start|>assistant',
        'Cows are domesticated bovines.',
        '<|im_end|>',
        '<|im_start|>assistant',
        '',
      ]);

      expect(prompt, expected);
    });
  });
}
