import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inference_openai_compat/src/cost_tapping_client.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

/// Talks to any server that speaks `POST /chat/completions` with
/// server-sent-event streaming, using openai_dart for the wire format.
@dataSource
final class OpenAiCompatInferenceClient implements InferenceClient {
  /// Every stream gets its own client from [clientFactory] because aborting
  /// a stream closes the client that carried it.
  OpenAiCompatInferenceClient({
    required InferenceEndpoint endpoint,
    required http.Client Function() clientFactory,
  }) : _sharedClient = clientFactory(),
       _clientFactory = clientFactory,
       _dialect = endpoint.dialect,
       _config = openai.OpenAIConfig(
         baseUrl: endpoint.baseUrl.toString(),
         authProvider: switch (endpoint.apiKey) {
           null => null,
           final apiKey => openai.ApiKeyProvider(apiKey),
         },
         defaultHeaders: endpoint.headers,
         retryPolicy: const openai.RetryPolicy(maxRetries: 0),
       ) {
    _client = openai.OpenAIClient(config: _config, httpClient: _sharedClient);
  }

  final http.Client _sharedClient;
  final http.Client Function() _clientFactory;
  final InferenceDialect _dialect;
  final openai.OpenAIConfig _config;
  late final openai.OpenAIClient _client;

  @override
  Future<ListModelsResult> listModels() async {
    try {
      final list = await _client.models.list();
      return ModelsListed([for (final model in list.data) _toModel(model)]);
    } on Object catch (error) {
      return ModelsListFailed(_failureFor(error));
    }
  }

  /// Each completion gets a client of its own so the charge tapped off its
  /// wire can only be its own, however many stream at once.
  @override
  Stream<InferenceEvent> complete(
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
    final client = openai.OpenAIClient(
      config: _config,
      httpClient: wire,
      streamClientFactory: () => wire,
    );
    try {
      final events = client.chat.completions.createStream(
        _toRequest(request, _dialect),
        abortTrigger: abortTrigger,
      );
      await for (final event in events) {
        accumulator.add(event);
        yield* _deltaEvents(event.firstChoice?.delta);
        final known = accumulator.toolCalls;
        while (announcedToolCalls < known.length) {
          final call = known[announcedToolCalls++];
          yield InferenceToolCallStarted(name: call.function.name);
        }
      }
    } on Object catch (error) {
      yield InferenceCompletionFailed(_failureFor(error));
      return;
    } finally {
      client.close();
      wire.close();
    }
    for (final call in accumulator.toolCalls) {
      yield InferenceToolCallEmitted(_toToolCall(call));
    }
    if (accumulator.usage case final usage?) {
      yield InferenceUsageReported(
        promptTokens: usage.promptTokens,
        completionTokens: usage.completionTokens ?? 0,
        cost: cost,
      );
    }
    yield InferenceCompletionFinished(_toStopReason(accumulator.finishReason));
  }

  @override
  Future<void> close() async {
    _client.close();
    _sharedClient.close();
  }

  Stream<InferenceEvent> _deltaEvents(openai.ChatDelta? delta) async* {
    if (delta == null) {
      return;
    }
    final reasoning = delta.reasoningContent ?? delta.reasoning;
    if (reasoning != null && reasoning.isNotEmpty) {
      yield InferenceReasoningDelta(reasoning);
    }
    final text = delta.content;
    if (text != null && text.isNotEmpty) {
      yield InferenceTextDelta(text);
    }
  }

  static openai.ChatCompletionCreateRequest _toRequest(
    CompletionRequest request,
    InferenceDialect dialect,
  ) {
    final sampling = request.sampling;
    final reasoning = _ReasoningFields.of(request.reasoning, dialect);
    return openai.ChatCompletionCreateRequest(
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
      reasoningEffort: reasoning.openAiEffort,
      openRouterReasoning: reasoning.openRouterReasoning,
    );
  }

  static openai.ChatMessage _toMessage(InferenceMessage message) =>
      switch (message) {
        InferenceSystemMessage(:final text) => openai.ChatMessage.system(text),
        InferenceUserMessage(:final text) => openai.ChatMessage.user(text),
        InferenceAssistantMessage(
          :final text,
          :final toolCalls,
          :final providerReasoning,
        ) =>
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
            reasoningDetails: providerReasoning == null
                ? null
                : [
                    for (final detail in providerReasoning)
                      openai.ReasoningDetail.fromJson(detail),
                  ],
          ),
        InferenceToolResultMessage(:final toolCallId, :final content) =>
          openai.ToolMessage(toolCallId: toolCallId, content: content),
      };

  static InferenceToolCall _toToolCall(openai.ToolCall call) {
    final raw = call.function.arguments;
    return InferenceToolCall(
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

  static InferenceStopReason _toStopReason(openai.FinishReason? reason) =>
      switch (reason) {
        null || openai.FinishReason.stop => InferenceStopReason.stop,
        openai.FinishReason.length => InferenceStopReason.length,
        openai.FinishReason.toolCalls ||
        openai.FinishReason.functionCall => InferenceStopReason.toolCalls,
        openai.FinishReason.contentFilter => InferenceStopReason.contentFilter,
        openai.FinishReason.unknown => InferenceStopReason.other,
      };

  static InferenceModel _toModel(openai.Model model) => InferenceModel(
    id: model.id,
    ownedBy: model.ownedBy,
    created: switch (model.created) {
      null => null,
      final seconds => DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ),
    },
  );

  static InferenceFailure _failureFor(Object error) => switch (error) {
    openai.AuthenticationException() ||
    openai.PermissionDeniedException() => _failure(
      InferenceFailureKind.auth,
      error,
    ),
    openai.RateLimitException() => _failure(
      InferenceFailureKind.rateLimit,
      error,
    ),
    openai.InternalServerException() => _failure(
      InferenceFailureKind.server,
      error,
    ),
    openai.ApiException(:final statusCode) => _failure(
      statusCode >= 500
          ? InferenceFailureKind.server
          : InferenceFailureKind.badRequest,
      error,
    ),
    openai.AbortedException() => _failure(
      InferenceFailureKind.cancelled,
      error,
    ),
    openai.StreamException() => _failure(InferenceFailureKind.server, error),
    openai.ConnectionException() ||
    openai.RequestTimeoutException() ||
    http.ClientException() => _failure(InferenceFailureKind.network, error),
    _ => _failure(InferenceFailureKind.malformedResponse, error),
  };

  static InferenceFailure _failure(InferenceFailureKind kind, Object error) =>
      InferenceFailure(
        kind: kind,
        message: switch (error) {
          openai.OpenAIException(:final message) => message,
          http.ClientException(:final message) => message,
          _ => error.toString(),
        },
      );
}

/// The wire fields one [InferenceReasoning] becomes for a given dialect.
final class _ReasoningFields {
  const _ReasoningFields({this.openAiEffort, this.openRouterReasoning});

  const _ReasoningFields.none() : this();

  factory _ReasoningFields.of(
    InferenceReasoning reasoning,
    InferenceDialect dialect,
  ) => switch (dialect) {
    InferenceDialect.openAi => _ReasoningFields.openAi(reasoning),
    InferenceDialect.openRouter => _ReasoningFields.openRouter(reasoning),
  };

  factory _ReasoningFields.openAi(InferenceReasoning reasoning) =>
      switch (reasoning) {
        InferenceReasoningDefault() ||
        InferenceReasoningEnabled() => const _ReasoningFields.none(),
        InferenceReasoningDisabled() => const _ReasoningFields(
          openAiEffort: openai.ReasoningEffort.none,
        ),
        InferenceReasoningEffort(:final effort) => _ReasoningFields(
          openAiEffort: openai.ReasoningEffort.values.byName(effort.name),
        ),
      };

  factory _ReasoningFields.openRouter(InferenceReasoning reasoning) =>
      switch (reasoning) {
        InferenceReasoningDefault() => const _ReasoningFields.none(),
        InferenceReasoningDisabled() => const _ReasoningFields(
          openRouterReasoning: openai.OpenRouterReasoning(enabled: false),
        ),
        InferenceReasoningEnabled() => const _ReasoningFields(
          openRouterReasoning: openai.OpenRouterReasoning(enabled: true),
        ),
        InferenceReasoningEffort(:final effort) => _ReasoningFields(
          openRouterReasoning: openai.OpenRouterReasoning(effort: effort.name),
        ),
      };

  final openai.ReasoningEffort? openAiEffort;
  final openai.OpenRouterReasoning? openRouterReasoning;
}
