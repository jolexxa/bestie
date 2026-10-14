import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:provider_local/src/built_in_server_client.dart';
import 'package:provider_local/src/models/built_in_server_launch.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// The models in bestie's own index, run by bestie's local server.
@model
final class LocalProvider implements Provider {
  const LocalProvider({
    required http.Client client,
    required http.Client Function() sessionClientFactory,
    required FileSystem fileSystem,
    required String lockFile,
    required String indexFile,
    required BuiltInServerLaunch launch,
    required int pid,
    Clock clock = const Clock(),
    Duration startTimeout = const Duration(seconds: 90),
    Duration healthTimeout = const Duration(seconds: 5),
  }) : _client = client,
       _sessionClientFactory = sessionClientFactory,
       _fileSystem = fileSystem,
       _lockFile = lockFile,
       _indexFile = indexFile,
       _launch = launch,
       _pid = pid,
       _clock = clock,
       _startTimeout = startTimeout,
       _healthTimeout = healthTimeout;

  final http.Client _client;
  final http.Client Function() _sessionClientFactory;
  final FileSystem _fileSystem;
  final String _lockFile;
  final String _indexFile;
  final BuiltInServerLaunch _launch;
  final int _pid;
  final Clock _clock;
  final Duration _startTimeout;
  final Duration _healthTimeout;

  @override
  String get id => 'local';

  @override
  String get displayName => 'Built-in server';

  @override
  ProviderCredentialsKind get credentialsKind => ProviderCredentialsKind.none;

  @override
  ProviderConnection connect(ProviderCredentials credentials) =>
      switch (credentials) {
        NoCredentials() => BuiltInServerClient(
          client: _client,
          sessionClientFactory: _sessionClientFactory,
          fileSystem: _fileSystem,
          lockFile: _lockFile,
          indexFile: _indexFile,
          launch: _launch,
          pid: _pid,
          clock: _clock,
          startTimeout: _startTimeout,
          healthTimeout: _healthTimeout,
        ),
        _ => throw ArgumentError.value(
          credentials,
          'credentials',
          'Local models need no credentials',
        ),
      };
}
