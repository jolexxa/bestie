import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:openai_endpoint_client/openai_endpoint_client.dart';

/// Where the user pointed bestie and what to assume about the server there,
/// kept under `provider.custom`.
@model
final class OpenAiEndpointConfigKeys {
  const OpenAiEndpointConfigKeys({
    required this.baseUrl,
    required this.apiKey,
    required this.contextWindow,
  });

  factory OpenAiEndpointConfigKeys.defaults() => OpenAiEndpointConfigKeys(
    baseUrl: ConfigKey<String>(
      id: 'provider.custom.base_url',
      path: const ['provider', 'custom', 'baseUrl'],
      codec: ConfigCodecs.strings,
      defaultValue: () => '',
      field: const OpaqueField(
        label: 'Custom endpoint URL',
        description:
            'OpenAI-compatible base URL including the version segment, '
            'e.g. http://localhost:8080/v1 for a local llama.cpp server.',
      ),
      effect: ConfigEffect.onCommit,
    ),
    apiKey: ConfigKey<String>(
      id: 'provider.custom.api_key',
      path: const ['provider', 'custom', 'apiKey'],
      codec: ConfigCodecs.strings,
      defaultValue: () => '',
      field: const OpaqueField(
        label: 'Custom endpoint API key',
        description: 'Bearer token for the endpoint, if it wants one.',
        secret: true,
      ),
      effect: ConfigEffect.onCommit,
    ),
    contextWindow: ConfigKey<int>(
      id: 'provider.custom.context_window',
      path: const ['provider', 'custom', 'contextWindow'],
      codec: ConfigCodecs.integers,
      defaultValue: () => OpenAiEndpointSettings.defaultContextWindow,
      field: const NumericField(
        label: 'Custom endpoint context window',
        description:
            'Tokens to assume the endpoint can attend to when it does not '
            'say.',
        min: 1024,
        max: 2097152,
        step: 1024,
      ),
      effect: ConfigEffect.onCommit,
    ),
  );

  final ConfigKey<String> baseUrl;

  final ConfigKey<String> apiKey;

  /// What to assume for an endpoint that does not report its context.
  final ConfigKey<int> contextWindow;

  /// Keys the settings are built from, in the order the overlay shows them.
  Iterable<ConfigKeyBase> get settingsKeys => [baseUrl, apiKey, contextWindow];
}
