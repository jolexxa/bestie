import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

final Uri _url = Uri.parse('http://localhost:8080/v1');

void main() {
  group('ProviderCredentials', () {
    test('compare by value', () {
      final endpoint = EndpointCredentials(
        baseUrl: _url,
        apiKey: 'tok',
        fallbackContextWindow: 8192,
      );

      expect(const NoCredentials(), const NoCredentials());
      expect(const NoCredentials().hashCode, const NoCredentials().hashCode);
      expect(const ApiKeyCredentials('sk'), const ApiKeyCredentials('sk'));
      expect(
        const ApiKeyCredentials('sk').hashCode,
        const ApiKeyCredentials('sk').hashCode,
      );
      expect(
        const ApiKeyCredentials('sk'),
        isNot(const ApiKeyCredentials('x')),
      );
      expect(
        endpoint,
        EndpointCredentials(
          baseUrl: _url,
          apiKey: 'tok',
          fallbackContextWindow: 8192,
        ),
      );
      expect(
        endpoint.hashCode,
        EndpointCredentials(
          baseUrl: _url,
          apiKey: 'tok',
          fallbackContextWindow: 8192,
        ).hashCode,
      );
      expect(
        endpoint,
        isNot(EndpointCredentials(baseUrl: _url, fallbackContextWindow: 8192)),
      );
      expect(const NoCredentials(), isNot(const ApiKeyCredentials('')));
    });

    test('never print a key', () {
      expect(const NoCredentials().toString(), 'NoCredentials()');
      expect(
        const ApiKeyCredentials('sk-secret').toString(),
        'ApiKeyCredentials(set)',
      );
      expect(
        EndpointCredentials(
          baseUrl: _url,
          apiKey: 'sk-secret',
          fallbackContextWindow: 8192,
        ).toString(),
        'EndpointCredentials(http://localhost:8080/v1, apiKey: set, '
        'fallbackContextWindow: 8192)',
      );
      expect(
        EndpointCredentials(
          baseUrl: _url,
          fallbackContextWindow: 8192,
        ).toString(),
        contains('apiKey: unset'),
      );
    });
  });
}
