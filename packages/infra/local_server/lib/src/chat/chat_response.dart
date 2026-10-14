import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/src/http/json_reply.dart';

/// Writes one completion's events as OpenAI chat-completion JSON, either as
/// stream chunks or as one whole response.
final class ChatResponse {
  ChatResponse({
    required this.id,
    required this.model,
    required this.created,
    this.includeUsage = false,
    this.returnProgress = false,
    this.timingsPerToken = false,
  });

  final String id;
  final String model;

  /// Seconds since the epoch.
  final int created;

  /// Whether a finished stream ends with a usage chunk.
  final bool includeUsage;

  /// Whether prefill progress streams as `prompt_progress` chunks.
  final bool returnProgress;

  /// Whether every generated chunk carries `timings`.
  final bool timingsPerToken;

  var _toolCallCount = 0;
  var _predicted = 0;
  var _prefill = const EngineCompletionPrefillProgressed(
    total: 0,
    cached: 0,
    processed: 0,
    elapsed: Duration.zero,
  );

  /// The chunk that opens the stream, naming the assistant role.
  Map<String, Object?> get opening => _chunk({'role': 'assistant'});

  /// The chunks [event] streams as. A finished completion streams its finish
  /// reason, then its usage when [includeUsage]; a failed one streams an
  /// error.
  List<Map<String, Object?>> chunksFor(EngineCompletionEvent event) {
    switch (event) {
      case EngineCompletionPrefillProgressed():
        _prefill = event;
        return [
          if (returnProgress)
            {
              ..._chunk({'role': 'assistant', 'content': null}),
              'prompt_progress': {
                'total': event.total,
                'cache': event.cached,
                'processed': event.processed,
                'time_ms': _milliseconds(event.elapsed),
              },
            },
        ];
      case EngineCompletionReasoningDelta(:final text, :final tokens):
        return [
          _generated({'reasoning_content': text}, tokens: tokens),
        ];
      case EngineCompletionTextDelta(:final text, :final tokens):
        return [
          _generated({'content': text}, tokens: tokens),
        ];
      case EngineCompletionToolCalled(:final tokens):
        return [
          _generated({
            'tool_calls': [_toolCall(event, index: _toolCallCount++)],
          }, tokens: tokens),
        ];
      case EngineCompletionFinished(:final reason, :final usage):
        return [
          {
            ..._chunk(const {}, finishReason: _finishReason(reason)),
            if (timingsPerToken) 'timings': _finalTimings(usage),
          },
          if (includeUsage)
            {
              ..._envelope('chat.completion.chunk'),
              'choices': const <Object?>[],
              'usage': _usage(usage),
            },
        ];
      case EngineCompletionFailed():
        return [errorFor(event)];
    }
  }

  Map<String, Object?> _generated(
    Map<String, Object?> delta, {
    required int tokens,
  }) {
    _predicted += tokens;
    return {
      ..._chunk(delta),
      if (timingsPerToken)
        'timings': {
          'cache_n': _prefill.cached,
          'prompt_n': _prefill.processed - _prefill.cached,
          'prompt_ms': _milliseconds(_prefill.elapsed),
          'predicted_n': _predicted,
        },
    };
  }

  static Map<String, Object?> _finalTimings(EngineCompletionUsage usage) => {
    'cache_n': usage.cachedTokens,
    'prompt_n': usage.promptTokens - usage.cachedTokens,
    'prompt_ms': _milliseconds(usage.promptTime),
    'predicted_n': usage.completionTokens,
    'predicted_ms': _milliseconds(usage.generationTime),
  };

  static double _milliseconds(Duration duration) =>
      duration.inMicroseconds / Duration.microsecondsPerMillisecond;

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
