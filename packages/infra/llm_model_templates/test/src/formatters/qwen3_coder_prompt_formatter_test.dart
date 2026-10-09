import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('Qwen3CoderPromptFormatter', () {
    const formatter = Qwen3CoderPromptFormatter();
    const tool = PromptTool(
      name: 'search',
      description: 'Search the web',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query',
          },
        },
        'required': ['query'],
      },
    );

    test('renders XML tool definitions in system block', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<tools>'));
      expect(prompt, contains('<function>'));
      expect(prompt, contains('<name>search</name>'));
      expect(prompt, contains('<description>Search the web</description>'));
      expect(prompt, contains('<type>string</type>'));
      expect(
        prompt,
        contains('<description>The search query</description>'),
      );
      expect(prompt, contains('</tools>'));
      expect(prompt, contains('<IMPORTANT>'));
      expect(prompt, contains('You are helpful.'));
    });

    test('separates consecutive tool calls with a newline', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Find facts about cows and goats.'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'call-1',
                name: 'search',
                arguments: {'query': 'cows'},
              ),
              ToolCallDefault(
                id: 'call-2',
                name: 'search',
                arguments: {'query': 'goats'},
              ),
            ],
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('</tool_call>\n<tool_call>'));
    });

    test('does not prefill reasoning', () {
      expect(formatter.prefillsReasoning('on'), isFalse);
    });

    test('renders tool calls in XML format', () {
      final prompt = formatter.format(
        messages: const [
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

      expect(prompt, contains('<tool_call>'));
      expect(prompt, contains('<function=search>'));
      expect(prompt, contains('<parameter=query>'));
      expect(prompt, contains('cows'));
      expect(prompt, contains('</parameter>'));
      expect(prompt, contains('</function>'));
      expect(prompt, contains('</tool_call>'));
      expect(prompt, contains('<tool_response>'));
    });

    test('does NOT add forced think block when reasoning disabled', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hello'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, isNot(contains('<think>')));
      expect(prompt.trimRight(), endsWith('<|im_start|>assistant'));
    });

    test('appends an assistant prefill after the generation prompt', () {
      final prompt = formatter.format(
        messages: const [PromptUserMessage('Hello')],
        tools: const [],
        reasoningMode: 'off',
        assistantPrefill: '## Goal\n',
      );
      expect(prompt, endsWith('<|im_start|>assistant\n## Goal\n'));
    });

    test('system message without tools', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are a coder.'),
          PromptUserMessage('Hello'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system\nYou are a coder.'));
      expect(prompt, isNot(contains('<tools>')));
    });

    test('renders required field on parameters', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<required>["query"]</required>'));
    });

    test('groups consecutive tool responses under single user block', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Do two searches.'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'search',
                arguments: {'query': 'a'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'c1',
            name: 'search',
            content: 'Result A',
          ),
          PromptToolMessage(
            toolCallId: 'c2',
            name: 'search',
            content: 'Result B',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      // Both tool responses should be under one <|im_start|>user block.
      final userStarts = '<|im_start|>user'.allMatches(prompt).length;
      expect(userStarts, 2); // One for the user message, one for tool group.
    });

    test('stopSequences and addBos', () {
      expect(
        formatter.stopSequences,
        containsAll(['<|im_end|>', '<|im_start|>']),
      );
      expect(formatter.addBos, isTrue);
    });

    test('renders enum values in tool parameter definition', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [
          PromptTool(
            name: 'set_mode',
            description: 'Set mode',
            parameters: {
              'type': 'object',
              'properties': {
                'mode': {
                  'type': 'string',
                  'description': 'The mode',
                  'enum': ['fast', 'slow'],
                },
              },
              'required': ['mode'],
            },
          ),
        ],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<enum>["fast","slow"]</enum>'));
    });

    test('never injects think blocks even with reasoningContent', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Think'),
          PromptAssistantMessage(
            content: 'Done.',
            reasoning: 'I thought hard.',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, isNot(contains('<think>')));
      expect(prompt, contains('Done.'));
    });

    test('writes content as-is even if it contains think tags', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Think'),
          PromptAssistantMessage(
            content: '<think>\nI thought\n</think>\nDone.',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      // Content is written verbatim — no parsing or re-wrapping.
      expect(
        prompt,
        contains('<think>\nI thought\n</think>\nDone.'),
      );
    });

    test('assistant message writes plain content regardless of position', () {
      // Multi-turn: assistant before and after the last user query.
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('First question'),
          PromptAssistantMessage(content: 'First answer.'),
          PromptUserMessage('Second question'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('<|im_start|>assistant\nFirst answer.<|im_end|>'),
      );
    });

    test('multi-step tool calls write assistant messages plainly', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Do stuff'),
          PromptAssistantMessage(
            content: 'Calling tool.',
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'search',
                arguments: {'query': 'x'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'c1',
            name: 'search',
            content: 'Result',
          ),
          PromptAssistantMessage(
            content: 'Middle step.',
            toolCalls: [
              ToolCallDefault(
                id: 'c2',
                name: 'search',
                arguments: {'query': 'y'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'c2',
            name: 'search',
            content: 'Result 2',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      // No <think> blocks injected anywhere.
      expect(prompt, isNot(contains('<think>')));
      expect(prompt, contains('Middle step.'));
    });

    test('tool definition with missing properties key', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [
          PromptTool(
            name: 'noop',
            description: 'No-op',
            parameters: {'type': 'object'},
          ),
        ],
        reasoningMode: 'on',
      );

      // Missing 'properties' → rawProps is null → empty map → no <parameter>.
      expect(prompt, contains('<name>noop</name>'));
      expect(prompt, contains('<parameters>'));
    });

    test('tool parameter with non-map spec value', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [
          PromptTool(
            name: 'weird',
            description: 'Weird',
            parameters: {
              'type': 'object',
              'properties': {
                'broken': 'not-a-map',
              },
            },
          ),
        ],
        reasoningMode: 'on',
      );

      // entry.value is String (not Map) → rawSpec = {} → no type/desc.
      expect(prompt, contains('<name>broken</name>'));
    });

    test('renders tool call with map/list argument values as JSON', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'complex_tool',
                arguments: {
                  'filters': {'status': 'active'},
                  'tags': ['a', 'b'],
                },
              ),
            ],
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('{"status":"active"}'));
      expect(prompt, contains('["a","b"]'));
    });

    test('default system prompt when tools present but no system message', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains(
          'You are Qwen, a helpful AI assistant that can interact with a '
          'computer to solve tasks.',
        ),
      );
      expect(prompt, contains('<tools>'));
    });

    test('no default system prompt without tools and no system message', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, isNot(contains('You are Qwen')));
      expect(prompt, isNot(contains('<|im_start|>system')));
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
  });
}
