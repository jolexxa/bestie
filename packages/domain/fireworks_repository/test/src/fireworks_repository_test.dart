import 'package:fireworks_repository/fireworks_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:test/test.dart';

final class _MockFireworksClient extends Mock implements FireworksClient {}

void main() {
  setUpAll(() => registerFallbackValue(FireworksSettings.unset));

  late _MockFireworksClient client;
  late FireworksRepository repository;

  setUp(() {
    client = _MockFireworksClient();
    repository = FireworksRepository(client: client);
  });

  test('starts unset', () {
    expect(repository.settings, FireworksSettings.unset);
    verifyNever(() => client.configure(any()));
  });

  test('configures the client and keeps the settings', () {
    const settings = FireworksSettings(apiKey: 'fw');

    repository.configure(settings);

    verify(() => client.configure(settings)).called(1);
    expect(repository.settings, settings);
  });
}
