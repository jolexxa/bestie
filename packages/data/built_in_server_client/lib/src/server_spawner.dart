import 'dart:async';

import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';

/// Starts server processes.
@PartOf(BuiltInServerClient)
// Tests replace the spawner, so it stays an interface.
// ignore: one_member_abstracts
abstract interface class ServerSpawner {
  /// Starts [executable] with [arguments] and watches how it ends.
  Future<ServerSpawnResult> spawn(String executable, List<String> arguments);
}

/// Starts the server under the process host's supervision, so its exit
/// status is known. The server logs to a file, so its pipes carry nothing
/// worth keeping and are drained; it is never killed from here, since a
/// server let go of exits by itself.
@PartOf(BuiltInServerClient)
final class SupervisedServerSpawner implements ServerSpawner {
  const SupervisedServerSpawner({
    required ProcessHost host,
    required Map<String, String> environment,
  }) : _host = host,
       _environment = environment;

  final ProcessHost _host;
  final Map<String, String> _environment;

  @override
  Future<ServerSpawnResult> spawn(
    String executable,
    List<String> arguments,
  ) async {
    final spawn = _host.piped(
      executable: executable,
      arguments: arguments,
      environment: _environment,
    );
    switch (spawn) {
      case ProcessSpawnFailed(:final failure):
        return ServerSpawnRefused('${failure.message} ($executable)');
      case ProcessSpawnSucceeded(:final process):
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        return ServerSpawned(
          pid: await process.pid,
          exit: process.exit.whenComplete(process.close),
        );
    }
  }
}
