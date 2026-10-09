import 'dart:convert';

import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  const formatter = HarmonyPromptFormatter();

  group('HarmonyPromptFormatter', () {
    test('formats system message with channel instructions', () {
      final result = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, contains('<|start|>system<|message|>'));
      expect(
        result,
        contains(
          'You are ChatGPT, a large language model trained by OpenAI.',
        ),
      );
      expect(result, contains('Knowledge cutoff: 2024-06'));
      expect(result, contains('# Valid channels'));
      expect(result, contains('<|end|>'));
      expect(result, contains('<|start|>developer<|message|>'));
      expect(result, contains('# Instructions'));
      expect(result, contains('You are helpful.'));
    });

    test('includes reasoning effort medium when enabled', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, contains('Reasoning: medium'));
    });

    test('includes reasoning effort low', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'low',
      );

      expect(result, contains('Reasoning: low'));
    });

    test('formats user message', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hello world'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, contains('<|start|>user<|message|>Hello world<|end|>'));
    });

    test('formats assistant final message', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptAssistantMessage(content: 'Hello!'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains(
          '<|start|>assistant<|channel|>final<|message|>Hello!<|end|>',
        ),
      );
    });

    test('formats tool definitions in TypeScript namespace syntax', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Weather?'),
        ],
        tools: const [
          PromptTool(
            name: 'get_weather',
            description: 'Get the weather',
            parameters: {
              'type': 'object',
              'properties': {
                'location': {
                  'type': 'string',
                  'description': 'City name',
                },
                'unit': {
                  'type': 'string',
                  'enum': ['celsius', 'fahrenheit'],
                },
              },
              'required': ['location'],
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('namespace functions {'));
      expect(result, contains('// Get the weather'));
      expect(result, contains('type get_weather = (_: {'));
      expect(result, contains('location: string'));
      expect(result, contains('unit?: "celsius" | "fahrenheit"'));
      expect(result, contains('} // namespace functions'));
      expect(
        result,
        contains(
          "Calls to these tools must go to the commentary channel: 'functions'.",
        ),
      );
    });

    test('formats tool call in assistant message', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Weather?'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: '1',
                name: 'get_weather',
                arguments: {'location': 'Paris'},
              ),
            ],
          ),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains(
          '<|start|>assistant<|channel|>commentary to=functions.get_weather',
        ),
      );
      expect(result, contains('<|constrain|>json<|message|>'));
      expect(result, contains(jsonEncode({'location': 'Paris'})));
      expect(result, contains('<|call|>'));
    });

    test('formats tool result', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Weather?'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: '1',
                name: 'get_weather',
                arguments: {'location': 'Paris'},
              ),
            ],
          ),
          PromptToolMessage(
            toolCallId: '',
            name: 'get_weather',
            content: '22°C and sunny',
          ),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains(
          '<|start|>functions.get_weather'
          ' to=assistant<|channel|>commentary<|message|>',
        ),
      );
      expect(result, contains(jsonEncode('22°C and sunny')));
    });

    test('formats analysis/reasoning in tool call turn', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Weather?'),
          PromptAssistantMessage(
            reasoning: 'I should check the weather.',
            toolCalls: [
              ToolCallDefault(
                id: '1',
                name: 'get_weather',
                arguments: {'location': 'Tokyo'},
              ),
            ],
          ),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains(
          '<|start|>assistant<|channel|>analysis<|message|>'
          'I should check the weather.<|end|>',
        ),
      );
    });

    test('prunes analysis on past tool-call turn after a later final', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('A?'),
          PromptAssistantMessage(
            reasoning: 'thinking-A',
            toolCalls: [
              ToolCallDefault(
                id: '1',
                name: 'get_x',
                arguments: {'q': 'a'},
              ),
            ],
          ),
          PromptToolMessage(toolCallId: '', name: 'get_x', content: 'rx'),
          PromptAssistantMessage(content: 'X'),
          PromptUserMessage('B?'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, isNot(contains('analysis<|message|>thinking-A')));
      expect(
        result,
        contains('<|channel|>final<|message|>X<|end|>'),
      );
    });

    test(
      'prunes multiple consecutive past tool-call analyses before a final',
      () {
        final result = formatter.format(
          messages: const [
            PromptUserMessage('go'),
            PromptAssistantMessage(
              reasoning: 'reasoning-A',
              toolCalls: [
                ToolCallDefault(id: '1', name: 'step', arguments: {'n': 1}),
              ],
            ),
            PromptToolMessage(toolCallId: '', name: 'step', content: 'r1'),
            PromptAssistantMessage(
              reasoning: 'reasoning-B',
              toolCalls: [
                ToolCallDefault(id: '2', name: 'step', arguments: {'n': 2}),
              ],
            ),
            PromptToolMessage(toolCallId: '', name: 'step', content: 'r2'),
            PromptAssistantMessage(content: 'done'),
            PromptUserMessage('next'),
          ],
          tools: const [],
          reasoningMode: 'medium',
        );

        expect(result, isNot(contains('analysis<|message|>reasoning-A')));
        expect(result, isNot(contains('analysis<|message|>reasoning-B')));
      },
    );

    test('retains analysis on tool-call turn that follows a past final', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('A?'),
          PromptAssistantMessage(
            reasoning: 'reasoning-A',
            toolCalls: [
              ToolCallDefault(id: '1', name: 'get_x', arguments: {'q': 'a'}),
            ],
          ),
          PromptToolMessage(toolCallId: '', name: 'get_x', content: 'rx'),
          PromptAssistantMessage(content: 'X'),
          PromptUserMessage('B?'),
          PromptAssistantMessage(
            reasoning: 'reasoning-B',
            toolCalls: [
              ToolCallDefault(id: '2', name: 'get_x', arguments: {'q': 'b'}),
            ],
          ),
          PromptToolMessage(toolCallId: '', name: 'get_x', content: 'ry'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, isNot(contains('analysis<|message|>reasoning-A')));
      expect(result, contains('analysis<|message|>reasoning-B'));
    });

    test('null reasoning emits no analysis block even with a later final', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('A?'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: '1', name: 'get_x', arguments: {'q': 'a'}),
            ],
          ),
          PromptToolMessage(toolCallId: '', name: 'get_x', content: 'rx'),
          PromptAssistantMessage(content: 'X'),
          PromptUserMessage('B?'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, isNot(contains('<|channel|>analysis<|message|>')));
    });

    test('ends with generation prompt', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(result, endsWith('<|start|>assistant'));
    });

    test('primes the final channel via an empty analysis channel', () {
      final result = formatter.format(
        messages: const [PromptUserMessage('Hi')],
        tools: const [],
        reasoningMode: 'medium',
        assistantPrefill: '## Goal\n',
      );

      expect(
        result,
        endsWith(
          '<|start|>assistant<|channel|>analysis<|message|><|end|>'
          '<|start|>assistant<|channel|>final<|message|>## Goal\n',
        ),
      );
    });

    test('stop sequences include call and return but not end', () {
      expect(
        formatter.stopSequences,
        containsAll(['<|call|>', '<|return|>']),
      );
      expect(formatter.stopSequences, isNot(contains('<|end|>')));
    });

    test('addBos is true', () {
      expect(formatter.addBos, isTrue);
    });

    test('handles no-params tool', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Run'),
        ],
        tools: const [
          PromptTool(
            name: 'noop',
            description: 'Does nothing',
            parameters: {'type': 'object', 'properties': {}},
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('type noop = () => any;'));
    });

    test('treats extra system messages as user messages', () {
      final result = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hi'),
          PromptSystemMessage('Extra system note.'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      // The second system message should be rendered as a user message.
      expect(
        result,
        contains(
          '<|start|>user<|message|>Extra system note.<|end|>',
        ),
      );
    });

    test('handles tool with missing properties key', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'ping',
            description: 'Ping',
            parameters: {'type': 'object'},
          ),
        ],
        reasoningMode: 'medium',
      );

      // No 'properties' key → rawProps is null → empty map → no-params.
      expect(result, contains('type ping = () => any;'));
    });

    test('handles property without description', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'act',
            description: 'Act on it',
            parameters: {
              'type': 'object',
              'properties': {
                'mode': {'type': 'string'},
              },
              'required': ['mode'],
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      // Should render property without a '// description' comment.
      expect(result, contains('mode: string'));
      expect(result, isNot(contains('// \nmode')));
    });

    test('converts nested object type to TypeScript object literal', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'create',
            description: 'Create',
            parameters: {
              'type': 'object',
              'properties': {
                'meta': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'},
                    'age': {'type': 'integer'},
                  },
                  'required': ['name'],
                },
              },
              'required': ['meta'],
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('meta: { name: string, age?: number }'));
    });

    test('converts bare object type (no properties) to "object"', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'create',
            description: 'Create',
            parameters: {
              'type': 'object',
              'properties': {
                'data': {'type': 'object'},
              },
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('data?: object'));
    });

    test('converts unknown type to "any"', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'create',
            description: 'Create',
            parameters: {
              'type': 'object',
              'properties': {
                'data': {'type': 'null'},
              },
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('data?: any'));
    });

    test('handles property with non-map spec value', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'act',
            description: 'Act',
            parameters: {
              'type': 'object',
              'properties': {
                'broken': 'not-a-map',
              },
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      // Non-map spec → empty map → type resolves to 'any'.
      expect(result, contains('broken?: any'));
    });

    test('nested object with non-map property spec falls back to any', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'act',
            description: 'Act',
            parameters: {
              'type': 'object',
              'properties': {
                'data': {
                  'type': 'object',
                  'properties': {
                    'bad': 'not-a-map',
                  },
                  'required': ['bad'],
                },
              },
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      // Nested property 'bad' has non-map spec → empty map → 'any'.
      expect(result, contains('bad: any'));
    });

    test('converts nested object types to TypeScript', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [
          PromptTool(
            name: 'create',
            description: 'Create item',
            parameters: {
              'type': 'object',
              'properties': {
                'tags': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'count': {'type': 'integer'},
                'flag': {'type': 'boolean'},
              },
              'required': ['tags', 'count'],
            },
          ),
        ],
        reasoningMode: 'medium',
      );

      expect(result, contains('tags: string[]'));
      expect(result, contains('count: number'));
      expect(result, contains('flag?: boolean'));
    });

    test('renders developer messages in the developer channel', () {
      final result = formatter.format(
        messages: const [
          PromptDeveloperMessage('Developer rules.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains('<|start|>developer<|message|># Instructions'),
      );
      expect(result, contains('Developer rules.'));
    });

    test('renders non-leading developer messages in the developer channel', () {
      final result = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptDeveloperMessage('Later developer rules.'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(
        result,
        contains('<|start|>developer<|message|>Later developer rules.<|end|>'),
      );
    });
  });
}
