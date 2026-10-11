import 'package:bestie/src/app/providers.dart';
import 'package:clock/clock.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

class _MockProvider extends Mock implements Provider {}

void main() {
  late _MockProvider local;
  late List<Provider> providers;

  setUp(() {
    local = _MockProvider();
    when(() => local.id).thenReturn('local');
    providers = bestieProviders(
      local: local,
      httpClient: MockClient((_) async => throw UnimplementedError()),
      clock: const Clock(),
    );
  });

  test("lists the user's own models before the hosted ones", () {
    expect(providers.map((provider) => provider.id), [
      'local',
      'custom',
      'openrouter',
      'fireworks',
    ]);
    expect(providers.first, same(local));
  });

  test('has no two providers with the same id', () {
    final ids = providers.map((provider) => provider.id);

    expect(ids.toSet(), hasLength(ids.length));
  });

  test('has the user point the custom endpoint at an address', () {
    expect(providers[1].credentialsKind, ProviderCredentialsKind.endpoint);
  });

  test('attributes the app to OpenRouter', () {
    final openRouter = providers[2] as OpenRouterProvider;

    expect(openRouter.appTitle, openRouterAppTitle);
    expect(openRouter.httpReferer, openRouterAppSite);
    expect(openRouter.appCategories, openRouterAppCategories);
  });
}
