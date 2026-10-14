import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// What the user gives us to reach OpenRouter, kept under
/// `provider.openrouter`.
@model
final class OpenRouterConfigKeys {
  const OpenRouterConfigKeys({required this.apiKey});

  factory OpenRouterConfigKeys.defaults() => OpenRouterConfigKeys(
    apiKey: ConfigKey<String>(
      id: 'provider.openrouter.api_key',
      path: const ['provider', 'openrouter', 'apiKey'],
      codec: ConfigCodecs.strings,
      defaultValue: () => '',
      field: const OpaqueField(
        label: 'OpenRouter API key',
        description: 'Your OpenRouter key. Bestie reconnects when it changes.',
        secret: true,
      ),
      effect: ConfigEffect.onCommit,
    ),
  );

  final ConfigKey<String> apiKey;

  /// Keys the settings are built from.
  Iterable<ConfigKeyBase> get settingsKeys => [apiKey];
}
