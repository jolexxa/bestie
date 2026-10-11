import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/http/json_reply.dart';

/// Writes one completion's events as OpenAI chat-completion JSON, either as
/// stream chunks or as one whole response.
final class ChatResponse {
  ChatResponse({required this.id, required this.model, required this.created});

  final String id;
  final String model;

  /// Seconds since the epoch.
  final int created;

  var _toolCallCount = 0;

  /// The chunk that opens the stream, naming the assistant role.
  Map<String, Object?> get opening => _chunk({'role': 'assistant'});

  /// The chunks [event] streams as. A finished completion streams its finish
  /// reason, then its usage when [includeUsage]; a failed one streams an
  /// error.
  List<Map<String, Object?>> chunksFor(
    EngineCompletionEvent event, {
    required bool includeUsage,
  }) => switch (event) {
    EngineCompletionReasoningDelta(:final text) => [
      _chunk({'reasoning_content': text}),
    ],
    EngineCompletionTextDelta(:final text) => [
      _chunk({'content': text}),
    ],
    EngineCompletionToolCalled() => [
      _chunk({
        'tool_calls': [_toolCall(event, index: _toolCallCount++)],
      }),
    ],
    EngineCompletionFinished(:final reason, :final usage) => [
      _chunk(const {}, finishReason: _finishReason(reason)),
      if (includeUsage)
        {
          ..._envelope('chat.completion.chunk'),
          'choices': const <Object?>[],
          'usage': _usage(usage),
        },
    ],
    EngineCompletionFailed() => [errorFor(event)],
  };

  /// The whole response for a completion that ended with [events].
  Map<String, Object?> whole(List<EngineCompletionEvent> events) {
    final finished = events.last as EngineCompletionFinished;
    final toolCalls = events.whereType<EngineCompletionToolCalled>().toList();
    final reasoning = _joined<EngineCompletionReasoningDelta>(
      events,
      (delta) => delta.text,
    );
    return {
      ..._envelope('chat.completion'),
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': _joined<EngineCompletionTextDelta>(
              events,
              (delta) => delta.text,
            ),
            if (reasoning.isNotEmpty) 'reasoning_content': reasoning,
            if (toolCalls.isNotEmpty)
              'tool_calls': [for (final call in toolCalls) _toolCall(call)],
          },
          'finish_reason': _finishReason(finished.reason),
        },
      ],
      'usage': _usage(finished.usage),
    };
  }

  /// The OpenAI error body for a completion that failed after it started.
  static Map<String, Object?> errorFor(EngineCompletionFailed failed) =>
      openAiError(
        message: failed.message,
        type: 'server_error',
        code: switch (failed.failure) {
          EngineCompletionFailure.contextExceeded => 'context_length_exceeded',
          EngineCompletionFailure.engineFailed => 'engine_failed',
          EngineCompletionFailure.cancelled => 'cancelled',
        },
      );

  Map<String, Object?> _envelope(String object) => {
    'id': id,
    'object': object,
    'created': created,
    'model': model,
  };

  Map<String, Object?> _chunk(
    Map<String, Object?> delta, {
    String? finishReason,
  }) => {
    ..._envelope('chat.completion.chunk'),
    'choices': [
      {'index': 0, 'delta': delta, 'finish_reason': finishReason},
    ],
  };

  static Map<String, Object?> _toolCall(
    EngineCompletionToolCalled call, {
    int? index,
  }) => {
    'index': ?index,
    'id': call.id,
    'type': 'function',
    'function': {'name': call.name, 'arguments': call.argumentsJson},
  };

  static String _finishReason(EngineCompletionStopReason reason) =>
      switch (reason) {
        EngineCompletionStopReason.stop => 'stop',
        EngineCompletionStopReason.length => 'length',
        EngineCompletionStopReason.toolCalls => 'tool_calls',
      };

  static Map<String, Object?> _usage(EngineCompletionUsage usage) => {
    'prompt_tokens': usage.promptTokens,
    'completion_tokens': usage.completionTokens,
    'total_tokens': usage.promptTokens + usage.completionTokens,
    'prompt_tokens_details': {'cached_tokens': usage.cachedTokens},
  };

  static String _joined<T extends EngineCompletionEvent>(
    List<EngineCompletionEvent> events,
    String Function(T event) text,
  ) => events.whereType<T>().map(text).join();
}
