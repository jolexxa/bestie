import 'package:mocktail/mocktail.dart';
import 'package:openai_endpoint_repository/openai_endpoint_repository.dart';
import 'package:provider_openai/provider_openai.dart';
import 'package:test/test.dart';

final class _MockOpenAiEndpointClient extends Mock
    implements OpenAiEndpointClient {}

void main() {
  setUpAll(() => registerFallbackValue(OpenAiEndpointSettings.unset));

  late _MockOpenAiEndpointClient client;
  late OpenAiEndpointRepository repository;

  setUp(() {
    client = _MockOpenAiEndpointClient();
    repository = OpenAiEndpointRepository(client: client);
  });

  test('starts unset', () {
    expect(repository.settings, OpenAiEndpointSettings.unset);
    verifyNever(() => client.configure(any()));
  });

  test('configures the client and keeps the settings', () {
    final settings = OpenAiEndpointSettings(
      baseUrl: Uri.parse('http://localhost:8080/v1'),
      apiKey: 'tok',
      contextWindow: 8192,
    );

    repository.configure(settings);

    verify(() => client.configure(settings)).called(1);
    expect(repository.settings, settings);
  });
}
