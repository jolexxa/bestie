import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_openai/src/open_ai_connection.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Any OpenAI-compatible server the user points bestie at.
@model
final class OpenAiProvider implements Provider {
  const OpenAiProvider({required http.Client client}) : _client = client;

  final http.Client _client;

  @override
  String get id => 'custom';

  @override
  String get displayName => 'Custom endpoint';

  @override
  ProviderCredentialsKind get credentialsKind =>
      ProviderCredentialsKind.endpoint;

  @override
  ProviderConnection connect(ProviderCredentials credentials) =>
      switch (credentials) {
        EndpointCredentials(
          :final baseUrl,
          :final apiKey,
          :final fallbackContextWindow,
        ) =>
          OpenAiConnection(
            baseUrl: baseUrl,
            apiKey: apiKey,
            fallbackContextWindow: fallbackContextWindow,
            client: _client,
          ),
        NoCredentials() => UnconfiguredConnection(
          ProviderRejected('$displayName URL is not set.'),
        ),
        ApiKeyCredentials() => throw ArgumentError.value(
          credentials,
          'credentials',
          '$displayName is reached at an address, not with a key alone',
        ),
      };
}
