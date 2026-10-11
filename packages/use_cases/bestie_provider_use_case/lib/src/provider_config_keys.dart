import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// The model a fresh install talks to until the user picks another.
const String defaultProviderModel = 'openrouter:openai/gpt-4o-mini';

const int defaultProviderMaxAgents = 3;

/// What to assume for a custom endpoint that does not report its context.
const int defaultCustomContextWindow = 32768;

/// The settings one provider is reached with, kept under `provider.<id>`.
@model
final class ProviderAccountKeys {
  const ProviderAccountKeys({
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.contextWindow,
  });

  factory ProviderAccountKeys.forProvider(Provider provider) {
    final id = provider.id;
    final name = provider.displayName;
    final isEndpoint =
        provider.credentialsKind == ProviderCredentialsKind.endpoint;
    return ProviderAccountKeys(
      provider: provider,
      apiKey: _textKey(
        id,
        'api_key',
        'apiKey',
        OpaqueField(
          label: '$name API key',
          description: isEndpoint
              ? 'Bearer token for the endpoint, if it wants one.'
              : 'Your $name key. Bestie reconnects when it changes.',
          secret: true,
        ),
      ),
      baseUrl: _textKey(
        id,
        'base_url',
        'baseUrl',
        OpaqueField(
          label: '$name URL',
          description:
              'OpenAI-compatible base URL including the version segment, '
              'e.g. http://localhost:8080/v1 for a local llama.cpp server.',
        ),
      ),
      contextWindow: ConfigKey<int>(
        id: 'provider.$id.context_window',
        path: ['provider', id, 'contextWindow'],
        codec: ConfigCodecs.integers,
        defaultValue: () => defaultCustomContextWindow,
        field: NumericField(
          label: '$name context window',
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
  }

  final Provider provider;

  final ConfigKey<String> apiKey;

  final ConfigKey<String> baseUrl;

  /// What to assume for an endpoint that does not report its context.
  final ConfigKey<int> contextWindow;

  /// The keys this provider is configured with, in the order the overlay
  /// shows them.
  List<ConfigKeyBase> get keys => switch (provider.credentialsKind) {
    ProviderCredentialsKind.none => const [],
    ProviderCredentialsKind.apiKey => [apiKey],
    ProviderCredentialsKind.endpoint => [baseUrl, apiKey, contextWindow],
  };

  List<ConfigAddressBase> get addresses => [
    for (final key in keys) key.atScope(ConfigScope.global),
  ];

  /// What the provider is reached with, built from the configured values;
  /// null when it needs nothing or what it needs is not set.
  ProviderCredentials? credentials({
    required String apiKey,
    required String baseUrl,
    required int contextWindow,
  }) {
    final key = apiKey.trim();
    return switch (provider.credentialsKind) {
      ProviderCredentialsKind.none => null,
      ProviderCredentialsKind.apiKey =>
        key.isEmpty ? null : ApiKeyCredentials(key),
      ProviderCredentialsKind.endpoint => switch (Uri.tryParse(
        baseUrl.trim(),
      )) {
        final url? when url.hasScheme && url.host.isNotEmpty =>
          EndpointCredentials(
            baseUrl: url,
            apiKey: key.isEmpty ? null : key,
            fallbackContextWindow: contextWindow,
          ),
        _ => null,
      },
    };
  }
}

@model
final class ProviderConfigKeys {
  const ProviderConfigKeys({
    required this.accounts,
    required this.model,
    required this.maxAgents,
    required this.contextCap,
  });

  /// One account's keys per provider, in the order given.
  factory ProviderConfigKeys.forProviders(Iterable<Provider> providers) =>
      ProviderConfigKeys(
        accounts: [
          for (final provider in providers)
            ProviderAccountKeys.forProvider(provider),
        ],
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
            description:
                'How many agents may run at once, including the primary.',
            min: 1,
            max: 8,
            step: 1,
          ),
          effect: ConfigEffect.onCommit,
        ),
        contextCap: ConfigKey<int>(
          id: 'provider.local.context_cap',
          path: const ['provider', 'local', 'contextCap'],
          codec: ConfigCodecs.integers,
          defaultValue: () => 0,
          field: const NumericField(
            label: 'Context cap',
            description:
                'The most context a local model may run with. 0 = as much as '
                'fits in memory. Applies on reconnect.',
            min: 0,
            max: 2097152,
            step: 1024,
          ),
          effect: ConfigEffect.onCommit,
        ),
      );

  final List<ProviderAccountKeys> accounts;

  final ConfigKey<String> model;
  final ConfigKey<int> maxAgents;

  /// The most context a model that loads on this device may run with; 0
  /// for as much as fits.
  final ConfigKey<int> contextCap;

  /// Keys the provider settings are built from.
  Iterable<ConfigKeyBase> get settingsKeys => [
    for (final account in accounts) ...account.keys,
    model,
    maxAgents,
    contextCap,
  ];
}

ConfigKey<String> _textKey(
  String id,
  String keyId,
  String path,
  ConfigField<String> field,
) => ConfigKey<String>(
  id: 'provider.$id.$keyId',
  path: ['provider', id, path],
  codec: ConfigCodecs.strings,
  defaultValue: () => '',
  field: field,
  effect: ConfigEffect.onCommit,
);
