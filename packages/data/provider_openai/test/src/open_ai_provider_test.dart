import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider_openai/provider_openai.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final class _MockHttpClient extends Mock implements http.Client {}

void main() {
  final provider = OpenAiProvider(client: _MockHttpClient());

  test('asks the user for an address of their own', () {
    expect(provider.id, 'custom');
    expect(provider.displayName, 'Custom endpoint');
    expect(provider.credentialsKind, ProviderCredentialsKind.endpoint);
  });

  test('connects to the address the user gave', () {
    final connection = provider.connect(
      EndpointCredentials(
        baseUrl: Uri.parse('http://localhost:8080/v1'),
        fallbackContextWindow: 8192,
      ),
    );

    expect(connection, isA<OpenAiEndpointClient>());
    expect(
      (connection as OpenAiEndpointClient).availability,
      const ProviderReady(),
    );
  });

  test('without an address, lists nothing and says what is missing', () async {
    final connection = provider.connect(const NoCredentials());

    expect(await connection.models(), isA<ProviderModelsListed>());
    expect(
      (connection as OpenAiEndpointClient).availability,
      const ProviderNotSetUp(
        ProviderRejected('Custom endpoint URL is not set.'),
      ),
    );
  });

  test('refuses a key without an address', () {
    expect(
      () => provider.connect(const ApiKeyCredentials('sk')),
      throwsArgumentError,
    );
  });
}
