// Byte-exact golden assertions need adjacent string literals without
// whitespace between them — the rendered output really is contiguous.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('GlmPromptFormatter', () {
    const formatter = GlmPromptFormatter();
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

    test('reports prefilled reasoning unless reasoning is off', () {
      expect(formatter.prefillsReasoning('on'), isTrue);
      expect(formatter.prefillsReasoning('off'), isFalse);
    });

    test('always emits [gMASK]<sop> prefix', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(prompt, startsWith('[gMASK]<sop>'));
    });

    test('plain user → assistant ends with <|assistant|><think>', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(prompt, '[gMASK]<sop><|user|>hi<|assistant|><think>');
    });

    test('reasoning off swaps trailing <think> for </think>', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('hi'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );
      expect(prompt, endsWith('<|assistant|></think>'));
    });

    test('appends an assistant prefill after the think tag', () {
      final off = formatter.format(
        messages: const [PromptUserMessage('hi')],
        tools: const [],
        reasoningMode: 'off',
        assistantPrefill: '## Goal\n',
      );
      expect(off, endsWith('<|assistant|></think>## Goal\n'));

      final on = formatter.format(
        messages: const [PromptUserMessage('hi')],
        tools: const [],
        reasoningMode: 'on',
        assistantPrefill: '## Goal\n',
      );
      expect(on, endsWith('<|assistant|><think>## Goal\n'));
    });

    test('system message renders inline', () {
      final prompt = formatter.format(
        messages: const [
          PromptSystemMessage('You are helpful.'),
          PromptUserMessage('hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(
        prompt,
        '[gMASK]<sop><|system|>You are helpful.<|user|>hi<|assistant|><think>',
      );
    });

    test('tools block byte-exact match against Jinja2 rendering', () {
      // Golden: rendered against the reference Jinja2 template with
      // tojson configured to emit compact JSON (separators=(",",":")) —
      // matching dart:convert's jsonEncode. Equivalence on this fixture
      // is the proof that the structural template port is faithful.
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('hi'),
        ],
        tools: const [tool],
        reasoningMode: 'on',
      );
      expect(
        prompt,
        '[gMASK]<sop><|system|>\n'
        '# Tools\n\n'
        'You may call one or more functions to assist with the user query.\n\n'
        'You are provided with function signatures within <tools></tools> XML tags:\n'
        '<tools>\n'
        '{"type":"function","function":{"name":"search",'
        '"description":"Search the web","parameters":{"type":"object",'
        '"properties":{"query":{"type":"string",'
        '"description":"Search query"}},"required":["query"]}}}\n'
        '</tools>\n\n'
        'For each function call, output the function name and arguments '
        'within the following XML format:\n'
        '<tool_call>{function-name}<arg_key>{arg-key-1}</arg_key>'
        '<arg_value>{arg-value-1}</arg_value>'
        '<arg_key>{arg-key-2}</arg_key><arg_value>{arg-value-2}</arg_value>'
        '...</tool_call>'
        '<|user|>hi<|assistant|><think>',
      );
    });

    test('past assistant (before last user) emits bare </think>', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('first'),
          PromptAssistantMessage(
            content: 'old answer',
            reasoning: 'old thoughts',
          ),
          PromptUserMessage('second'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(
        prompt,
        '[gMASK]<sop>'
        '<|user|>first'
        '<|assistant|></think>old answer'
        '<|user|>second'
        '<|assistant|><think>',
      );
    });

    test('current assistant (after last user) preserves reasoning', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('q'),
          PromptAssistantMessage(
            content: 'a',
            reasoning: 'mulling',
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(
        prompt,
        '[gMASK]<sop>'
        '<|user|>q'
        '<|assistant|><think>mulling</think>a'
        '<|assistant|><think>',
      );
    });

    test(
      'extracts <think>...</think> from content when reasoningContent unset',
      () {
        final prompt = formatter.format(
          messages: const [
            PromptUserMessage('q'),
            PromptAssistantMessage(
              content: '<think>\ninner\n</think>\nfinal answer',
            ),
          ],
          tools: const [],
          reasoningMode: 'on',
        );
        expect(prompt, contains('<think>inner</think>final answer'));
      },
    );

    test(
      'assistant w/ no reasoning AND no content emits </think> only',
      () {
        final prompt = formatter.format(
          messages: const [
            PromptUserMessage('q'),
            PromptAssistantMessage(),
          ],
          tools: const [],
          reasoningMode: 'on',
        );
        expect(
          prompt,
          '[gMASK]<sop>'
          '<|user|>q'
          '<|assistant|></think>'
          '<|assistant|><think>',
        );
      },
    );

    test('tool call byte-exact (string args)', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('go'),
          PromptAssistantMessage(
            content: 'calling',
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'search',
                arguments: {'query': 'cows', 'limit': 5},
              ),
            ],
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(
        prompt,
        '[gMASK]<sop>'
        '<|user|>go'
        '<|assistant|></think>calling'
        '<tool_call>search'
        '<arg_key>query</arg_key><arg_value>cows</arg_value>'
        '<arg_key>limit</arg_key><arg_value>5</arg_value>'
        '</tool_call>'
        '<|assistant|><think>',
      );
    });

    test('non-string tool-call args are JSON-encoded', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(
                id: 'c1',
                name: 'fn',
                arguments: {
                  'flag': true,
                  'list': [1, 2],
                  'nested': {'a': 1},
                },
              ),
            ],
          ),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      expect(prompt, contains('<arg_value>true</arg_value>'));
      expect(prompt, contains('<arg_value>[1,2]</arg_value>'));
      expect(prompt, contains('<arg_value>{"a":1}</arg_value>'));
    });

    test(
      'first tool message gets <|observation|>, consecutive ones do not',
      () {
        final prompt = formatter.format(
          messages: const [
            PromptUserMessage('go'),
            PromptAssistantMessage(
              toolCalls: [
                ToolCallDefault(id: 'c1', name: 'fn', arguments: {}),
              ],
            ),
            PromptToolMessage(toolCallId: 'c1', name: 'unknown', content: 'r1'),
            PromptToolMessage(toolCallId: 'c1', name: 'unknown', content: 'r2'),
          ],
          tools: const [],
          reasoningMode: 'on',
        );
        expect(
          prompt,
          contains(
            '<|observation|>'
            '<tool_response>r1</tool_response>'
            '<tool_response>r2</tool_response>',
          ),
        );
        // <|observation|> should appear exactly once.
        expect('<|observation|>'.allMatches(prompt).length, 1);
      },
    );

    test('tool message after non-tool gets fresh <|observation|>', () {
      final prompt = formatter.format(
        messages: const [
          PromptUserMessage('go'),
          PromptAssistantMessage(
            toolCalls: [
              ToolCallDefault(id: 'c1', name: 'fn', arguments: {}),
            ],
          ),
          PromptToolMessage(toolCallId: 'c1', name: 'unknown', content: 'r1'),
          PromptAssistantMessage(content: 'mid'),
          PromptToolMessage(toolCallId: 'c1', name: 'unknown', content: 'r2'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );
      // Two distinct observation blocks because the tool sequence was broken.
      expect('<|observation|>'.allMatches(prompt).length, 2);
    });

    test('addBos is false (template emits [gMASK]<sop> inline)', () {
      expect(formatter.addBos, isFalse);
    });

    test('stop sequences cover all role boundaries', () {
      expect(
        formatter.stopSequences,
        containsAll(<String>['<|user|>', '<|observation|>', '<|system|>']),
      );
    });

    test('folds developer messages into system-style blocks', () {
      final prompt = formatter.format(
        messages: const [
          PromptDeveloperMessage('Developer rules.'),
          PromptUserMessage('Hi'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|system|>Developer rules.'));
    });
  });
}
