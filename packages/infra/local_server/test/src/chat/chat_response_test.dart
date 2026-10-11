import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/chat/chat_response.dart';
import 'package:test/test.dart';

const _usage = EngineCompletionUsage(
  promptTokens: 10,
  completionTokens: 4,
  cachedTokens: 6,
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
            .chunksFor(
              const EngineCompletionReasoningDelta('hmm'),
              includeUsage: false,
            )
            .single,
      ),
      {'reasoning_content': 'hmm'},
    );
    expect(
      deltaOf(
        response
            .chunksFor(
              const EngineCompletionTextDelta('hi'),
              includeUsage: false,
            )
            .single,
      ),
      {'content': 'hi'},
    );
  });

  test('numbers tool calls in the order they stream', () {
    List<Object?> callsIn(EngineCompletionEvent event) =>
        (deltaOf(response.chunksFor(event, includeUsage: false).single)!
                as Map)['tool_calls']!
            as List;

    callsIn(
      const EngineCompletionToolCalled(
        id: 'a',
        name: 'read',
        argumentsJson: '{}',
      ),
    );
    expect(
      callsIn(
        const EngineCompletionToolCalled(
          id: 'b',
          name: 'write',
          argumentsJson: '{"x":1}',
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
    final chunks = response.chunksFor(
      const EngineCompletionFinished(
        reason: EngineCompletionStopReason.toolCalls,
        usage: _usage,
      ),
      includeUsage: true,
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
        includeUsage: false,
      ),
      hasLength(1),
    );
  });

  test('streams a failure as an OpenAI error', () {
    expect(
      response.chunksFor(
        const EngineCompletionFailed(
          failure: EngineCompletionFailure.engineFailed,
          message: 'boom',
        ),
        includeUsage: true,
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
        EngineCompletionReasoningDelta('think '),
        EngineCompletionReasoningDelta('more'),
        EngineCompletionTextDelta('Hel'),
        EngineCompletionTextDelta('lo'),
        EngineCompletionToolCalled(id: 'a', name: 'read', argumentsJson: '{}'),
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
                      EngineCompletionTextDelta('ok'),
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
