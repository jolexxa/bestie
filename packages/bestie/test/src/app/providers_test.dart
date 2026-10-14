import 'package:bestie/src/app/providers.dart';
import 'package:clock/clock.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_local/provider_local.dart';
import 'package:test/test.dart';

final class _MockBuiltInServerClient extends Mock
    implements BuiltInServerClient {}

void main() {
  late _MockBuiltInServerClient builtInServer;
  late BestieProviderClients clients;

  setUp(() {
    builtInServer = _MockBuiltInServerClient();
    when(() => builtInServer.id).thenReturn('local');
    clients = BestieProviderClients(
      builtInServer: builtInServer,
      httpClient: MockClient((_) async => throw UnimplementedError()),
      clock: const Clock(),
    );
  });

  test("lists the user's own models before the hosted ones", () {
    expect(clients.all.map((client) => client.id), [
      'local',
      'custom',
      'openrouter',
      'fireworks',
    ]);
    expect(clients.all.first, same(builtInServer));
  });

  test('has no two clients with the same id', () {
    final ids = clients.all.map((client) => client.id);

    expect(ids.toSet(), hasLength(ids.length));
  });

  test('attributes the app to OpenRouter', () {
    expect(clients.openRouter.appTitle, openRouterAppTitle);
    expect(clients.openRouter.httpReferer, openRouterAppSite);
    expect(clients.openRouter.appCategories, openRouterAppCategories);
  });
}
