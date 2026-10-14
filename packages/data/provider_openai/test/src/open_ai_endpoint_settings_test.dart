import 'package:provider_openai/provider_openai.dart';
import 'package:test/test.dart';

final Uri _url = Uri.parse('http://localhost:8080/v1');

void main() {
  group('OpenAiEndpointSettings', () {
    test('compares by value', () {
      final settings = OpenAiEndpointSettings(
        baseUrl: _url,
        apiKey: 'tok',
        contextWindow: 8192,
      );

      expect(
        settings,
        OpenAiEndpointSettings(
          baseUrl: _url,
          apiKey: 'tok',
          contextWindow: 8192,
        ),
      );
      expect(
        settings.hashCode,
        OpenAiEndpointSettings(
          baseUrl: _url,
          apiKey: 'tok',
          contextWindow: 8192,
        ).hashCode,
      );
      expect(settings, isNot(OpenAiEndpointSettings(baseUrl: _url)));
      expect(settings, isNot(OpenAiEndpointSettings.unset));
    });

    test('is set once it has an address', () {
      expect(OpenAiEndpointSettings.unset.isSet, isFalse);
      expect(OpenAiEndpointSettings.unset.apiKey, isNull);
      expect(
        OpenAiEndpointSettings.unset.contextWindow,
        OpenAiEndpointSettings.defaultContextWindow,
      );
      expect(OpenAiEndpointSettings(baseUrl: _url).isSet, isTrue);
    });

    test('never prints the key', () {
      expect(
        OpenAiEndpointSettings(
          baseUrl: _url,
          apiKey: 'sk-secret',
          contextWindow: 8192,
        ).toString(),
        'OpenAiEndpointSettings(http://localhost:8080/v1, apiKey: set, '
        'contextWindow: 8192)',
      );
      expect(
        OpenAiEndpointSettings.unset.toString(),
        'OpenAiEndpointSettings(unset, apiKey: unset, contextWindow: 32768)',
      );
    });
  });
}
