import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import 'formatter_golden_fixtures.dart';

void main() {
  group('Qwen3CoderPromptFormatter golden', () {
    test('matches representative tool conversation exactly', () {
      final prompt = const Qwen3CoderPromptFormatter().format(
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
        'You have access to the following functions:',
        '',
        '<tools>',
        '<function>',
        '<name>search_web</name>',
        '<description>Search the web</description>',
        '<parameters>',
        '<parameter>',
        '<name>query</name>',
        '<type>string</type>',
        '<description>Search query</description>',
        '</parameter>',
        '<parameter>',
        '<name>limit</name>',
        '<type>integer</type>',
        '<description>Max results</description>',
        '</parameter>',
        '<required>["query"]</required>',
        '</parameters>',
        '</function>',
        '</tools>',
        '',
        'If you choose to call a function ONLY reply in the following format with NO suffix:',
        '',
        '<tool_call>',
        '<function=example_function_name>',
        '<parameter=example_parameter_1>',
        'value_1',
        '</parameter>',
        '<parameter=example_parameter_2>',
        'This is the value for the second parameter',
        'that can span',
        'multiple lines',
        '</parameter>',
        '</function>',
        '</tool_call>',
        '',
        '<IMPORTANT>',
        'Reminder:',
        '- Function calls MUST follow the specified format: an inner <function=...></function> block must be nested within <tool_call></tool_call> XML tags',
        '- Required parameters MUST be specified',
        '- You may provide optional reasoning for your function call in natural language BEFORE the function call, but NOT after',
        '- If there is no function call available, answer the question like normal with your current knowledge and do not tell the user about function calls',
        '</IMPORTANT><|im_end|>',
        '<|im_start|>user',
        'Find facts about cows.<|im_end|>',
        '<|im_start|>assistant',
        'I will search.',
        '<tool_call>',
        '<function=search_web>',
        '<parameter=query>',
        'cows',
        '</parameter>',
        '<parameter=limit>',
        '2',
        '</parameter>',
        '</function>',
        '</tool_call><|im_end|>',
        '<|im_start|>user',
        '<tool_response>',
        'Cows are domesticated bovines.',
        '</tool_response><|im_end|>',
        '<|im_start|>assistant',
        'Cows are domesticated bovines.<|im_end|>',
        '<|im_start|>assistant',
        '',
      ]);

      expect(prompt, expected);
    });
  });
}
