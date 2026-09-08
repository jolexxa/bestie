import 'package:bestie_provider_use_case/src/provider_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class ProviderConfigContribution implements ConfigContribution {
  ProviderConfigContribution() : configKeys = ProviderConfigKeys.defaults();

  final ProviderConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.openRouterApiKey,
      field: _openRouterApiKeyField,
    ),
    globalEntry(key: configKeys.fireworksApiKey, field: _fireworksApiKeyField),
    globalEntry(key: configKeys.customBaseUrl, field: _customBaseUrlField),
    globalEntry(key: configKeys.customApiKey, field: _customApiKeyField),
    globalEntry(
      key: configKeys.customContextWindow,
      field: _customContextWindowField,
    ),
    globalEntry(key: configKeys.model, field: _modelField),
    globalEntry(key: configKeys.maxAgents, field: _maxAgentsField),
    globalEntry(key: configKeys.sampling.temperature, field: _temperatureField),
    globalEntry(key: configKeys.sampling.topP, field: _topPField),
    globalEntry(
      key: configKeys.sampling.frequencyPenalty,
      field: _frequencyPenaltyField,
    ),
    globalEntry(
      key: configKeys.sampling.presencePenalty,
      field: _presencePenaltyField,
    ),
    globalEntry(key: configKeys.sampling.seed, field: _seedField),
  ];
}

final _openRouterApiKeyField = OpaqueField<String>(
  label: 'OpenRouter API key',
  description: 'Your OpenRouter key. Bestie reconnects when it changes.',
  secret: true,
);

final _fireworksApiKeyField = OpaqueField<String>(
  label: 'Fireworks AI API key',
  description: 'Your Fireworks AI key. Bestie reconnects when it changes.',
  secret: true,
);

final _customBaseUrlField = OpaqueField<String>(
  label: 'Custom endpoint URL',
  description:
      'OpenAI-compatible base URL including the version segment, '
      'e.g. http://localhost:8080/v1 for a local llama.cpp server.',
);

final _customApiKeyField = OpaqueField<String>(
  label: 'Custom endpoint API key',
  description: 'Bearer token for the custom endpoint, if it wants one.',
  secret: true,
);

final _customContextWindowField = NumericField<int>(
  label: 'Custom context window',
  description:
      'Tokens to assume the custom endpoint can attend to when it does not '
      'say.',
  min: 1024,
  max: 2097152,
  step: 1024,
);

final _modelField = OpaqueField<String>(
  label: 'Model',
  description:
      'Provider-qualified model id, e.g. openrouter:openai/gpt-4o-mini. '
      'Pick one from the palette with "Select model".',
);

final _maxAgentsField = NumericField<int>(
  label: 'Max Agents',
  description: 'How many agents may run at once, including the primary.',
  min: 1,
  max: 8,
  step: 1,
);

final _temperatureField = NumericField<double>(
  label: 'Temperature',
  description:
      'Controls randomness in token selection. '
      'Higher values produce more creative output.',
  min: 0,
  max: 2,
  step: 0.1,
);

final _topPField = NumericField<double>(
  label: 'Top-P',
  description:
      'Limits token selection to a cumulative probability. '
      'Lower values make output more focused.',
  min: 0,
  max: 1,
  step: 0.05,
);

final _frequencyPenaltyField = NumericField<double>(
  label: 'Frequency Penalty',
  description: 'Penalizes tokens proportional to how often they appear.',
  min: -2,
  max: 2,
  step: 0.1,
);

final _presencePenaltyField = NumericField<double>(
  label: 'Presence Penalty',
  description: 'Flat penalty for any token that has appeared at all.',
  min: -2,
  max: 2,
  step: 0.1,
);

final _seedField = NumericField<int>(
  label: 'Seed',
  description: 'Sampling seed for providers that honor one. 0 = unseeded.',
  min: 0,
  max: 999999999,
  step: 1,
);
