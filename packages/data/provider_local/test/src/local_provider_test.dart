import 'package:provider_local/provider_local.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

void main() {
  late LocalProvider provider;

  setUp(() => provider = FakeServer().provider());

  test('is the local server, needing no credentials', () {
    expect(provider.id, 'local');
    expect(provider.displayName, 'Built-in server');
    expect(provider.credentialsKind, ProviderCredentialsKind.none);
  });

  test('connects to the local server', () async {
    final connection = provider.connect(const NoCredentials());

    expect(connection, isA<BuiltInServerClient>());
    await connection.close();
  });

  test('refuses credentials', () {
    expect(
      () => provider.connect(const ApiKeyCredentials('sk')),
      throwsArgumentError,
    );
  });
}
