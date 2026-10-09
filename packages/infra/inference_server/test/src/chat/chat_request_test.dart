import 'dart:convert';

import 'package:inference/inference.dart';
import 'package:inference_server/src/chat/chat_request.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

ChatRequest _parsed(Map<String, Object?> body) =>
    (ChatRequestParser.parse(jsonEncode(body)) as ChatRequestParsed).request;

String _invalid(Object? body) =>
    (ChatRequestParser.parse(body is String ? body : jsonEncode(body))
            as ChatRequestInvalid)
        .message;

const _hello = {
  'messages': [
    {'role': 'user', 'content': 'hi'},
  ],
};

void main() {
  group('ChatRequestParser', () {
    test('reads every field the app sends', () {
      final request = _parsed({
        'model': 'qwen',
        'stream': true,
        'stream_options': {'include_usage': true},
        'max_completion_tokens': 64,
        'max_tokens': 32,
        'temperature': 1,
        'top_p': 0.5,
        'seed': 7,
        'frequency_penalty': 0.25,
        'presence_penalty': 0.75,
        'reasoning_effort': 'high',
        'chat_template_kwargs': {'enable_thinking': true},
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'read',
              'description': 'Reads a file.',
              'parameters': {'type': 'object'},
            },
          },
          {
            'type': 'function',
            'function': {'name': 'bare'},
          },
        ],
        'messages': [
          {'role': 'system', 'content': 'be terse'},
          {'role': 'developer', 'content': 'dev notes'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'look '},
              {'type': 'image_url', 'image_url': 'x'},
              {'type': 'text', 'text': 'here'},
            ],
          },
          {
            'role': 'assistant',
            'content': null,
            'reasoning_content': 'thinking',
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'read', 'arguments': '{"path":"a"}'},
              },
              {
                'id': 'call_2',
                'type': 'function',
                'function': {'name': 'read', 'arguments': 'not json'},
              },
              {
                'id': 'call_3',
                'type': 'function',
                'function': {'name': 'read', 'arguments': '[1]'},
              },
              {
                'id': 'call_4',
                'type': 'function',
                'function': {'name': 'list'},
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'call_1', 'content': 'file a'},
          {
            'role': 'tool',
            'tool_call_id': 'call_9',
            'name': 'named',
            'content': 'x',
          },
          {'role': 'tool', 'tool_call_id': 'call_8', 'content': 'y'},
        ],
      });

      expect(request.model, 'qwen');
      expect(request.stream, isTrue);
      expect(request.includeUsage, isTrue);
      expect(request.maxTokens, 64);
      expect(request.temperature, 1.0);
      expect(request.topP, 0.5);
      expect(request.seed, 7);
      expect(request.frequencyPenalty, 0.25);
      expect(request.presencePenalty, 0.75);
      expect(request.reasoningEffort, 'high');
      expect(request.enableThinking, isTrue);
      expect(
        [for (final tool in request.tools) tool.name],
        ['read', 'bare'],
      );
      expect(request.tools.first.parameters, {'type': 'object'});
      expect(request.tools.last.description, '');
      expect(request.tools.last.parameters, isEmpty);

      final messages = request.messages;
      expect((messages[0] as PromptSystemMessage).content, 'be terse');
      expect((messages[1] as PromptDeveloperMessage).content, 'dev notes');
      expect((messages[2] as PromptUserMessage).content, 'look here');
      final assistant = messages[3] as PromptAssistantMessage;
      expect(assistant.content, '');
      expect(assistant.reasoning, 'thinking');
      expect(
        [for (final call in assistant.toolCalls) call.arguments],
        [
          {'path': 'a'},
          isEmpty,
          isEmpty,
          isEmpty,
        ],
      );
      expect(assistant.toolCalls.first, isA<ToolCallDefault>());
      expect((messages[4] as PromptToolMessage).name, 'read');
      expect((messages[4] as PromptToolMessage).toolCallId, 'call_1');
      expect((messages[5] as PromptToolMessage).name, 'named');
      expect((messages[6] as PromptToolMessage).name, '');
    });

    test('defaults what a plain OpenAI client leaves out', () {
      final request = _parsed(_hello);

      expect(request.model, isNull);
      expect(request.stream, isFalse);
      expect(request.includeUsage, isFalse);
      expect(request.tools, isEmpty);
      expect(request.maxTokens, isNull);
      expect(request.stopSequences, isEmpty);
      expect(request.enableThinking, isNull);
    });

    test('falls back to max_tokens', () {
      expect(_parsed({..._hello, 'max_tokens': 9}).maxTokens, 9);
    });

    test('refuses a token limit below one', () {
      expect(
        _invalid({..._hello, 'max_tokens': 0}),
        'request.max_tokens must be at least 1.',
      );
      expect(
        _invalid({..._hello, 'max_completion_tokens': -3, 'max_tokens': 5}),
        'request.max_completion_tokens must be at least 1.',
      );
    });

    test('reads a single stop sequence', () {
      expect(_parsed({..._hello, 'stop': 'END'}).stopSequences, ['END']);
    });

    test('reads a list of stop sequences', () {
      expect(
        _parsed({
          ..._hello,
          'stop': ['a', 'b', 'c', 'd'],
        }).stopSequences,
        ['a', 'b', 'c', 'd'],
      );
    });

    test('refuses more than four stop sequences', () {
      expect(
        _invalid({
          ..._hello,
          'stop': ['a', 'b', 'c', 'd', 'e'],
        }),
        'request.stop must be a string or a list of at most 4 strings.',
      );
    });

    test('refuses stop sequences that are not strings', () {
      expect(
        _invalid({
          ..._hello,
          'stop': ['a', 1],
        }),
        'request.stop must be a string or a list of at most 4 strings.',
      );
      expect(
        _invalid({..._hello, 'stop': 7}),
        'request.stop must be a string or a list of at most 4 strings.',
      );
    });

    test('refuses a body that is not JSON', () {
      expect(_invalid('{'), startsWith('The body is not JSON'));
    });

    test('refuses a body that is not an object', () {
      expect(_invalid([1]), 'request must be an object.');
    });

    test('refuses a request without messages', () {
      expect(_invalid(<String, Object?>{}), 'request.messages is required.');
    });

    test('refuses an empty conversation', () {
      expect(_invalid({'messages': <Object?>[]}), 'messages is empty.');
    });

    test('refuses a field of the wrong type', () {
      expect(
        _invalid({..._hello, 'stream': 'yes'}),
        'request.stream has the wrong type.',
      );
    });

    test('refuses an unknown role', () {
      expect(
        _invalid({
          'messages': [
            {'role': 'narrator', 'content': 'x'},
          ],
        }),
        'request.messages[0].role narrator is not supported.',
      );
    });

    test('refuses content that is neither text nor parts', () {
      expect(
        _invalid({
          'messages': [
            {'role': 'user', 'content': 3},
          ],
        }),
        'request.messages[0].content must be a string or a list of parts.',
      );
    });

    test('refuses a tool call without an id', () {
      expect(
        _invalid({
          'messages': [
            {
              'role': 'assistant',
              'tool_calls': [
                {
                  'function': {'name': 'read'},
                },
              ],
            },
          ],
        }),
        'request.messages[0].tool_calls[0].id is required.',
      );
    });
  });

  group('ChatRequest', () {
    test('lays the request sampling over the model defaults', () {
      final sampling =
          _parsed({
            ..._hello,
            'temperature': 0.2,
            'seed': 3,
            'frequency_penalty': 0.1,
            'presence_penalty': 0.4,
          }).samplingOver(
            const ModelSamplingDefaults(
              temperature: 0.6,
              topK: 20,
              topP: 0.95,
              minP: 0.05,
              penaltyRepeat: 1.1,
              penaltyLastN: 128,
            ),
          );

      expect(
        sampling,
        const EngineSampling(
          seed: 3,
          temperature: 0.2,
          topK: 20,
          topP: 0.95,
          minP: 0.05,
          penaltyRepeat: 1.1,
          penaltyLastN: 128,
          penaltyFreq: 0.1,
          penaltyPresent: 0.4,
        ),
      );
    });

    group('reasoning mode', () {
      String modeFor(
        ModelReasoning reasoning, {
        String? effort,
        bool? enableThinking,
      }) => _parsed({
        ..._hello,
        'reasoning_effort': ?effort,
        if (enableThinking != null)
          'chat_template_kwargs': {'enable_thinking': enableThinking},
      }).reasoningModeFor(reasoning);

      const efforts = ModelReasoningEfforts(efforts: ['low', 'medium', 'high']);

      test('a model without reasoning is always off', () {
        expect(
          modeFor(const ModelReasoningNone(), enableThinking: true),
          'off',
        );
      });

      test('a model that always reasons is always on', () {
        expect(modeFor(const ModelReasoningAlways(), effort: 'none'), 'on');
      });

      test('a toggle is on unless declined', () {
        const toggle = ModelReasoningToggle();
        expect(modeFor(toggle), 'on');
        expect(modeFor(toggle, enableThinking: true), 'on');
        expect(modeFor(toggle, enableThinking: false), 'off');
        expect(modeFor(toggle, effort: 'none'), 'off');
        expect(modeFor(toggle, effort: 'low', enableThinking: false), 'on');
      });

      test('efforts take the asked-for effort', () {
        expect(modeFor(efforts, effort: 'high'), 'high');
      });

      test('efforts default to medium', () {
        expect(modeFor(efforts), 'medium');
        expect(modeFor(efforts, effort: 'extreme'), 'medium');
      });

      test('efforts without medium default to the first', () {
        expect(
          modeFor(const ModelReasoningEfforts(efforts: ['quick', 'deep'])),
          'quick',
        );
      });

      test('declining efforts takes the lowest', () {
        expect(modeFor(efforts, effort: 'none'), 'low');
        expect(modeFor(efforts, enableThinking: false), 'low');
      });
    });
  });
}
