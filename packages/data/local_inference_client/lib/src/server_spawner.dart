import 'dart:io';

import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/server_results.dart';

/// Starts server processes.
@PartOf(LocalInferenceClient)
// Tests replace the spawner, so it stays an interface.
// ignore: one_member_abstracts
abstract interface class ServerSpawner {
  /// Starts [executable] with [arguments] so that it outlives this process.
  Future<ServerSpawnResult> spawn(String executable, List<String> arguments);
}

/// Starts the server detached from bestie: no pipes to fill, and nothing
/// that ends it when bestie or its terminal goes away.
@PartOf(LocalInferenceClient)
final class DetachedServerSpawner implements ServerSpawner {
  const DetachedServerSpawner();

  @override
  Future<ServerSpawnResult> spawn(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final process = await Process.start(
        executable,
        arguments,
        mode: ProcessStartMode.detached,
      );
      return ServerSpawned(pid: process.pid);
    } on ProcessException catch (error) {
      return ServerSpawnRefused('${error.message} ($executable)');
    }
  }
}
