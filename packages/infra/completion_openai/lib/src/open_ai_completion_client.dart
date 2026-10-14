import 'dart:convert';

import 'package:completion_openai/src/open_ai_dialect.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart' as openai;

/// Talks to any server that speaks `POST /chat/completions` with
/// server-sent-event streaming, using openai_dart for the wire format.
final class OpenAiCompletionClient implements CompletionClient {
  /// Every completion gets its own client from [clientFactory] because
  /// aborting a stream closes the client that carried it.
  OpenAiCompletionClient({
    required this.baseUrl,
    required http.Client Function() clientFactory,
    this.apiKey,
    this.headers = const {},
    this.dialect = const StandardOpenAiDialect(),
  }) : _clientFactory = clientFactory,
       _config = openai.OpenAIConfig(
         baseUrl: baseUrl.toString(),
         authProvider: switch (apiKey) {
           null => null,
           final apiKey => openai.ApiKeyProvider(apiKey),
         },
         defaultHeaders: headers,
         retryPolicy: const openai.RetryPolicy(maxRetries: 0),
       );

  /// Base URL up to and including the API version segment.
  final Uri baseUrl;

  /// Bearer token sent with every request, when the server wants one.
  final String? apiKey;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  /// The server's extensions to the base protocol.
  final OpenAiDialect dialect;

  final http.Client Function() _clientFactory;
  final openai.OpenAIConfig _config;

  @override
  Stream<CompletionEvent> complete(
    CompletionRequest request, {
    Future<void>? abortTrigger,
  }) async* {
    final accumulator = openai.ChatStreamAccumulator();
    final ledger = _TokenLedger();
    var announcedToolCalls = 0;
    double? cost;
    final wire = _clientFactory();
    final extensions = dialect.extensionsFor(request);
    final client = openai.OpenAIClient(
      config: _config.copyWith(
        defaultHeaders: {..._config.defaultHeaders, ...extensions.headers},
      ),
      httpClient: wire,
      streamClientFactory: () => wire,
    );
    try {
      final chunks = _chunks(
        client.chat.completions,
        _toBody(request, extensions.body),
        abortTrigger,
      );
      await for (final raw in chunks) {
        final event = openai.ChatStreamEvent.fromJson(raw);
        accumulator.add(event);
        ledger.read(raw);
        cost = _costOf(raw) ?? cost;
        yield* _progressEvents(raw);
        yield* _deltaEvents(event.firstChoice?.delta, ledger);
        final known = accumulator.toolCalls;
        while (announcedToolCalls < known.length) {
          final call = known[announcedToolCalls++];
          yield CompletionToolCallStarted(name: call.function.name);
        }
      }
    } on Object catch (error) {
      yield CompletionFailed(_failureFor(error));
      return;
    } finally {
      client.close();
      wire.close();
    }
    for (final call in accumulator.toolCalls) {
      yield CompletionToolCallEmitted(
        _toToolCall(call),
        tokens: ledger.toolCallTokens(call.id),
      );
    }
    if (accumulator.usage case final usage?) {
      yield CompletionUsageReported(
        promptTokens: usage.promptTokens,
        completionTokens: usage.completionTokens ?? 0,
        reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
        cost: cost,
      );
    }
    yield CompletionFinished(_toStopReason(accumulator.finishReason));
  }

  /// Every streamed chunk both as openai_dart reads it and as it arrived, so
  /// fields openai_dart drops can still be read.
  static Stream<Map<String, dynamic>> _chunks(
    openai.ChatCompletionsResource completions,
    Map<String, dynamic> body,
    Future<void>? abortTrigger,
  ) => completions
      .streamSseEvents(
        endpoint: '/chat/completions',
        body: body,
        abortTrigger: abortTrigger,
      )
      .map((json) {
        final sseEvent = json['_event'] as String?;
        final error = json['error'];
        if (sseEvent == 'error' || error != null) {
          completions.throwInlineStreamError(json, sseEvent, error);
        }
        return json;
      });

  static double? _costOf(Map<String, dynamic> raw) => switch (raw) {
    {'usage': {'cost': final num cost}} => cost.toDouble(),
    _ => null,
  };

  static Stream<CompletionEvent> _progressEvents(
    Map<String, dynamic> raw,
  ) async* {
    if (raw case {
      'prompt_progress':
          {
            'total': final int total,
            'processed': final int processed,
          } &&
          final progress,
    }) {
      final cached = switch (progress) {
        {'cache': final int cache} => cache,
        _ => 0,
      };
      yield CompletionPrefillProgressed(
        total: total - cached,
        processed: processed - cached,
      );
    }
  }

  static Stream<CompletionEvent> _deltaEvents(
    openai.ChatDelta? delta,
    _TokenLedger ledger,
  ) async* {
    if (delta == null) {
      return;
    }
    final reasoning = delta.reasoningContent ?? delta.reasoning;
    if (reasoning != null && reasoning.isNotEmpty) {
      yield CompletionReasoningDelta(reasoning, tokens: ledger.claim());
    }
    final text = delta.content;
    if (text != null && text.isNotEmpty) {
      yield CompletionTextDelta(text, tokens: ledger.claim());
    }
    (delta.toolCalls ?? const []).forEach(ledger.claimForToolCall);
  }

  static Map<String, dynamic> _toBody(
    CompletionRequest request,
    Map<String, Object?> extraFields,
  ) {
    final sampling = request.sampling;
    final typed = openai.ChatCompletionCreateRequest(
      model: request.model,
      messages: [for (final message in request.messages) _toMessage(message)],
      tools: request.tools.isEmpty
          ? null
          : [
              for (final tool in request.tools)
                openai.Tool.function(
                  name: tool.name,
                  description: tool.description,
                  parameters: tool.parameters,
                ),
            ],
      temperature: sampling.temperature,
      topP: sampling.topP,
      frequencyPenalty: sampling.frequencyPenalty,
      presencePenalty: sampling.presencePenalty,
      seed: sampling.seed,
      maxCompletionTokens: sampling.maxOutputTokens,
      stop: request.stopSequences.isEmpty ? null : request.stopSequences,
      streamOptions: const openai.StreamOptions(includeUsage: true),
    );
    return {...typed.toJson(), ...extraFields, 'stream': true};
  }

  static openai.ChatMessage _toMessage(CompletionMessage message) =>
      switch (message) {
        CompletionSystemMessage(:final text) => openai.ChatMessage.system(text),
        CompletionUserMessage(:final text) => openai.ChatMessage.user(text),
        CompletionAssistantMessage(:final text, :final toolCalls) =>
          openai.AssistantMessage(
            content: text.isEmpty ? null : text,
            toolCalls: toolCalls.isEmpty
                ? null
                : [
                    for (final call in toolCalls)
                      openai.ToolCall.functionCall(
                        id: call.id,
                        call: openai.FunctionCall(
                          name: call.name,
                          arguments: call.rawArguments,
                        ),
                      ),
                  ],
          ),
        CompletionToolResultMessage(:final toolCallId, :final content) =>
          openai.ToolMessage(toolCallId: toolCallId, content: content),
      };

  static CompletionToolCall _toToolCall(openai.ToolCall call) {
    final raw = call.function.arguments;
    return CompletionToolCall(
      id: call.id,
      name: call.function.name,
      arguments: _parseArguments(raw),
      rawArguments: raw,
    );
  }

  static Map<String, Object?> _parseArguments(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  static CompletionStopReason _toStopReason(openai.FinishReason? reason) =>
      switch (reason) {
        null || openai.FinishReason.stop => CompletionStopReason.stop,
        openai.FinishReason.length => CompletionStopReason.length,
        openai.FinishReason.toolCalls ||
        openai.FinishReason.functionCall => CompletionStopReason.toolCalls,
        openai.FinishReason.contentFilter => CompletionStopReason.contentFilter,
        openai.FinishReason.unknown => CompletionStopReason.other,
      };

  static CompletionFailure _failureFor(Object error) => switch (error) {
    openai.AuthenticationException() ||
    openai.PermissionDeniedException() => _failure(
      CompletionFailureKind.auth,
      error,
    ),
    openai.RateLimitException() => _failure(
      CompletionFailureKind.rateLimit,
      error,
    ),
    openai.InternalServerException() => _failure(
      CompletionFailureKind.server,
      error,
    ),
    openai.ApiException(:final statusCode) => _failure(
      statusCode >= 500
          ? CompletionFailureKind.server
          : CompletionFailureKind.badRequest,
      error,
    ),
    openai.AbortedException() => _failure(
      CompletionFailureKind.cancelled,
      error,
    ),
    openai.StreamException() => _failure(CompletionFailureKind.server, error),
    openai.ConnectionException() ||
    openai.RequestTimeoutException() ||
    http.ClientException() => _failure(CompletionFailureKind.network, error),
    _ => _failure(CompletionFailureKind.malformedResponse, error),
  };

  static CompletionFailure _failure(CompletionFailureKind kind, Object error) =>
      CompletionFailure(
        kind: kind,
        message: switch (error) {
          openai.OpenAIException(:final message) => message,
          http.ClientException(:final message) => message,
          _ => error.toString(),
        },
      );
}

/// One streamed chunk, typed and raw.

/// Credits the generated tokens a server counts in its cumulative
/// `timings.predicted_n` to the deltas they decoded into. A chunk that carries
/// nothing passes its tokens on to the next one that does.
final class _TokenLedger {
  int? _predicted;
  var _unclaimed = 0;
  final _toolCallIds = <int, String>{};
  final _toolCallTokens = <String, int>{};

  void read(Map<String, dynamic> raw) {
    if (raw case {'timings': {'predicted_n': final int predicted}}) {
      _unclaimed += predicted - (_predicted ?? 0);
      _predicted = predicted;
    }
  }

  /// The tokens not yet credited to anything; null while the server has not
  /// counted any.
  int? claim() {
    if (_predicted == null) {
      return null;
    }
    final claimed = _unclaimed;
    _unclaimed = 0;
    return claimed;
  }

  void claimForToolCall(openai.ToolCallDelta fragment) {
    if (fragment.id case final id?) {
      _toolCallIds[fragment.index] = id;
    }
    final id = _toolCallIds[fragment.index];
    final tokens = claim();
    if (id != null && tokens != null) {
      _toolCallTokens.update(
        id,
        (held) => held + tokens,
        ifAbsent: () => tokens,
      );
    }
  }

  int? toolCallTokens(String id) => _toolCallTokens[id];
}
