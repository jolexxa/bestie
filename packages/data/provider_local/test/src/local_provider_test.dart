import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/provider_local.dart';
import 'package:provider_local/src/local_connection.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

void main() {
  late LocalProvider provider;

  setUp(() => provider = FakeServer().provider());

  test('is the local server, needing no credentials', () {
    expect(provider.id, 'local');
    expect(provider.displayName, bestieServerName);
    expect(provider.credentialsKind, ProviderCredentialsKind.none);
  });

  test('connects to the local server', () async {
    final connection = provider.connect(const NoCredentials());

    expect(connection, isA<LocalConnection>());
    await connection.close();
  });

  test('refuses credentials', () {
    expect(
      () => provider.connect(const ApiKeyCredentials('sk')),
      throwsArgumentError,
    );
  });
}
