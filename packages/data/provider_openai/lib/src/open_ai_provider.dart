import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_openai/src/open_ai_endpoint_client.dart';
import 'package:provider_openai/src/open_ai_endpoint_settings.dart';
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
          OpenAiEndpointClient(client: _client)..configure(
            OpenAiEndpointSettings(
              baseUrl: baseUrl,
              apiKey: apiKey,
              contextWindow: fallbackContextWindow,
            ),
          ),
        NoCredentials() => OpenAiEndpointClient(client: _client),
        ApiKeyCredentials() => throw ArgumentError.value(
          credentials,
          'credentials',
          '$displayName is reached at an address, not with a key alone',
        ),
      };
}
