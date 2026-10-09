import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('Qwen35PromptFormatter', () {
    const formatter = Qwen35PromptFormatter();
    const tool = PromptTool(
      name: 'search',
      description: 'Search the web',
      parameters: {'type': 'object'},
    );

    test('writes the tools block before the system prompt content', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hello.'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      final toolsIndex = prompt.indexOf('# Tools');
      final systemIndex = prompt.indexOf('You are helpful.');
      expect(toolsIndex, isNot(-1));
      expect(systemIndex, greaterThan(toolsIndex));
      expect(prompt, contains('</IMPORTANT>\n\nYou are helpful.<|im_end|>\n'));
    });

    test('omits blank system prompt content from the tools block', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('   '),
          PromptUserMessage('Hello.'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('</IMPORTANT><|im_end|>\n'));
    });

    test(
      'opens a think block in the generation prompt when reasoning is on',
      () {
        final prompt = formatter.format(
          messages: const [PromptUserMessage('Hello.')],
          tools: const [],
          reasoningMode: 'on',
        );

        expect(prompt, endsWith('<|im_start|>assistant\n<think>\n'));
      },
    );

    test('closes an empty think block when reasoning is off', () {
      final prompt = formatter.format(
        messages: const [PromptUserMessage('Hello.')],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(
        prompt,
        endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n'),
      );
    });

    test('appends an assistant prefill after the generation prologue', () {
      final prompt = formatter.format(
        messages: const [PromptUserMessage('Hello.')],
        tools: const [],
        reasoningMode: 'on',
        assistantPrefill: '## Goal\n',
      );

      expect(prompt, endsWith('<|im_start|>assistant\n<think>\n## Goal\n'));
    });

    test('reports prefilled reasoning per mode', () {
      expect(formatter.prefillsReasoning('on'), isTrue);
      expect(formatter.prefillsReasoning('off'), isFalse);
    });

    test('renders a plain system turn when no tools are offered', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hello.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        startsWith('<|im_start|>system\nYou are helpful.<|im_end|>\n'),
      );
      expect(prompt, isNot(contains('# Tools')));
    });

    test('always wraps post-query assistant turns in think blocks', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Question.'),
          PromptAssistantMessage(content: 'Middle.'),
          PromptAssistantMessage(content: 'Last.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<think>\n\n</think>\n\nMiddle.<|im_end|>\n'));
      expect(prompt, contains('<think>\n\n</think>\n\nLast.<|im_end|>\n'));
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

    test('trims rendered message content', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('  Padded question.  \n'),
          PromptAssistantMessage(content: '\n  Padded answer.  '),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>user\nPadded question.<|im_end|>'));
      expect(prompt, contains('\n</think>\n\nPadded answer.<|im_end|>'));
    });

    test('separates the first tool call from content with a blank line', () {
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
                  'limit': 2,
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
          'Ok.\n\n'
          '<tool_call>\n'
          '<function=search>\n'
          '<parameter=query>\n'
          'cows\n'
          '</parameter>\n'
          '<parameter=filters>\n'
          '["a","b"]\n'
          '</parameter>\n'
          '<parameter=limit>\n'
          '2\n'
          '</parameter>\n'
          '</function>\n'
          '</tool_call><|im_end|>\n',
        ),
      );
    });

    test('omits the separator when a tool call has no content', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Search'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: 'call-1', name: 'search', arguments: {}),
            ],
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('\n</think>\n\n<tool_call>\n<function=search>\n'),
      );
    });

    test('ignores tool-response user content when locating the last query', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Original question.'),
          PromptAssistantMessage(content: 'Calling a tool.'),
          PromptUserMessage('<tool_response>\nResult\n</tool_response>'),
          PromptAssistantMessage(content: 'Follow up.'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('<think>\n\n</think>\n\nCalling a tool.<|im_end|>'),
      );
      expect(prompt, contains('<think>\n\n</think>\n\nFollow up.<|im_end|>'));
    });

    test('groups consecutive tool responses under one user turn', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go.'),
          PromptToolMessage(toolCallId: '1', name: 'search', content: 'One'),
          PromptToolMessage(toolCallId: '2', name: 'search', content: 'Two'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains(
          '<|im_start|>user\n'
          '<tool_response>\n'
          'One\n'
          '</tool_response>\n'
          '<tool_response>\n'
          'Two\n'
          '</tool_response><|im_end|>\n',
        ),
      );
    });

    test('stopSequences and addBos', () {
      expect(formatter.stopSequences, ['<|im_end|>', '<|im_start|>']);
      expect(formatter.addBos, isTrue);
    });
  });
}
