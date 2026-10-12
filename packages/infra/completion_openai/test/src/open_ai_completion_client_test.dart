import 'dart:async';
import 'dart:convert';

import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockOpenAiDialect extends Mock implements OpenAiDialect {}

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
  int? predicted,
  Map<String, Object?>? promptProgress,
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
  if (predicted != null) 'timings': {'predicted_n': predicted},
  'prompt_progress': ?promptProgress,
};

const _primary = AgentIdentity(
  id: 'primary:1',
  kind: AgentIdentityKind.primary,
);

const _helper = AgentIdentity(
  id: 'subagent:2',
  kind: AgentIdentityKind.subagent,
);

CompletionRequest _requestFrom(AgentIdentity agent) => CompletionRequest(
  model: 'test/model',
  messages: const [CompletionUserMessage('hi')],
  agent: agent,
);

const _usage = {
  'prompt_tokens': 10,
  'completion_tokens': 5,
  'total_tokens': 15,
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBaseRequest());
    registerFallbackValue(_requestFrom(_primary));
  });

  final baseUrl = Uri.parse('https://example.test/v1');
  const request = CompletionRequest(
    model: 'test/model',
    messages: [CompletionUserMessage('hi')],
  );

  late List<http.BaseRequest> requests;
  late List<String> bodies;

  setUp(() {
    requests = [];
    bodies = [];
  });

  OpenAiCompletionClient clientFor({
    required Future<http.StreamedResponse> Function(http.BaseRequest) respond,
    String? apiKey = 'sk-test',
    Map<String, String> headers = const {},
    OpenAiDialect dialect = const StandardOpenAiDialect(),
  }) => OpenAiCompletionClient(
    baseUrl: baseUrl,
    apiKey: apiKey,
    headers: headers,
    dialect: dialect,
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

  test('keeps the address, key, headers, and dialect it serves with', () {
    final dialect = MockOpenAiDialect();
    final client = OpenAiCompletionClient(
      baseUrl: baseUrl,
      apiKey: 'sk',
      headers: const {'X-Title': 'bestie'},
      dialect: dialect,
      clientFactory: http.Client.new,
    );

    expect(client.baseUrl, baseUrl);
    expect(client.apiKey, 'sk');
    expect(client.headers, const {'X-Title': 'bestie'});
    expect(client.dialect, dialect);
  });

  test('speaks the base protocol unless told otherwise', () {
    final client = OpenAiCompletionClient(
      baseUrl: baseUrl,
      clientFactory: http.Client.new,
    );

    expect(client.dialect, isA<StandardOpenAiDialect>());
  });

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
        CompletionTextDelta('Hel'),
        CompletionTextDelta('lo'),
        CompletionUsageReported(promptTokens: 10, completionTokens: 5),
        CompletionFinished(CompletionStopReason.stop),
      ]);
    });

    test('reads how much of the completion went to reasoning', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(content: 'ok', finishReason: 'stop'),
            _chunk(
              usage: {
                ..._usage,
                'completion_tokens_details': {'reasoning_tokens': 3},
              },
              withChoice: false,
            ),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(
        events,
        contains(
          const CompletionUsageReported(
            promptTokens: 10,
            completionTokens: 5,
            reasoningTokens: 3,
          ),
        ),
      );
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
          const CompletionUsageReported(
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
        events.whereType<CompletionUsageReported>().single.cost,
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
          events.whereType<CompletionUsageReported>().single.cost,
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
          CompletionSystemMessage('be nice'),
          CompletionUserMessage('hi'),
          CompletionAssistantMessage(
            text: 'calling',
            reasoning: 'hmm',
            toolCalls: [
              CompletionToolCall(
                id: 'call_1',
                name: 'echo',
                arguments: {'text': 'hi'},
                rawArguments: '{"text":"hi"}',
              ),
            ],
          ),
          CompletionToolResultMessage(
            toolCallId: 'call_1',
            name: 'echo',
            content: 'hi',
          ),
          CompletionAssistantMessage(text: ''),
        ],
        tools: [
          CompletionTool(
            name: 'echo',
            description: 'Echoes',
            parameters: {'type': 'object'},
          ),
        ],
        sampling: CompletionSampling(
          temperature: 0.5,
          topP: 0.9,
          frequencyPenalty: 0.1,
          presencePenalty: 0.2,
          seed: 7,
          maxOutputTokens: 256,
        ),
        reasoning: CompletionReasoningEffort(CompletionEffort.max),
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
      expect(assistant.containsKey('reasoning_details'), isFalse);
      expect(messages[3], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': 'hi',
      });
      final emptyAssistant = messages[4]! as Map<String, Object?>;
      expect(emptyAssistant.containsKey('content'), isFalse);
      expect(emptyAssistant.containsKey('tool_calls'), isFalse);
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

    test("adds the dialect's headers and body fields", () async {
      final dialect = MockOpenAiDialect();
      when(() => dialect.extensionsFor(any())).thenReturn(
        const OpenAiExtensions(
          headers: {'X-Agent': 'primary:1'},
          body: {
            'chat_template_kwargs': {'enable_thinking': true},
          },
        ),
      );
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'ok')])),
        headers: const {'X-Title': 'bestie'},
        dialect: dialect,
      );

      final primaryRequest = _requestFrom(_primary);
      await client.complete(primaryRequest).drain<void>();

      verify(() => dialect.extensionsFor(primaryRequest)).called(1);
      final sent = requests.single;
      expect(sent.headers['X-Agent'], 'primary:1');
      expect(sent.headers['X-Title'], 'bestie');
      final body = jsonDecode(bodies.single) as Map<String, Object?>;
      expect(body['chat_template_kwargs'], {'enable_thinking': true});
      expect(body['model'], 'test/model');
    });

    test('asks the dialect afresh for every completion', () async {
      final dialect = MockOpenAiDialect();
      when(() => dialect.extensionsFor(any())).thenAnswer((invocation) {
        final sent = invocation.positionalArguments.single as CompletionRequest;
        return OpenAiExtensions(headers: {'X-Agent': sent.agent!.id});
      });
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'ok')])),
        dialect: dialect,
      );

      await client.complete(_requestFrom(_helper)).drain<void>();
      await client.complete(_requestFrom(_primary)).drain<void>();

      expect(requests.map((sent) => sent.headers['X-Agent']), [
        'subagent:2',
        'primary:1',
      ]);
    });

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
        CompletionReasoningDelta('think '),
        CompletionReasoningDelta('more'),
        CompletionTextDelta('answer'),
        CompletionFinished(CompletionStopReason.stop),
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
        CompletionToolCallStarted(name: 'echo'),
        CompletionToolCallStarted(name: 'sum'),
        CompletionToolCallEmitted(
          CompletionToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {'text': 'hi'},
            rawArguments: '{"text":"hi"}',
          ),
        ),
        CompletionToolCallEmitted(
          CompletionToolCall(
            id: 'call_b',
            name: 'sum',
            arguments: {},
            rawArguments: '[1,2]',
          ),
        ),
        CompletionUsageReported(promptTokens: 10, completionTokens: 5),
        CompletionFinished(CompletionStopReason.toolCalls),
      ]);
      final emitted = events[2] as CompletionToolCallEmitted;
      expect(emitted.call.arguments, {'text': 'hi'});
      final listArguments = events[3] as CompletionToolCallEmitted;
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
        CompletionTextDelta('note'),
        CompletionToolCallStarted(name: 'echo'),
        CompletionToolCallEmitted(
          CompletionToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {},
            rawArguments: '{}',
          ),
        ),
        CompletionFinished(CompletionStopReason.toolCalls),
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
        CompletionToolCallStarted(name: 'echo'),
        CompletionToolCallEmitted(
          CompletionToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {},
            rawArguments: '{"text":',
          ),
        ),
        CompletionFinished(CompletionStopReason.toolCalls),
      ]);
    });

    test('reports how far the server has read the prompt', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(
              promptProgress: {
                'total': 100,
                'cache': 20,
                'processed': 60,
                'time_ms': 12,
              },
            ),
            _chunk(promptProgress: {'total': 100, 'processed': 'lots'}),
            _chunk(content: 'ok', finishReason: 'stop'),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        CompletionPrefillProgressed(total: 100, processed: 60),
        CompletionTextDelta('ok'),
        CompletionFinished(CompletionStopReason.stop),
      ]);
    });

    test('credits counted tokens to the deltas they decoded into', () async {
      final client = clientFor(
        respond: streamBody(
          _sse([
            _chunk(predicted: 0),
            _chunk(reasoningContent: 'hm', predicted: 2),
            _chunk(predicted: 3),
            _chunk(reasoningContent: 'm', content: 'Hi', predicted: 5),
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'id': 'call_a',
                  'function': {'name': 'echo', 'arguments': '{'},
                },
              ],
              predicted: 7,
            ),
            _chunk(
              toolCalls: [
                {
                  'index': 0,
                  'function': {'arguments': '}'},
                },
                {
                  'index': 1,
                  'function': {'arguments': 'lost'},
                },
              ],
              predicted: 8,
            ),
            _chunk(finishReason: 'tool_calls', predicted: 9),
          ]),
        ),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        CompletionReasoningDelta('hm', tokens: 2),
        CompletionReasoningDelta('m', tokens: 3),
        CompletionTextDelta('Hi', tokens: 0),
        CompletionToolCallStarted(name: 'echo'),
        CompletionToolCallEmitted(
          CompletionToolCall(
            id: 'call_a',
            name: 'echo',
            arguments: {},
            rawArguments: '{}',
          ),
          tokens: 3,
        ),
        CompletionFinished(CompletionStopReason.toolCalls),
      ]);
    });

    test('maps the remaining finish reasons', () async {
      const reasons = {
        'length': CompletionStopReason.length,
        'content_filter': CompletionStopReason.contentFilter,
        'mystery': CompletionStopReason.other,
      };
      for (final entry in reasons.entries) {
        final client = clientFor(
          respond: streamBody(
            _sse([_chunk(content: 'x', finishReason: entry.key)]),
          ),
        );
        final events = await client.complete(request).toList();
        expect(events.last, CompletionFinished(entry.value));
      }
    });

    test('treats a stream that ends without a finish reason as stop', () async {
      final client = clientFor(
        respond: streamBody(_sse([_chunk(content: 'x')], done: false)),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        CompletionTextDelta('x'),
        CompletionFinished(CompletionStopReason.stop),
      ]);
    });

    test('maps HTTP failures to failure kinds', () async {
      const cases = {
        401: CompletionFailureKind.auth,
        403: CompletionFailureKind.auth,
        429: CompletionFailureKind.rateLimit,
        400: CompletionFailureKind.badRequest,
        404: CompletionFailureKind.badRequest,
        500: CompletionFailureKind.server,
        503: CompletionFailureKind.server,
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
          CompletionFailed(
            CompletionFailure(kind: entry.value, message: 'nope ${entry.key}'),
          ),
        ]);
      }
    });

    test('maps non-JSON HTTP failures by status code', () async {
      const cases = {
        418: CompletionFailureKind.badRequest,
        502: CompletionFailureKind.server,
      };
      for (final entry in cases.entries) {
        final client = clientFor(
          respond: streamBody('plain text failure', status: entry.key),
        );

        final events = await client.complete(request).toList();

        expect(events, [
          CompletionFailed(
            CompletionFailure(
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
        CompletionTextDelta('partial'),
        CompletionFailed(
          CompletionFailure(
            kind: CompletionFailureKind.server,
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
      final failed = events.single as CompletionFailed;
      expect(failed.failure.kind, CompletionFailureKind.malformedResponse);
    });

    test('reports transport errors as network failures', () async {
      final client = clientFor(
        respond: (_) => throw http.ClientException('socket closed'),
      );

      final events = await client.complete(request).toList();

      expect(events, const [
        CompletionFailed(
          CompletionFailure(
            kind: CompletionFailureKind.network,
            message: 'socket closed',
          ),
        ),
      ]);
    });

    test('reports anything else as a malformed response', () async {
      final client = clientFor(respond: (_) => throw StateError('odd'));

      final events = await client.complete(request).toList();

      expect(events, hasLength(1));
      final failed = events.single as CompletionFailed;
      expect(failed.failure.kind, CompletionFailureKind.malformedResponse);
      expect(failed.failure.message, contains('odd'));
    });

    test('reports an abort during the request as cancelled', () async {
      final httpClient = MockHttpClient();
      final closed = Completer<void>();
      when(httpClient.close).thenAnswer((_) {
        if (!closed.isCompleted) {
          closed.completeError(http.ClientException('closed'));
        }
      });
      when(() => httpClient.send(any())).thenAnswer((_) async {
        await closed.future;
        throw StateError('unreachable');
      });
      final client = OpenAiCompletionClient(
        baseUrl: baseUrl,
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
      final failed = collected.single as CompletionFailed;
      expect(failed.failure.kind, CompletionFailureKind.cancelled);
    });
  });
}
