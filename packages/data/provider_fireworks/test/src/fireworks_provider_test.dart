import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final class _MockHttpClient extends Mock implements http.Client {}

void main() {
  final provider = FireworksProvider(client: _MockHttpClient());

  test('asks for an API key', () {
    expect(provider.id, 'fireworks');
    expect(provider.displayName, 'Fireworks AI');
    expect(provider.credentialsKind, ProviderCredentialsKind.apiKey);
  });

  test('connects with the key', () {
    final connection = provider.connect(const ApiKeyCredentials('fw-key'));

    expect(connection, isA<FireworksClient>());
    expect((connection as FireworksClient).availability, const ProviderReady());
  });

  test('without a key, lists nothing and says a key is missing', () async {
    final connection = provider.connect(const NoCredentials());

    expect(
      (await connection.models() as ProviderModelsListed).models,
      isEmpty,
    );
    expect(
      (await connection.credits() as CreditsFailed).failure,
      const ProviderAuthFailed('No Fireworks AI API key configured.'),
    );
  });

  test('refuses an endpoint', () {
    expect(
      () => provider.connect(
        EndpointCredentials(
          baseUrl: Uri.parse('http://localhost:8080/v1'),
          fallbackContextWindow: 8192,
        ),
      ),
      throwsArgumentError,
    );
  });
}
