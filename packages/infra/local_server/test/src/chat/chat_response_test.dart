import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/chat/chat_response.dart';
import 'package:test/test.dart';

const _usage = EngineCompletionUsage(
  promptTokens: 10,
  completionTokens: 4,
  cachedTokens: 6,
  promptTime: Duration(milliseconds: 40),
  generationTime: Duration(microseconds: 12500),
);

const _progress = EngineCompletionPrefillProgressed(
  total: 10,
  cached: 6,
  processed: 8,
  elapsed: Duration(milliseconds: 30),
);

const Map<String, Object?> _usageJson = {
  'prompt_tokens': 10,
  'completion_tokens': 4,
  'total_tokens': 14,
  'prompt_tokens_details': {'cached_tokens': 6},
};

void main() {
  late ChatResponse response;

  setUp(
    () => response = ChatResponse(id: 'chatcmpl-1', model: 'qwen', created: 5),
  );

  Object? deltaOf(Map<String, Object?> chunk) =>
      ((chunk['choices']! as List).single as Map)['delta'];

  test('opens the stream with the assistant role', () {
    expect(response.opening, {
      'id': 'chatcmpl-1',
      'object': 'chat.completion.chunk',
      'created': 5,
      'model': 'qwen',
      'choices': [
        {
          'index': 0,
          'delta': {'role': 'assistant'},
          'finish_reason': null,
        },
      ],
    });
  });

  test('streams reasoning and text as deltas', () {
    expect(
      deltaOf(
        response
            .chunksFor(const EngineCompletionReasoningDelta('hmm', tokens: 2))
            .single,
      ),
      {'reasoning_content': 'hmm'},
    );
    expect(
      deltaOf(
        response
            .chunksFor(const EngineCompletionTextDelta('hi', tokens: 1))
            .single,
      ),
      {'content': 'hi'},
    );
  });

  test('numbers tool calls in the order they stream', () {
    List<Object?> callsIn(EngineCompletionEvent event) =>
        (deltaOf(response.chunksFor(event).single)! as Map)['tool_calls']!
            as List;

    callsIn(
      const EngineCompletionToolCalled(
        id: 'a',
        name: 'read',
        argumentsJson: '{}',
        tokens: 3,
      ),
    );
    expect(
      callsIn(
        const EngineCompletionToolCalled(
          id: 'b',
          name: 'write',
          argumentsJson: '{"x":1}',
          tokens: 4,
        ),
      ),
      [
        {
          'index': 1,
          'id': 'b',
          'type': 'function',
          'function': {'name': 'write', 'arguments': '{"x":1}'},
        },
      ],
    );
  });

  test('finishes with the reason, then usage when asked', () {
    final chunks =
        ChatResponse(
          id: 'chatcmpl-1',
          model: 'qwen',
          created: 5,
          includeUsage: true,
        ).chunksFor(
          const EngineCompletionFinished(
            reason: EngineCompletionStopReason.toolCalls,
            usage: _usage,
          ),
        );

    expect(
      ((chunks.first['choices']! as List).single as Map)['finish_reason'],
      'tool_calls',
    );
    expect(chunks.last['choices'], isEmpty);
    expect(chunks.last['usage'], _usageJson);
  });

  test('finishes without usage unless asked', () {
    expect(
      response.chunksFor(
        const EngineCompletionFinished(
          reason: EngineCompletionStopReason.length,
          usage: _usage,
        ),
      ),
      hasLength(1),
    );
  });

  test('streams prefill progress only when asked', () {
    expect(response.chunksFor(_progress), isEmpty);

    final chunk = ChatResponse(
      id: 'chatcmpl-1',
      model: 'qwen',
      created: 5,
      returnProgress: true,
    ).chunksFor(_progress).single;

    expect(deltaOf(chunk), {'role': 'assistant', 'content': null});
    expect(chunk['prompt_progress'], {
      'total': 10,
      'cache': 6,
      'processed': 8,
      'time_ms': 30.0,
    });
  });

  test('leaves timings out unless asked', () {
    response.chunksFor(_progress);

    expect(
      response.chunksFor(const EngineCompletionTextDelta('hi', tokens: 1)),
      [isNot(contains('timings'))],
    );
  });

  test('times every generated chunk when asked', () {
    final timed = ChatResponse(
      id: 'chatcmpl-1',
      model: 'qwen',
      created: 5,
      timingsPerToken: true,
    );
    List<Object?> timingsOf(EngineCompletionEvent event) => [
      for (final chunk in timed.chunksFor(event)) chunk['timings'],
    ];

    timed.chunksFor(_progress);

    expect(
      timingsOf(const EngineCompletionReasoningDelta('hm', tokens: 2)),
      [
        {'cache_n': 6, 'prompt_n': 2, 'prompt_ms': 30.0, 'predicted_n': 2},
      ],
    );
    expect(timingsOf(const EngineCompletionTextDelta('hi', tokens: 1)), [
      {'cache_n': 6, 'prompt_n': 2, 'prompt_ms': 30.0, 'predicted_n': 3},
    ]);
    expect(
      timingsOf(
        const EngineCompletionToolCalled(
          id: 'a',
          name: 'read',
          argumentsJson: '{}',
          tokens: 4,
        ),
      ),
      [
        {'cache_n': 6, 'prompt_n': 2, 'prompt_ms': 30.0, 'predicted_n': 7},
      ],
    );
    expect(
      timingsOf(
        const EngineCompletionFinished(
          reason: EngineCompletionStopReason.stop,
          usage: _usage,
        ),
      ),
      [
        {
          'cache_n': 6,
          'prompt_n': 4,
          'prompt_ms': 40.0,
          'predicted_n': 4,
          'predicted_ms': 12.5,
        },
      ],
    );
  });

  test('streams a failure as an OpenAI error', () {
    expect(
      response.chunksFor(
        const EngineCompletionFailed(
          failure: EngineCompletionFailure.engineFailed,
          message: 'boom',
        ),
      ),
      [
        {
          'error': {
            'message': 'boom',
            'type': 'server_error',
            'code': 'engine_failed',
          },
        },
      ],
    );
  });

  test('names every failure', () {
    expect(
      [
        for (final failure in EngineCompletionFailure.values)
          (ChatResponse.errorFor(
                EngineCompletionFailed(failure: failure, message: ''),
              )['error']!
              as Map)['code'],
      ],
      ['context_length_exceeded', 'engine_failed', 'cancelled'],
    );
  });

  test('gathers a whole response', () {
    expect(
      response.whole(const [
        _progress,
        EngineCompletionReasoningDelta('think ', tokens: 1),
        EngineCompletionReasoningDelta('more', tokens: 1),
        EngineCompletionTextDelta('Hel', tokens: 1),
        EngineCompletionTextDelta('lo', tokens: 1),
        EngineCompletionToolCalled(
          id: 'a',
          name: 'read',
          argumentsJson: '{}',
          tokens: 3,
        ),
        EngineCompletionFinished(
          reason: EngineCompletionStopReason.stop,
          usage: _usage,
        ),
      ]),
      {
        'id': 'chatcmpl-1',
        'object': 'chat.completion',
        'created': 5,
        'model': 'qwen',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': 'Hello',
              'reasoning_content': 'think more',
              'tool_calls': [
                {
                  'id': 'a',
                  'type': 'function',
                  'function': {'name': 'read', 'arguments': '{}'},
                },
              ],
            },
            'finish_reason': 'stop',
          },
        ],
        'usage': _usageJson,
      },
    );
  });

  test('leaves reasoning and tool calls out of a plain answer', () {
    final message =
        ((response.whole(const [
                      EngineCompletionTextDelta('ok', tokens: 1),
                      EngineCompletionFinished(
                        reason: EngineCompletionStopReason.stop,
                        usage: _usage,
                      ),
                    ])['choices']!
                    as List)
                .single
            as Map)['message'];

    expect(message, {'role': 'assistant', 'content': 'ok'});
  });
}
