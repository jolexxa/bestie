import 'package:completion_runtime/completion_runtime.dart';
import 'package:inference_server/src/http/json_reply.dart';

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
    CompletionEvent event, {
    required bool includeUsage,
  }) => switch (event) {
    CompletionReasoningDelta(:final text) => [
      _chunk({'reasoning_content': text}),
    ],
    CompletionTextDelta(:final text) => [
      _chunk({'content': text}),
    ],
    CompletionToolCalled() => [
      _chunk({
        'tool_calls': [_toolCall(event, index: _toolCallCount++)],
      }),
    ],
    CompletionFinished(:final reason, :final usage) => [
      _chunk(const {}, finishReason: _finishReason(reason)),
      if (includeUsage)
        {
          ..._envelope('chat.completion.chunk'),
          'choices': const <Object?>[],
          'usage': _usage(usage),
        },
    ],
    CompletionFailed() => [errorFor(event)],
  };

  /// The whole response for a completion that ended with [events].
  Map<String, Object?> whole(List<CompletionEvent> events) {
    final finished = events.last as CompletionFinished;
    final toolCalls = events.whereType<CompletionToolCalled>().toList();
    final reasoning = _joined<CompletionReasoningDelta>(
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
            'content': _joined<CompletionTextDelta>(
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
  static Map<String, Object?> errorFor(CompletionFailed failed) => openAiError(
    message: failed.message,
    type: 'server_error',
    code: switch (failed.failure) {
      CompletionFailure.contextExceeded => 'context_length_exceeded',
      CompletionFailure.engineFailed => 'engine_failed',
      CompletionFailure.cancelled => 'cancelled',
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
    CompletionToolCalled call, {
    int? index,
  }) => {
    'index': ?index,
    'id': call.id,
    'type': 'function',
    'function': {'name': call.name, 'arguments': call.argumentsJson},
  };

  static String _finishReason(CompletionStopReason reason) => switch (reason) {
    CompletionStopReason.stop => 'stop',
    CompletionStopReason.length => 'length',
    CompletionStopReason.toolCalls => 'tool_calls',
  };

  static Map<String, Object?> _usage(CompletionUsage usage) => {
    'prompt_tokens': usage.promptTokens,
    'completion_tokens': usage.completionTokens,
    'total_tokens': usage.promptTokens + usage.completionTokens,
    'prompt_tokens_details': {'cached_tokens': usage.cachedTokens},
  };

  static String _joined<T extends CompletionEvent>(
    List<CompletionEvent> events,
    String Function(T event) text,
  ) => events.whereType<T>().map(text).join();
}
