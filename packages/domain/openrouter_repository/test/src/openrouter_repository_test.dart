import 'package:mocktail/mocktail.dart';
import 'package:openrouter_repository/openrouter_repository.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:test/test.dart';

final class _MockOpenRouterClient extends Mock implements OpenRouterClient {}

void main() {
  setUpAll(() => registerFallbackValue(OpenRouterSettings.unset));

  late _MockOpenRouterClient client;
  late OpenRouterRepository repository;

  setUp(() {
    client = _MockOpenRouterClient();
    repository = OpenRouterRepository(client: client);
  });

  test('starts unset', () {
    expect(repository.settings, OpenRouterSettings.unset);
    verifyNever(() => client.configure(any()));
  });

  test('configures the client and keeps the settings', () {
    const settings = OpenRouterSettings(apiKey: 'sk-or');

    repository.configure(settings);

    verify(() => client.configure(settings)).called(1);
    expect(repository.settings, settings);
  });
}
