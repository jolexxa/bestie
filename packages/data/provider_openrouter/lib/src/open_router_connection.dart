import 'package:agent_runtime/agent_runtime.dart';
import 'package:completion_openai/completion_openai.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:provider_openrouter/src/open_router_dialect.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// OpenRouter: an OpenAI-compatible inference endpoint plus the account and
/// model APIs behind one API key. Without a key it still lists models.
@dataSource
final class OpenRouterConnection implements ProviderConnection {
  OpenRouterConnection({
    required openrouter.OpenRouter client,
    String? apiKey,
    Map<String, String> headers = const {},
  }) : _client = client,
       _apiKey = apiKey,
       _headers = headers;

  static final Uri _baseUrl = Uri.parse('https://openrouter.ai/api/v1');

  static const _noKey = ProviderAuthFailed('No OpenRouter API key configured.');

  final openrouter.OpenRouter _client;
  final String? _apiKey;
  final Map<String, String> _headers;

  @override
  Future<CreditsResult> credits() async {
    if (_apiKey == null) return const CreditsFailed(_noKey);
    try {
      final credits = await _client.credits.getCredits();
      return CreditsFetched(
        ProviderCredits(
          spent: credits.totalUsage,
          remaining: credits.totalCredits - credits.totalUsage,
          window: SpendWindow.lifetime,
        ),
      );
    } on Object catch (error) {
      return CreditsFailed(_failureFor(error));
    }
  }

  @override
  ProviderModelLoad load(ProviderModelLoadRequest request) =>
      ProviderModelLoad.settled(switch (_apiKey) {
        null => const ProviderModelLoadFailed(_noKey),
        final apiKey => ProviderModelLoaded(
          HostedProviderModel(
            runtime: CompletionAgentRuntime.perAgentWindow(
              client: OpenAiCompletionClient(
                baseUrl: _baseUrl,
                apiKey: apiKey,
                headers: _headers,
                dialect: const OpenRouterDialect(),
                clientFactory: http.Client.new,
              ),
              options: AgentRuntimeOptions(
                modelId: request.modelId,
                contextWindow: request.contextWindow,
                maxAgents: request.maxAgents,
              ),
            ),
            contextWindow: request.contextWindow,
            maxAgents: request.maxAgents,
          ),
        ),
      });

  @override
  Future<void> close() async {}

  /// The models that answer in text, the only ones a chat can use.
  @override
  Future<ProviderModelsResult> models() async {
    try {
      final models = await _client.models.list(
        outputModalities: {openrouter.Modality.text},
      );
      return ProviderModelsListed([
        for (final model in models) _toProviderModel(model),
      ]);
    } on Object catch (error) {
      return ProviderModelsFailed(_failureFor(error));
    }
  }

  static ProviderModelInfo _toProviderModel(openrouter.Model model) {
    final parameters = model.supportedParameters;
    return ProviderModelInfo(
      id: model.id,
      name: model.name,
      contextLength: model.contextLength,
      supportsTools: parameters.contains(openrouter.ModelParameter.tools),
      reasoning: _toReasoning(
        model.reasoning,
        advertised: parameters.contains(openrouter.ModelParameter.reasoning),
      ),
      promptPricePerToken: _price(model.pricing.prompt),
      completionPricePerToken: _price(model.pricing.completion),
    );
  }

  /// OpenRouter lists efforts strongest first and spells "can be turned
  /// off" as a `none` effort; we keep efforts cheapest first and turn
  /// `none` into [ProviderReasoningEfforts.canDisable].
  static ProviderReasoning? _toReasoning(
    openrouter.ModelReasoning? reasoning, {
    required bool advertised,
  }) {
    if (reasoning == null) {
      return advertised ? const ProviderReasoningToggle() : null;
    }
    final canDisable =
        !reasoning.isMandatory ||
        reasoning.supportedEfforts.contains(openrouter.ReasoningEffort.none);
    final efforts = [
      for (final effort in reasoning.supportedEfforts.reversed)
        if (effort != openrouter.ReasoningEffort.none) effort.name,
    ];
    if (efforts.isNotEmpty) {
      return ProviderReasoningEfforts(
        efforts: efforts,
        canDisable: canDisable,
        defaultEffort:
            reasoning.defaultEffort == openrouter.ReasoningEffort.none
            ? null
            : reasoning.defaultEffort.name,
      );
    }
    return canDisable
        ? ProviderReasoningToggle(enabledByDefault: reasoning.defaultEnabled)
        : const ProviderReasoningFixed();
  }

  static double? _price(double value) => value < 0 ? null : value;

  static ProviderFailure _failureFor(Object error) => switch (error) {
    openrouter.OpenRouterException(:final code, :final message) =>
      ProviderFailure.forStatus(code, message),
    _ => ProviderUnreachable(error.toString()),
  };
}
