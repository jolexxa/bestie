import 'package:intentions/intentions.dart';
import 'package:provider_openrouter/src/open_router_client.dart';
import 'package:provider_openrouter/src/open_router_settings.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// OpenRouter, reached with the user's API key. Its model list is public, so
/// it lists models before the user gives one.
@model
final class OpenRouterProvider implements Provider {
  const OpenRouterProvider({
    this.appTitle,
    this.httpReferer,
    this.appCategories = const [],
  });

  /// How the app names itself to OpenRouter's attribution.
  final String? appTitle;

  final String? httpReferer;

  final List<String> appCategories;

  @override
  String get id => 'openrouter';

  @override
  String get displayName => 'OpenRouter';

  @override
  ProviderCredentialsKind get credentialsKind => ProviderCredentialsKind.apiKey;

  @override
  ProviderConnection connect(ProviderCredentials credentials) =>
      switch (credentials) {
        ApiKeyCredentials(:final apiKey) =>
          _client()..configure(OpenRouterSettings(apiKey: apiKey)),
        NoCredentials() => _client(),
        EndpointCredentials() => throw ArgumentError.value(
          credentials,
          'credentials',
          '$displayName takes an API key',
        ),
      };

  OpenRouterClient _client() => OpenRouterClient(
    appTitle: appTitle,
    httpReferer: httpReferer,
    appCategories: appCategories,
  );
}
