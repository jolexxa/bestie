import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// The model a fresh install talks to until the user picks another.
const String defaultProviderModel = 'openrouter:openai/gpt-4o-mini';

const int defaultProviderMaxAgents = 3;

/// The settings the session runs under whichever provider is chosen.
@model
final class ProviderConfigKeys {
  const ProviderConfigKeys({required this.model, required this.maxAgents});

  factory ProviderConfigKeys.defaults() => ProviderConfigKeys(
    model: ConfigKey<String>(
      id: 'provider.model',
      path: const ['provider', 'model'],
      codec: ConfigCodecs.strings,
      defaultValue: () => defaultProviderModel,
      field: const OpaqueField(
        label: 'Model',
        description:
            'Provider-qualified model id, e.g. '
            'openrouter:openai/gpt-4o-mini. Pick one from the palette '
            'with "Select model".',
      ),
      effect: ConfigEffect.onCommit,
    ),
    maxAgents: ConfigKey<int>(
      id: 'provider.max_agents',
      path: const ['provider', 'maxAgents'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultProviderMaxAgents,
      field: const NumericField(
        label: 'Max Agents',
        description: 'How many agents may run at once, including the primary.',
        min: 1,
        max: 8,
        step: 1,
      ),
      effect: ConfigEffect.onCommit,
    ),
  );

  final ConfigKey<String> model;
  final ConfigKey<int> maxAgents;

  /// Keys the provider settings are built from.
  Iterable<ConfigKeyBase> get settingsKeys => [model, maxAgents];
}
