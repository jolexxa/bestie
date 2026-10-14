import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_fireworks/src/fireworks_client.dart';
import 'package:provider_fireworks/src/fireworks_settings.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Fireworks AI, reached with the user's API key. It lists nothing until it
/// has one.
@model
final class FireworksProvider implements Provider {
  const FireworksProvider({
    required http.Client client,
    this.managementUrl,
    this.clock = const Clock(),
  }) : _client = client;

  /// Where the management API lives, when not at Fireworks' own address.
  final Uri? managementUrl;

  final Clock clock;

  final http.Client _client;

  @override
  String get id => 'fireworks';

  @override
  String get displayName => 'Fireworks AI';

  @override
  ProviderCredentialsKind get credentialsKind => ProviderCredentialsKind.apiKey;

  @override
  ProviderConnection connect(ProviderCredentials credentials) =>
      switch (credentials) {
        ApiKeyCredentials(:final apiKey) =>
          _connect()..configure(FireworksSettings(apiKey: apiKey)),
        NoCredentials() => _connect(),
        EndpointCredentials() => throw ArgumentError.value(
          credentials,
          'credentials',
          '$displayName takes an API key',
        ),
      };

  FireworksClient _connect() => FireworksClient(
    client: _client,
    managementUrl: managementUrl,
    clock: clock,
  );
}
