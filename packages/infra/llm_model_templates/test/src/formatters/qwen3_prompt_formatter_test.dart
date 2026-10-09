import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('QwenPromptFormatter', () {
    const formatter = Qwen3PromptFormatter();
    const tool = PromptTool(
      name: 'search',
      description: 'Search the web',
      parameters: {'type': 'object'},
    );

    test('includes tool declarations, tool calls, and tool responses', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Find facts about cows.'),
          PromptAssistantMessage(
            content: 'Let me check.',
            toolCalls: [
              ToolCallDefault(
                id: 'call-1',
                name: 'search',
                arguments: {'query': 'cows'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'call-1',
            name: 'search',
            content: 'Cows are large mammals.',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<tools>'));
      expect(prompt, contains('"name":"search"'));
      expect(prompt, contains('<tool_call>'));
      expect(prompt, contains('"name": "search"'));
      expect(prompt, contains('<tool_response>'));
      expect(prompt.trimRight(), endsWith('<|im_start|>assistant'));
    });

    test('injects empty think block when reasoning is disabled', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hello.'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(
        prompt,
        contains('<|im_start|>assistant\n<think>\n\n</think>\n\n'),
      );
    });

    test('appends an assistant prefill after the generation prompt', () {
      final off = formatter.format(
        messages: const [PromptUserMessage('Hello.')],
        tools: const [],
        reasoningMode: 'off',
        assistantPrefill: '## Goal\n',
      );
      expect(
        off,
        endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n## Goal\n'),
      );

      final on = formatter.format(
        messages: const [PromptUserMessage('Hello.')],
        tools: const [],
        reasoningMode: 'on',
        assistantPrefill: '## Goal\n',
      );
      expect(on.trimRight(), endsWith('<|im_start|>assistant\n## Goal'));
    });

    test('emits reasoning blocks for assistant messages when enabled', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hello.'),
          PromptAssistantMessage(
            content: 'Answer',
            reasoning: 'Thinking',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<think>'));
      expect(prompt, contains('Thinking'));
      expect(prompt, contains('</think>'));
    });

    test('tool response headers are omitted', () {
      final prompt = formatter.format(
        messages: const [
          PromptToolMessage(toolCallId: '', name: 'unknown', content: 'Result'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, isNot(contains('Tool:')));
      expect(prompt, contains('<tool_response>'));
    });

    test('matches the reference template prompt exactly', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Find facts.'),
          PromptAssistantMessage(
            content: 'Let me check.',
            reasoning: 'Plan',
            toolCalls: [
              ToolCallDefault(
                id: 'call-1',
                name: 'search',
                arguments: {'query': 'cows'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: '',
            name: 'unknown',
            content: 'Result 1',
          ),
          PromptToolMessage(
            toolCallId: '',
            name: 'unknown',
            content: 'Result 2',
          ),
          PromptAssistantMessage(content: 'Done.'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      const expected =
          '<|im_start|>system\n'
          'You are helpful.\n'
          '\n'
          '# Tools\n'
          '\n'
          'You may call one or more functions to assist with the user query.\n'
          '\n'
          'You are provided with function signatures within <tools></tools> XML tags:\n'
          '<tools>\n'
          '{"type":"function","function":{"name":"search","description":"Search'
          ' the web","parameters":{"type":"object"}}}\n'
          '</tools>\n'
          '\n'
          'For each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n'
          '<tool_call>\n'
          '{"name": <function-name>, "arguments": <args-json-object>}\n'
          '</tool_call><|im_end|>\n'
          '<|im_start|>user\n'
          'Find facts.<|im_end|>\n'
          '<|im_start|>assistant\n'
          '<think>\n'
          'Plan\n'
          '</think>\n'
          '\n'
          'Let me check.\n'
          '<tool_call>\n'
          '{"name": "search", "arguments": {"query":"cows"}}\n'
          '</tool_call><|im_end|>\n'
          '<|im_start|>user\n'
          '<tool_response>\n'
          'Result 1\n'
          '</tool_response>\n'
          '<tool_response>\n'
          'Result 2\n'
          '</tool_response><|im_end|>\n'
          '<|im_start|>assistant\n'
          '<think>\n'
          '\n'
          '</think>\n'
          '\n'
          'Done.<|im_end|>\n'
          '<|im_start|>assistant\n';

      expect(prompt, expected);
    });

    test('parses embedded think blocks when reasoning content is inline', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptAssistantMessage(content: '<think>\nHidden\n</think>\nVisible'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<think>\nHidden\n</think>\n\nVisible'));
    });

    test('keeps assistant content before the last user unwrapped', () {
      final prompt = formatter.format(
        messages: const [
          PromptAssistantMessage(content: 'Earlier response.'),
          PromptUserMessage('Latest question.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('<|im_start|>assistant\nEarlier response.<|im_end|>'),
      );
      expect(prompt, isNot(contains('<think>\nEarlier response.')));
    });

    test('serializes tool call arguments as json', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Search'),
          PromptAssistantMessage(
            content: 'Ok.',
            toolCalls: [
              ToolCallDefault(
                id: 'call-1',
                name: 'search',
                arguments: {
                  'query': 'cows',
                  'filters': ['a', 'b'],
                },
              ),
            ],
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains(
          '{"name": "search", "arguments": '
          '{"query":"cows","filters":["a","b"]}}',
        ),
      );
    });

    test('ignores tool-response user content when locating the last query', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('<tool_response>\nResult\n</tool_response>'),
          PromptAssistantMessage(content: 'Follow up.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>assistant\nFollow up.<|im_end|>'));
      expect(prompt, isNot(contains('<think>\nFollow up.')));
    });

    test('lastUserMessageIndex handles missing user messages', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('System only.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('System only.'));
    });

    test('folds developer messages into system-style ChatML', () {
      final prompt = formatter.format(
        messages: const [
          PromptDeveloperMessage('Developer rules.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system\nDeveloper rules.'));
    });

    test('folds non-leading system-like messages into system turns', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptDeveloperMessage('Developer follow-up.'),
          PromptSystemMessage('System follow-up.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system\nDeveloper follow-up.'));
      expect(prompt, contains('<|im_start|>system\nSystem follow-up.'));
    });

    test('stopSequences and addBos', () {
      expect(formatter.stopSequences, ['<|im_end|>', '<|im_start|>']);
      expect(formatter.addBos, isTrue);
    });
  });
}
