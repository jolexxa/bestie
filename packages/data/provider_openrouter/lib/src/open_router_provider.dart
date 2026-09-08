import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:provider_protocol/provider_protocol.dart';

/// OpenRouter: an OpenAI-compatible inference endpoint plus the account
/// APIs (credits, key metadata, model catalog) behind one API key.
@dataSource
final class OpenRouterProvider implements Provider {
  OpenRouterProvider({
    required openrouter.OpenRouter client,
    required String apiKey,
    String? appTitle,
    String? httpReferer,
    List<String> appCategories = const [],
  }) : _client = client,
       endpoints = {
         InferenceProtocolId.openAiCompat: InferenceEndpoint(
           baseUrl: Uri.parse(_baseUrl),
           apiKey: apiKey,
           dialect: InferenceDialect.openRouter,
           headers: {
             'HTTP-Referer': ?httpReferer,
             'X-OpenRouter-Title': ?appTitle,
             if (appCategories.isNotEmpty)
               'X-OpenRouter-Categories': appCategories.join(','),
           },
         ),
       };

  static const _baseUrl = 'https://openrouter.ai/api/v1';

  final openrouter.OpenRouter _client;

  @override
  final Map<InferenceProtocolId, InferenceEndpoint> endpoints;

  @override
  String get id => 'openrouter';

  @override
  String get displayName => 'OpenRouter';

  @override
  Future<CreditsResult> credits() async {
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
  Future<KeyInfoResult> keyInfo() async {
    try {
      final metadata = await _client.apiKeys.getCurrentKeyMetadata();
      return KeyInfoFetched(
        ProviderKeyInfo(
          label: metadata.label,
          usage: metadata.usage,
          isFreeTier: metadata.isFreeTier,
          limit: metadata.limit,
          limitRemaining: metadata.limitRemaining,
        ),
      );
    } on Object catch (error) {
      return KeyInfoFailed(_failureFor(error));
    }
  }

  @override
  Future<ProviderModelsResult> models() async {
    try {
      final models = await _client.models.list();
      return ProviderModelsListed([
        for (final model in models) _toProviderModel(model),
      ]);
    } on Object catch (error) {
      return ProviderModelsFailed(_failureFor(error));
    }
  }

  static ProviderModel _toProviderModel(openrouter.Model model) {
    final parameters = model.supportedParameters;
    return ProviderModel(
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
      ProviderFailure(kind: _kindForCode(code), message: message),
    _ => ProviderFailure(
      kind: InferenceFailureKind.network,
      message: error.toString(),
    ),
  };

  static InferenceFailureKind _kindForCode(int code) => switch (code) {
    401 || 403 => InferenceFailureKind.auth,
    429 => InferenceFailureKind.rateLimit,
    >= 500 => InferenceFailureKind.server,
    _ => InferenceFailureKind.badRequest,
  };
}
