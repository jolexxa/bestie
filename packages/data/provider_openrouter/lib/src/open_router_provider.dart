import 'package:intentions/intentions.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:provider_openrouter/src/open_router_connection.dart';
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
        ApiKeyCredentials(:final apiKey) => _connection(apiKey),
        NoCredentials() => _connection(null),
        EndpointCredentials() => throw ArgumentError.value(
          credentials,
          'credentials',
          '$displayName takes an API key',
        ),
      };

  OpenRouterConnection _connection(String? apiKey) => OpenRouterConnection(
    client: openrouter.OpenRouter(
      apiKey: apiKey ?? '',
      httpReferer: httpReferer,
      appTitle: appTitle,
      appCategories: appCategories.toSet(),
    ),
    apiKey: apiKey,
    headers: {
      'HTTP-Referer': ?httpReferer,
      'X-OpenRouter-Title': ?appTitle,
      if (appCategories.isNotEmpty)
        'X-OpenRouter-Categories': appCategories.join(','),
    },
  );
}
