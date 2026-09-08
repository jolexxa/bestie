import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// The model a fresh install talks to until the user picks another.
const String defaultProviderModel = 'openrouter:openai/gpt-4o-mini';

const int defaultProviderMaxAgents = 3;

/// What to assume for a custom endpoint that does not report its context.
const int defaultCustomContextWindow = 32768;

@model
final class ProviderConfigKeys {
  const ProviderConfigKeys({
    required this.openRouterApiKey,
    required this.fireworksApiKey,
    required this.customBaseUrl,
    required this.customApiKey,
    required this.customContextWindow,
    required this.model,
    required this.maxAgents,
    required this.sampling,
  });

  factory ProviderConfigKeys.defaults() => ProviderConfigKeys(
    openRouterApiKey: _textKey('openrouter.api_key', [
      'openrouter',
      'apiKey',
    ]),
    fireworksApiKey: _textKey('fireworks.api_key', ['fireworks', 'apiKey']),
    customBaseUrl: _textKey('custom.base_url', ['custom', 'baseUrl']),
    customApiKey: _textKey('custom.api_key', ['custom', 'apiKey']),
    customContextWindow: ConfigKey<int>(
      id: 'provider.custom.context_window',
      path: const ['provider', 'custom', 'contextWindow'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultCustomContextWindow,
      effect: ConfigEffect.onCommit,
    ),
    model: ConfigKey<String>(
      id: 'provider.model',
      path: const ['provider', 'model'],
      codec: ConfigCodecs.strings,
      defaultValue: () => defaultProviderModel,
      effect: ConfigEffect.onCommit,
    ),
    maxAgents: ConfigKey<int>(
      id: 'provider.max_agents',
      path: const ['provider', 'maxAgents'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultProviderMaxAgents,
      effect: ConfigEffect.onCommit,
    ),
    sampling: ProviderSamplingConfigKeys(
      temperature: _samplingKey('temperature', 'temperature', 0.7),
      topP: _samplingKey('top_p', 'topP', 1),
      frequencyPenalty: _samplingKey(
        'frequency_penalty',
        'frequencyPenalty',
        0,
      ),
      presencePenalty: _samplingKey('presence_penalty', 'presencePenalty', 0),
      seed: ConfigKey<int>(
        id: 'provider.sampling.seed',
        path: const ['provider', 'sampling', 'seed'],
        codec: ConfigCodecs.integers,
        defaultValue: () => 0,
      ),
    ),
  );

  final ConfigKey<String> openRouterApiKey;
  final ConfigKey<String> fireworksApiKey;
  final ConfigKey<String> customBaseUrl;
  final ConfigKey<String> customApiKey;
  final ConfigKey<int> customContextWindow;
  final ConfigKey<String> model;
  final ConfigKey<int> maxAgents;
  final ProviderSamplingConfigKeys sampling;

  /// Keys whose change means a different provider session.
  Iterable<ConfigKeyBase> get sessionKeys => [
    openRouterApiKey,
    fireworksApiKey,
    customBaseUrl,
    customApiKey,
    customContextWindow,
    model,
    maxAgents,
  ];
}

@model
final class ProviderSamplingConfigKeys {
  const ProviderSamplingConfigKeys({
    required this.temperature,
    required this.topP,
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.seed,
  });

  final ConfigKey<double> temperature;
  final ConfigKey<double> topP;
  final ConfigKey<double> frequencyPenalty;
  final ConfigKey<double> presencePenalty;

  /// 0 leaves sampling unseeded.
  final ConfigKey<int> seed;
}

ConfigKey<String> _textKey(String id, List<String> path) => ConfigKey<String>(
  id: 'provider.$id',
  path: ['provider', ...path],
  codec: ConfigCodecs.strings,
  defaultValue: () => '',
  effect: ConfigEffect.onCommit,
);

ConfigKey<double> _samplingKey(String id, String path, double defaultValue) =>
    ConfigKey<double>(
      id: 'provider.sampling.$id',
      path: ['provider', 'sampling', path],
      codec: ConfigCodecs.doubles,
      defaultValue: () => defaultValue,
    );
