import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import 'formatter_golden_fixtures.dart';

void main() {
  group('GlmPromptFormatter golden', () {
    test('matches representative tool conversation exactly', () {
      final prompt = const GlmPromptFormatter().format(
        messages: goldenMessages,
        tools: const [goldenTool],
        reasoningMode: 'on',
      );

      final expected = goldenLines([
        '[gMASK]<sop><|system|>',
        '# Tools',
        '',
        'You may call one or more functions to assist with the user query.',
        '',
        'You are provided with function signatures within <tools></tools> XML tags:',
        '<tools>',
        goldenLine([
          '{"type":"function","function":{"name":"search_web",',
          '"description":"Search the web","parameters":{"type":"object",',
          '"properties":{"query":{"type":"string",',
          '"description":"Search query"},"limit":{"type":"integer",',
          '"description":"Max results"}},"required":["query"]}}}',
        ]),
        '</tools>',
        '',
        'For each function call, output the function name and arguments within the following XML format:',
        goldenLine([
          '<tool_call>{function-name}<arg_key>{arg-key-1}</arg_key>',
          '<arg_value>{arg-value-1}</arg_value><arg_key>{arg-key-2}',
          '</arg_key><arg_value>{arg-value-2}</arg_value>...</tool_call>',
          '<|system|>You are helpful.<|user|>Find facts about cows.',
          '<|assistant|><think>Need current facts.</think>I will search.',
          '<tool_call>search_web<arg_key>query</arg_key>',
          '<arg_value>cows</arg_value><arg_key>limit</arg_key>',
          '<arg_value>2</arg_value></tool_call><|observation|>',
          '<tool_response>Cows are domesticated bovines.</tool_response>',
          '<|assistant|></think>Cows are domesticated bovines.',
          '<|assistant|><think>',
        ]),
      ]);

      expect(prompt, expected);
    });
  });
}
