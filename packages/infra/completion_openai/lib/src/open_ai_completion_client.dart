import 'dart:convert';

import 'package:completion_openai/src/cost_tapping_client.dart';
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

  /// Each completion gets a client of its own so the charge tapped off its
  /// wire can only be its own, however many stream at once.
  @override
  Stream<CompletionEvent> complete(
    CompletionRequest request, {
    Future<void>? abortTrigger,
  }) async* {
    final accumulator = openai.ChatStreamAccumulator();
    var announcedToolCalls = 0;
    double? cost;
    final wire = CostTappingClient(
      _clientFactory(),
      onCost: (charge) => cost = charge,
    );
    final extensions = dialect.extensionsFor(request);
    final client = openai.OpenAIClient(
      config: _config.copyWith(
        defaultHeaders: {..._config.defaultHeaders, ...extensions.headers},
      ),
      httpClient: wire,
      streamClientFactory: () => wire,
    );
    try {
      final events = client.chat.completions.createStream(
        _toRequest(request, extensions.body),
        abortTrigger: abortTrigger,
      );
      await for (final event in events) {
        accumulator.add(event);
        yield* _deltaEvents(event.firstChoice?.delta);
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
      yield CompletionToolCallEmitted(_toToolCall(call));
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

  Stream<CompletionEvent> _deltaEvents(openai.ChatDelta? delta) async* {
    if (delta == null) {
      return;
    }
    final reasoning = delta.reasoningContent ?? delta.reasoning;
    if (reasoning != null && reasoning.isNotEmpty) {
      yield CompletionReasoningDelta(reasoning);
    }
    final text = delta.content;
    if (text != null && text.isNotEmpty) {
      yield CompletionTextDelta(text);
    }
  }

  static _ExtendedChatRequest _toRequest(
    CompletionRequest request,
    Map<String, Object?> extraFields,
  ) {
    final sampling = request.sampling;
    return _ExtendedChatRequest(
      extraFields: extraFields,
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

/// A chat request carrying body fields openai_dart does not model, merged into
/// the JSON it sends.
final class _ExtendedChatRequest extends openai.ChatCompletionCreateRequest {
  const _ExtendedChatRequest({
    required this.extraFields,
    required super.model,
    required super.messages,
    super.tools,
    super.temperature,
    super.topP,
    super.frequencyPenalty,
    super.presencePenalty,
    super.seed,
    super.maxCompletionTokens,
    super.stop,
    super.streamOptions,
  });

  final Map<String, Object?> extraFields;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), ...extraFields};
}
