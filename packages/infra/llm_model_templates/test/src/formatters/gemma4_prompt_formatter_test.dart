import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('Gemma4PromptFormatter', () {
    const formatter = Gemma4PromptFormatter();
    const tool = PromptTool(
      name: 'search',
      description: 'Search the web',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search query'},
        },
        'required': ['query'],
      },
    );

    test('basic conversation with system, user, and assistant', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Hello!'),
          PromptAssistantMessage(content: 'Hi there!'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|turn>system\n'));
      expect(prompt, contains('<|think|>\n'));
      expect(prompt, contains('You are helpful.'));
      expect(prompt, contains('<|turn>user\nHello!'));
      expect(prompt, contains('<|turn>model\nHi there!'));
      expect(prompt, isNot(contains('assistant')));
    });

    test('includes think token when reasoning is on', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('Be concise.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|think|>\n'));
    });

    test('omits think token and adds empty thinking block when off', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, isNot(contains('<|think|>')));
      expect(prompt, endsWith('<|turn>model\n<|channel>thought\n<channel|>'));
    });

    test('appends an assistant prefill after the generation prompt', () {
      final off = formatter.format(
        messages: const [PromptUserMessage('Hi')],
        tools: const [],
        reasoningMode: 'off',
        assistantPrefill: '## Goal\n',
      );
      expect(
        off,
        endsWith('<|turn>model\n<|channel>thought\n<channel|>## Goal\n'),
      );

      final on = formatter.format(
        messages: const [PromptUserMessage('Hi')],
        tools: const [],
        reasoningMode: 'on',
        assistantPrefill: '## Goal\n',
      );
      expect(on, endsWith('<|turn>model\n## Goal\n'));
    });

    test('renders tool declarations in system block', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('Search'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|tool>declaration:search{'));
      expect(prompt, contains('description:<|"|>Search the web<|"|>'));
      expect(prompt, contains('type:<|"|>STRING<|"|>'));
      expect(prompt, contains('type:<|"|>OBJECT<|"|>'));
      expect(prompt, contains('<tool|>'));
      expect(prompt, contains('required:[<|"|>query<|"|>]'));
    });

    test('tool calls in assistant history', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Find cows.'),
          PromptAssistantMessage(
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
            content: 'Cows are mammals.',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('<|tool_call>call:search{query:<|"|>cows<|"|>}<tool_call|>'),
      );
    });

    test('tool responses are forward-scanned inline', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Find cows.'),
          PromptAssistantMessage(
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
            content: 'Cows are mammals.',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains(
          '<|tool_response>response:search'
          '{value:<|"|>Cows are mammals.<|"|>}<tool_response|>',
        ),
      );
      // Tool messages should NOT generate their own <|turn>tool turns.
      expect(prompt, isNot(contains('<|turn>tool')));
    });

    test('model turn continuation after tool responses', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Find cows.'),
          PromptAssistantMessage(
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
            content: 'Cows are mammals.',
          ),
          PromptAssistantMessage(content: 'Cows are large mammals!'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      // The second assistant message should NOT have <|turn>model.
      // Count occurrences of <|turn>model — should be 1 (generation prompt).
      final turnModelCount = '<|turn>model'.allMatches(prompt).length;
      // One in the history for the first assistant + one for generation prompt
      // BUT the first assistant continues into the second, so...
      // Actually: first assistant gets <|turn>model, second does NOT
      // (continuation), and generation prompt adds another.
      expect(turnModelCount, 2); // first assistant + generation prompt
    });

    test(
      'narrated tool call with thinking off still emits a generation prompt',
      () {
        // A small model with thinking off narrates before its tool call, so the
        // planning prose lands in `content`. The reference gemma jinja closes
        // the turn and suppresses the generation prompt here, stranding the
        // model on a finished conversation — it stops after the tool. We diverge
        // so a fresh model turn opens for the answer.
        final prompt = formatter.format(
          messages: const [
            PromptUserMessage('Find cows.'),
            PromptAssistantMessage(
              content: "The user wants cows. I'll search.",
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
              content: 'Cows are mammals.',
            ),
          ],
          tools: const [tool],
          reasoningMode: 'off',
        );

        // Must end on an open model turn to answer into, not a closed <turn|>.
        expect(prompt, endsWith('<|turn>model\n<|channel>thought\n<channel|>'));
      },
    );

    test('reasoning content rendered only after last user with tool calls', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Find cows.'),
          PromptAssistantMessage(
            reasoning: 'I should search for cows.',
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
            content: 'Cows are mammals.',
          ),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains(
          '<|channel>thought\nI should search for cows.\n<channel|>',
        ),
      );
    });

    test('reasoning content NOT rendered for messages before last user', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('First question'),
          PromptAssistantMessage(
            content: 'First answer',
            reasoning: 'old thinking',
            toolCalls: [
              ToolCallDefault(id: 'c1', name: 'search', arguments: {'q': 'x'}),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'c1',
            name: 'search',
            content: 'result',
          ),
          PromptAssistantMessage(content: 'Here you go.'),
          PromptUserMessage('Second question'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      // Reasoning from before the last user message should be stripped.
      expect(prompt, isNot(contains('old thinking')));
    });

    test('reasoning content NOT rendered without tool calls', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptAssistantMessage(
            content: 'Hello!',
            reasoning: 'thinking...',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, isNot(contains('<|channel>thought')));
    });

    test('strips thinking from model content', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
          PromptAssistantMessage(
            content: '<|channel>thought\nsome thinking\n<channel|>visible text',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, isNot(contains('some thinking')));
      expect(prompt, contains('visible text'));
    });

    test('no system block when no system message, tools, or thinking', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, isNot(contains('<|turn>system')));
    });

    test('system block emitted for thinking even without system message', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|turn>system\n<|think|>\n<turn|>\n'));
    });

    test('stopSequences are correct', () {
      expect(formatter.stopSequences, ['<turn|>', '<|turn>']);
    });

    test('addBos is true', () {
      expect(formatter.addBos, isTrue);
    });

    test('user content is trimmed', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('  hello  '),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, contains('<|turn>user\nhello<turn|>'));
    });

    test('tool calls without responses emit bare tool_response', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: 'c1', name: 'search', arguments: {'q': 'x'}),
            ],
          ),
          // No tool response message follows.
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );

      expect(
        prompt,
        contains('<tool_call|><|tool_response>'),
      );
    });

    test('renders tool with STRING enum property', () {
      const enumTool = PromptTool(
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
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [enumTool],
        reasoningMode: 'off',
      );

      expect(prompt, contains('enum:[<|"|>fast<|"|>,<|"|>slow<|"|>]'));
      expect(prompt, contains('type:<|"|>STRING<|"|>'));
    });

    test('renders tool with ARRAY property and items', () {
      const arrayTool = PromptTool(
        name: 'tag',
        description: 'Tag items',
        parameters: {
          'type': 'object',
          'properties': {
            'tags': {
              'type': 'array',
              'description': 'Tag list',
              'items': {'type': 'string'},
            },
          },
          'required': ['tags'],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [arrayTool],
        reasoningMode: 'off',
      );

      expect(prompt, contains('type:<|"|>ARRAY<|"|>'));
      expect(prompt, contains('items:{type:<|"|>STRING<|"|>}'));
    });

    test('renders tool with nullable property after description', () {
      const nullableTool = PromptTool(
        name: 'opt',
        description: 'Optional',
        parameters: {
          'type': 'object',
          'properties': {
            'val': {
              'type': 'string',
              'description': 'A value',
              'nullable': true,
            },
          },
          'required': [],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [nullableTool],
        reasoningMode: 'off',
      );

      // nullable should be preceded by a comma since description was added.
      expect(prompt, contains('description:<|"|>A value<|"|>,nullable:true'));
    });

    test('renders tool with nested OBJECT property', () {
      const nestedTool = PromptTool(
        name: 'config',
        description: 'Configure',
        parameters: {
          'type': 'object',
          'properties': {
            'opts': {
              'type': 'object',
              'description': 'Options',
              'properties': {
                'timeout': {'type': 'integer', 'description': 'Timeout'},
              },
              'required': ['timeout'],
            },
          },
          'required': ['opts'],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [nestedTool],
        reasoningMode: 'off',
      );

      expect(prompt, contains('properties:{timeout:{'));
      expect(prompt, contains('required:[<|"|>timeout<|"|>]'));
      expect(prompt, contains('type:<|"|>OBJECT<|"|>'));
    });

    test('renders tool with multiple sorted properties', () {
      const multiTool = PromptTool(
        name: 'multi',
        description: 'Multi param',
        parameters: {
          'type': 'object',
          'properties': {
            'zebra': {'type': 'string', 'description': 'Z'},
            'alpha': {'type': 'integer', 'description': 'A'},
          },
          'required': ['alpha'],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [multiTool],
        reasoningMode: 'off',
      );

      // Properties should be sorted: alpha before zebra.
      final declMatch = RegExp(
        r'properties:\{(.*?)\},required',
      ).firstMatch(prompt);
      expect(declMatch, isNotNull);
      final propsContent = declMatch!.group(1)!;
      expect(
        propsContent.indexOf('alpha:'),
        lessThan(
          propsContent.indexOf('zebra:'),
        ),
      );
    });

    test('renders items block with map-valued custom key', () {
      const mapItemsTool = PromptTool(
        name: 'cfg',
        description: 'Config',
        parameters: {
          'type': 'object',
          'properties': {
            'vals': {
              'type': 'array',
              'items': {
                'type': 'object',
                'default': {'a': 'b'},
              },
            },
          },
          'required': [],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [mapItemsTool],
        reasoningMode: 'off',
      );

      // The 'default' key in items has a map value — exercises
      // _writeFormattedValue with escapeKeys: true for maps.
      expect(prompt, contains('default:{<|"|>a<|"|>:<|"|>b<|"|>}'));
    });

    test('renders tool with ARRAY items containing nested properties', () {
      const arrayObjTool = PromptTool(
        name: 'batch',
        description: 'Batch items',
        parameters: {
          'type': 'object',
          'properties': {
            'items': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string'},
                },
                'required': ['name'],
              },
            },
          },
          'required': ['items'],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [arrayObjTool],
        reasoningMode: 'off',
      );

      expect(prompt, contains('items:{'));
      expect(prompt, contains('properties:{name:{'));
      expect(prompt, contains('required:[<|"|>name<|"|>]'));
    });

    test('tool call with bool and number argument values', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'fn',
                arguments: {'active': true, 'count': 42},
              ),
            ],
          ),
          PromptToolMessage(toolCallId: 'c1', name: 'fn', content: 'ok'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('active:true'));
      expect(prompt, contains('count:42'));
    });

    test('renders ARRAY items with description and union type', () {
      const arrayDescTool = PromptTool(
        name: 'info',
        description: 'Info',
        parameters: {
          'type': 'object',
          'properties': {
            'data': {
              'type': 'array',
              'items': {
                'type': ['string', 'integer'],
                'description': 'An item',
              },
            },
          },
          'required': ['data'],
        },
      );
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
        ],
        tools: const [arrayDescTool],
        reasoningMode: 'off',
      );

      expect(prompt, contains('items:{'));
      expect(prompt, contains('description:<|"|>An item<|"|>'));
      // Union types are uppercased and formatted as a list.
      expect(
        prompt,
        contains('type:[<|"|>STRING<|"|>,<|"|>INTEGER<|"|>]'),
      );
    });

    test('tool call with map and list argument values', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'fn',
                arguments: {
                  'opts': {'key': 'val'},
                  'tags': ['a', 'b'],
                },
              ),
            ],
          ),
          PromptToolMessage(toolCallId: 'c1', name: 'fn', content: 'ok'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('opts:{key:<|"|>val<|"|>}'));
      expect(prompt, contains('tags:[<|"|>a<|"|>,<|"|>b<|"|>]'));
    });

    test('resolves tool name from toolCallId', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: 'tc-99', name: 'real_name', arguments: {}),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'tc-99',
            name: 'fallback_name',
            content: 'result',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      // Should use the name from the tool call, not the fallback.
      expect(prompt, contains('response:real_name{'));
      expect(prompt, isNot(contains('response:fallback_name')));
    });

    test('falls back to message name when toolCallId does not match', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: 'tc-1', name: 'fn', arguments: {}),
            ],
          ),
          PromptToolMessage(
            toolCallId: 'tc-nomatch',
            name: 'fallback',
            content: 'result',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('response:fallback{'));
    });

    test('tool arguments are sorted alphabetically', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('Go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'fn',
                arguments: {'zebra': 'z', 'alpha': 'a'},
              ),
            ],
          ),
          PromptToolMessage(toolCallId: 'c1', name: 'fn', content: 'ok'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      final callContent = RegExp(
        r'call:fn\{(.*?)\}<tool_call\|>',
      ).firstMatch(prompt)?.group(1);
      expect(callContent, startsWith('alpha:'));
    });

    test('folds developer messages into system-style turns', () {
      final prompt = formatter.format(
        messages: const [
          PromptDeveloperMessage('Developer rules.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|turn>system\n<|think|>\nDeveloper rules.'));
    });
  });
}
