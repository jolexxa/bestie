import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_openai_compat/inference_openai_compat.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class _FakeBaseRequest extends Fake implements http.BaseRequest {}

String _sse(List<Map<String, Object?>> chunks, {bool done = true}) {
  final buffer = StringBuffer();
  for (final chunk in chunks) {
    buffer.write('data: ${jsonEncode(chunk)}\n\n');
  }
  if (done) {
    buffer.write('data: [DONE]\n\n');
  }
  return buffer.toString();
}

Map<String, Object?> _chunk({
  String? content,
  String? reasoningContent,
  String? reasoning,
  List<Map<String, Object?>>? toolCalls,
  String? finishReason,
  Map<String, Object?>? usage,
  bool withChoice = true,
}) => {
  'id': 'chatcmpl-1',
  'object': 'chat.completion.chunk',
  'model': 'test/model',
  if (withChoice)
    'choices': [
      {
        'index': 0,
        'delta': {
          'content': ?content,
          'reasoning_content': ?reasoningContent,
          'reasoning': ?reasoning,
          'tool_calls': ?toolCalls,
        },
        'finish_reason': finishReason,
      },
    ]
  else
    'choices': <Object?>[],
  'usage': ?usage,
};

const _usage = {
  'prompt_tokens': 10,
  'completion_tokens': 5,
  'total_tokens': 15,
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBaseRequest());
  });

  final baseUrl = Uri.parse('https://example.test/v1');
  const request = CompletionRequest(
    model: 'test/model',
    messages: [InferenceUserMessage('hi')],
  );

  late List<http.BaseRequest> requests;
  late List<String> bodies;

  setUp(() {
    requests = [];
    bodies = [];
  });

  OpenAiCompatInferenceClient clientFor({
    required Future<http.StreamedResponse> Function(http.BaseRequest) respond,
    String? apiKey = 'sk-test',
    Map<String, String> headers = const {},
    InferenceDialect dialect = InferenceDialect.openAi,
  }) => OpenAiCompatInferenceClient(
    endpoint: InferenceEndpoint(
      baseUrl: baseUrl,
      apiKey: apiKey,
      headers: headers,
      dialect: dialect,
    ),
    clientFactory: () => MockClient.streaming((request, bodyStream) async {
      requests.add(request);
      bodies.add(await bodyStream.bytesToString());
      return respond(request);
    }),
  );

  Future<http.StreamedResponse> Function(http.BaseRequest) streamBody(
    String body, {
    int status = 200,
  }) =>
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        status,
        headers: const {'content-type': 'text/event-stream'},
      );

  group('complete', () {
    test('streams text deltas, usage and the stop reason', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(content: 'Hel'),
            _chunk(content: ''),
            _chunk(content: 'lo', finishReason: 'stop'),
            _chunk(usage: _usage, withChoice: false),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceTextDelta('Hel'),
        InferenceTextDelta('lo'),
        InferenceUsageReported(promptTokens: 10, completionTokens: 5),
        InferenceCompletionFinished(InferenceStopReason.stop),
      ]);
    });

    test('reads the charge a provider stamps on its usage', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(content: 'ok', finishReason: 'stop'),
            _chunk(usage: {..._usage, 'cost': 0.0125}, withChoice: false),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(
        events,
        contains(
          const InferenceUsageReported(
            promptTokens: 10,
            completionTokens: 5,
            cost: 0.0125,
          ),
        ),
      );
    });

    test('reassembles a charge split across wire chunks', () async {
      final body = _sse([
        _chunk(content: 'ok', finishReason: 'stop'),
        _chunk(usage: {..._usage, 'cost': 0.0125}, withChoice: false),
      ]);
      final cut = body.indexOf('"cost"') + 3;
      final client = clientFor(
        respond: (_) async => http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode(body.substring(0, cut)),
            utf8.encode(body.substring(cut)),
          ]),
          200,
          headers: const {'content-type': 'text/event-stream'},
        ),
      );

      final events = await client.complete(request).toList();

      expect(
        events.whereType<InferenceUsageReported>().single.cost,
        0.0125,
      );
    });

    test('keeps each concurrent completion to its own charge', () async {
      var served = 0;
      final client = clientFor(
        respond: (_) async {
          final cost = ++served == 1 ? 0.1 : 0.2;
          await Future<void>.delayed(Duration(milliseconds: served * 5));
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                _sse([
                  _chunk(content: 'ok', finishReason: 'stop'),
                  _chunk(usage: {..._usage, 'cost': cost}, withChoice: false),
                ]),
              ),
            ),
            200,
            headers: const {'content-type': 'text/event-stream'},
          );
        },
      );

      final first = client.complete(request).toList();
      final second = client.complete(request).toList();
      final costs = [
        for (final events in await Future.wait([first, second]))
          events.whereType<InferenceUsageReported>().single.cost,
      ];

      expect(costs, [0.1, 0.2]);
    });

    test('sends the mapped request body and auth headers', () async {
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'ok')])),
        headers: const {'X-Title': 'bestie'},
      );
      const fullRequest = CompletionRequest(
        model: 'test/model',
        messages: [
          InferenceSystemMessage('be nice'),
          InferenceUserMessage('hi'),
          InferenceAssistantMessage(
            text: 'calling',
            reasoning: 'hmm',
            toolCalls: [
              InferenceToolCall(
                id: 'call_1',
                name: 'echo',
                arguments: {'text': 'hi'},
                rawArguments: '{"text":"hi"}',
              ),
            ],
            providerReasoning: [
              {'type': 'reasoning.text', 'text': 'hmm', 'signature': 'sig'},
            ],
          ),
          InferenceToolResultMessage(
            toolCallId: 'call_1',
            name: 'echo',
            content: 'hi',
          ),
          InferenceAssistantMessage(text: ''),
        ],
        tools: [
          InferenceTool(
            name: 'echo',
            description: 'Echoes',
            parameters: {'type': 'object'},
          ),
        ],
        sampling: InferenceSampling(
          temperature: 0.5,
          topP: 0.9,
          frequencyPenalty: 0.1,
          presencePenalty: 0.2,
          seed: 7,
          maxOutputTokens: 256,
        ),
        reasoning: InferenceReasoningEffort(InferenceEffort.max),
        stopSequences: ['END'],
      );

      await client.complete(fullRequest).drain<void>();

      final sent = requests.single;
      expect(sent.url, Uri.parse('https://example.test/v1/chat/completions'));
      expect(sent.headers['Authorization'], 'Bearer sk-test');
      expect(sent.headers['X-Title'], 'bestie');
      final body = jsonDecode(bodies.single) as Map<String, Object?>;
      expect(body['model'], 'test/model');
      expect(body['stream'], isTrue);
      expect(body['stream_options'], {'include_usage': true});
      expect(body['temperature'], 0.5);
      expect(body['top_p'], 0.9);
      expect(body['frequency_penalty'], 0.1);
      expect(body['presence_penalty'], 0.2);
      expect(body['seed'], 7);
      expect(body['max_completion_tokens'], 256);
      expect(body['stop'], ['END']);
      expect(body['reasoning_effort'], 'max');
      expect(body.containsKey('reasoning'), isFalse);
      expect(body['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'echo',
            'description': 'Echoes',
            'parameters': {'type': 'object'},
          },
        },
      ]);
      final messages = body['messages']! as List<Object?>;
      expect(messages[0], {'role': 'system', 'content': 'be nice'});
      expect(messages[1], {'role': 'user', 'content': 'hi'});
      final assistant = messages[2]! as Map<String, Object?>;
      expect(assistant['role'], 'assistant');
      expect(assistant['content'], 'calling');
      expect(assistant['tool_calls'], [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'echo', 'arguments': '{"text":"hi"}'},
        },
      ]);
      expect(assistant['reasoning_details'], [
        {'type': 'reasoning.text', 'text': 'hmm', 'signature': 'sig'},
      ]);
      expect(messages[3], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': 'hi',
      });
      final emptyAssistant = messages[4]! as Map<String, Object?>;
      expect(emptyAssistant.containsKey('content'), isFalse);
      expect(emptyAssistant.containsKey('tool_calls'), isFalse);
      expect(emptyAssistant.containsKey('reasoning_details'), isFalse);
    });

    test('omits auth and reasoning when the request has neither', () async {
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'ok')])),
        apiKey: null,
      );

      await client.complete(request).drain<void>();

      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode(bodies.single) as Map<String, Object?>;
      expect(body.containsKey('reasoning_effort'), isFalse);
      expect(body.containsKey('reasoning'), isFalse);
      expect(body.containsKey('tools'), isFalse);
      expect(body.containsKey('stop'), isFalse);
    });

    test('maps every reasoning effort by name in both dialects', () async {
      for (final effort in InferenceEffort.values) {
        for (final dialect in InferenceDialect.values) {
          final client = clientFor(
            respond: streamBody(_sse([_chunk(content: 'ok')])),
            dialect: dialect,
          );
          await client
              .complete(
                CompletionRequest(
                  model: 'm',
                  messages: const [],
                  reasoning: InferenceReasoningEffort(effort),
                ),
              )
              .drain<void>();
          final body = jsonDecode(bodies.last) as Map<String, Object?>;
          switch (dialect) {
            case InferenceDialect.openAi:
              expect(body['reasoning_effort'], effort.name);
              expect(body.containsKey('reasoning'), isFalse);
            case InferenceDialect.openRouter:
              expect(body['reasoning'], {'effort': effort.name});
              expect(body.containsKey('reasoning_effort'), isFalse);
          }
        }
      }
    });

    test(
      'serializes disabled, enabled and default reasoning per dialect',
      () async {
        final cases = <InferenceDialect, Map<InferenceReasoning, Object?>>{
          InferenceDialect.openAi: {
            const InferenceReasoningDefault(): null,
            const InferenceReasoningEnabled(): null,
            const InferenceReasoningDisabled(): 'none',
          },
          InferenceDialect.openRouter: {
            const InferenceReasoningDefault(): null,
            const InferenceReasoningEnabled(): {'enabled': true},
            const InferenceReasoningDisabled(): {'enabled': false},
          },
        };
        for (final dialectCase in cases.entries) {
          for (final reasoningCase in dialectCase.value.entries) {
            final client = clientFor(
              respond: streamBody(_sse([_chunk(content: 'ok')])),
              dialect: dialectCase.key,
            );
            await client
                .complete(
                  CompletionRequest(
                    model: 'm',
                    messages: const [],
                    reasoning: reasoningCase.key,
                  ),
                )
                .drain<void>();
            final body = jsonDecode(bodies.last) as Map<String, Object?>;
            final field = switch (dialectCase.key) {
              InferenceDialect.openAi => 'reasoning_effort',
              InferenceDialect.openRouter => 'reasoning',
            };
            expect(
              body[field],
              reasoningCase.value,
              reason: '${dialectCase.key} ${reasoningCase.key}',
            );
            expect(
              body.containsKey('reasoning_effort') &&
                  body.containsKey('reasoning'),
              isFalse,
            );
          }
        }
      },
    );

    test('streams reasoning deltas from either reasoning field', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(reasoningContent: 'think '),
            _chunk(reasoning: 'more'),
            _chunk(reasoning: ''),
            _chunk(content: 'answer', finishReason: 'stop'),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceReasoningDelta('think '),
        InferenceReasoningDelta('more'),
        InferenceTextDelta('answer'),
        InferenceCompletionFinished(InferenceStopReason.stop),
      ]);
    });

    test('emits complete tool calls after accumulating fragments', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'id': 'call_a',
                  'type': 'function',
                  'function': {'name': 'echo', 'arguments': '{"te'},
                },
                {
                  'index': 1,
                  'id': 'call_b',
                  'type': 'function',
                  'function': {'name': 'sum', 'arguments': '[1,'},
                },
              ],
            ),
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'function': {'arguments': 'xt":"hi"}'},
                },
                {
                  'index': 1,
                  'function': {'arguments': '2]'},
                },
              ],
            ),
            _chunk(finishReason: 'tool_calls'),
            _chunk(usage: _usage, withChoice: false),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceToolCallStarted(name: 'echo'),
        InferenceToolCallStarted(name: 'sum'),
        InferenceToolCallEmitted(
          InferenceToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {'text': 'hi'},
            rawArguments: '{"text":"hi"}',
          ),
        ),
        InferenceToolCallEmitted(
          InferenceToolCall(
            id: 'call_b',
            name: 'sum',
            arguments: {},
            rawArguments: '[1,2]',
          ),
        ),
        InferenceUsageReported(promptTokens: 10, completionTokens: 5),
        InferenceCompletionFinished(InferenceStopReason.toolCalls),
      ]);
      final emitted = events[2] as InferenceToolCallEmitted;
      expect(emitted.call.arguments, {'text': 'hi'});
      final listArguments = events[3] as InferenceToolCallEmitted;
      expect(listArguments.call.arguments, isEmpty);
    });

    test('announces a tool call once its name is known', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(
              toolCalls: [
                {'index': 0, 'id': 'call_a', 'type': 'function'},
              ],
            ),
            _chunk(content: 'note'),
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'function': {'name': 'echo', 'arguments': '{}'},
                },
              ],
            ),
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'function': {'arguments': ''},
                },
              ],
            ),
            _chunk(finishReason: 'tool_calls'),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceTextDelta('note'),
        InferenceToolCallStarted(name: 'echo'),
        InferenceToolCallEmitted(
          InferenceToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {},
            rawArguments: '{}',
          ),
        ),
        InferenceCompletionFinished(InferenceStopReason.toolCalls),
      ]);
    });

    test('tolerates tool calls without an index and broken JSON', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(
              toolCalls: [
                {
                  'id': 'call_a',
                  'type': 'function',
                  'function': {'name': 'echo', 'arguments': '{"text":'},
                },
              ],
            ),
            _chunk(finishReason: 'function_call'),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceToolCallStarted(name: 'echo'),
        InferenceToolCallEmitted(
          InferenceToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {},
            rawArguments: '{"text":',
          ),
        ),
        InferenceCompletionFinished(InferenceStopReason.toolCalls),
      ]);
    });

    test('maps the remaining finish reasons', () async {
      const reasons = {
        'length': InferenceStopReason.length,
        'content_filter': InferenceStopReason.contentFilter,
        'mystery': InferenceStopReason.other,
      };
      for (final entry in reasons.entries) {
        final client = clientFor(
          respond: streamBody(
            _sse([_chunk(content: 'x', finishReason: entry.key)]),
          ),
        );
        final events = await client.complete(request).toList();
        expect(events.last, InferenceCompletionFinished(entry.value));
      }
    });

    test('treats a stream that ends without a finish reason as stop', () async {
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'x')], done: false)),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceTextDelta('x'),
        InferenceCompletionFinished(InferenceStopReason.stop),
      ]);
    });

    test('maps HTTP failures to failure kinds', () async {
      const cases = {
        401: InferenceFailureKind.auth,
        403: InferenceFailureKind.auth,
        429: InferenceFailureKind.rateLimit,
        400: InferenceFailureKind.badRequest,
        404: InferenceFailureKind.badRequest,
        500: InferenceFailureKind.server,
        503: InferenceFailureKind.server,
      };
      for (final entry in cases.entries) {
        final client = clientFor(
          respond: streamBody(
            jsonEncode({
              'error': {'message': 'nope ${entry.key}', 'type': 'err'},
            }),
            status: entry.key,
          ),
        );

        final events = await client.complete(request).toList();

        expect(events, [
          InferenceCompletionFailed(
            InferenceFailure(kind: entry.value, message: 'nope ${entry.key}'),
          ),
        ]);
      }
    });

    test('maps non-JSON HTTP failures by status code', () async {
      const cases = {
        418: InferenceFailureKind.badRequest,
        502: InferenceFailureKind.server,
      };
      for (final entry in cases.entries) {
        final client = clientFor(
          respond: streamBody('plain text failure', status: entry.key),
        );

        final events = await client.complete(request).toList();

        expect(events, [
          InferenceCompletionFailed(
            InferenceFailure(
              kind: entry.value,
              message: 'plain text failure',
            ),
          ),
        ]);
      }
    });

    test('reports inline stream errors as server failures', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(content: 'partial'),
            {
              'error': {'message': 'provider exploded', 'code': 502},
            },
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceTextDelta('partial'),
        InferenceCompletionFailed(
          InferenceFailure(
            kind: InferenceFailureKind.server,
            message: 'provider exploded',
          ),
        ),
      ]);
    });

    test('reports unparseable chunks as malformed responses', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            {
              'choices': [
                {
                  'delta': {'content': 42},
                },
              ],
            },
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, hasLength(1));
      final failed = events.single as InferenceCompletionFailed;
      expect(failed.failure.kind, InferenceFailureKind.malformedResponse);
    });

    test('reports transport errors as network failures', () async {
      final client = clientFor(
        respond: (_) => throw http.ClientException('socket closed'),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        InferenceCompletionFailed(
          InferenceFailure(
            kind: InferenceFailureKind.network,
            message: 'socket closed',
          ),
        ),
      ]);
    });

    test('reports an abort during the request as cancelled', () async {
      final httpClient = MockHttpClient();
      final closed = Completer<void>();
      when(httpClient.close).thenAnswer((_) {
        closed.completeError(http.ClientException('closed'));
      });
      when(() => httpClient.send(any())).thenAnswer((_) async {
        await closed.future;
        throw StateError('unreachable');
      });
      final client = OpenAiCompatInferenceClient(
        endpoint: InferenceEndpoint(baseUrl: baseUrl),
        clientFactory: () => httpClient,
      );
      final abort = Completer<void>();

      final events = client
          .complete(request, abortTrigger: abort.future)
          .toList();
      await Future<void>.delayed(Duration.zero);
      abort.complete();

      final collected = await events;
      expect(collected, hasLength(1));
      final failed = collected.single as InferenceCompletionFailed;
      expect(failed.failure.kind, InferenceFailureKind.cancelled);
    });
  });

  group('listModels', () {
    test('lists models with their metadata', () async {
      final client = clientFor(
        respond: streamBody(
          jsonEncode({
            'object': 'list',
            'data': [
              {
                'id': 'a/one',
                'object': 'model',
                'created': 1700000000,
                'owned_by': 'a',
              },
              {'id': 'b/two', 'object': 'model'},
            ],
          }),
        ),
      );

      final result = await client.listModels();

      expect(requests.single.url, Uri.parse('https://example.test/v1/models'));
      expect(result, isA<ModelsListed>());
      final listed = result as ModelsListed;
      expect(listed.models, [
        InferenceModel(
          id: 'a/one',
          ownedBy: 'a',
          created: DateTime.fromMillisecondsSinceEpoch(
            1700000000 * 1000,
            isUtc: true,
          ),
        ),
        const InferenceModel(id: 'b/two'),
      ]);
    });

    test('maps HTTP failures', () async {
      final client = clientFor(
        respond: streamBody(
          jsonEncode({
            'error': {'message': 'bad key', 'type': 'invalid_request_error'},
          }),
          status: 401,
        ),
      );

      final result = await client.listModels();

      expect(
        (result as ModelsListFailed).failure,
        const InferenceFailure(
          kind: InferenceFailureKind.auth,
          message: 'bad key',
        ),
      );
    });

    test('maps transport failures', () async {
      final client = clientFor(
        respond: (_) => throw http.ClientException('offline'),
      );

      final result = await client.listModels();

      expect(
        (result as ModelsListFailed).failure,
        const InferenceFailure(
          kind: InferenceFailureKind.network,
          message: 'offline',
        ),
      );
    });

    test('maps unexpected errors as malformed responses', () async {
      final client = clientFor(respond: streamBody('not json'));

      final result = await client.listModels();

      expect(
        (result as ModelsListFailed).failure.kind,
        InferenceFailureKind.malformedResponse,
      );
    });
  });

  test('close releases the shared client', () async {
    final httpClient = MockHttpClient();
    when(httpClient.close).thenReturn(null);
    final client = OpenAiCompatInferenceClient(
      endpoint: InferenceEndpoint(baseUrl: baseUrl),
      clientFactory: () => httpClient,
    );

    await client.close();

    verify(httpClient.close).called(1);
  });
}
