import 'dart:async';

import 'package:process_host/src/process_capture_result.dart';
import 'package:process_host/src/process_host.dart';
import 'package:process_host/src/process_run_result.dart';
import 'package:process_host/src/process_spawn_result.dart';
import 'package:process_host/src/sandbox.dart';

/// Runs a short-lived child through a pipe, feeds it stdin, and
/// reports how it finished.
class ProcessRunner {
  /// Runs children through [host], each in [environment].
  const ProcessRunner({required this.host, required this.environment});

  /// Spawns the children this runner drives.
  final ProcessHost host;

  /// The environment every child this runner starts is given.
  final Map<String, String> environment;

  /// Runs [executable] (piped) under [sandbox], writes [stdin] to it,
  /// and completes once it has finished. Output is drained so a chatty
  /// child can't wedge on a full pipe.
  Future<ProcessRunResult> run(
    String executable, {
    List<String> arguments = const [],
    List<int> stdin = const [],
    Sandbox? sandbox,
  }) async {
    final spawn = host.piped(
      executable: executable,
      arguments: arguments,
      environment: environment,
      sandbox: sandbox,
    );

    switch (spawn) {
      case ProcessSpawnFailed(:final failure):
        return ProcessRunNotStarted(failure);

      case ProcessSpawnSucceeded(:final process):
        final drained = Future.wait<void>([
          process.stdout.drain<void>(),
          process.stderr.drain<void>(),
        ]);
        if (stdin.isNotEmpty) {
          process.writeBytes(stdin);
        }
        await process.closeStdin();
        final exit = await process.exit;
        await drained;
        await process.close();
        return ProcessRunCompleted(exit, sandbox: process.sandbox);
    }
  }

  /// Runs [executable] (piped) under [sandbox], writes [stdin] to it, and
  /// completes once it has finished — collecting everything it wrote so the
  /// caller can read `stdout` / `stderr`. Like [run] but keeps the output
  /// instead of draining it.
  Future<ProcessCaptureResult> runCaptured(
    String executable, {
    List<String> arguments = const [],
    List<int> stdin = const [],
    Sandbox? sandbox,
  }) async {
    final spawn = host.piped(
      executable: executable,
      arguments: arguments,
      environment: environment,
      sandbox: sandbox,
    );

    switch (spawn) {
      case ProcessSpawnFailed(:final failure):
        return ProcessCaptureNotStarted(failure);

      case ProcessSpawnSucceeded(:final process):
        // Start collecting before touching stdin/exit so a child that fills a
        // pipe cannot wedge.
        final stdout = _collect(process.stdout);
        final stderr = _collect(process.stderr);
        if (stdin.isNotEmpty) {
          process.writeBytes(stdin);
        }
        await process.closeStdin();
        final exit = await process.exit;
        final result = ProcessCaptureCompleted(
          exit: exit,
          stdout: await stdout,
          stderr: await stderr,
          sandbox: process.sandbox,
        );
        await process.close();
        return result;
    }
  }
}

Future<List<int>> _collect(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await stream.forEach(bytes.addAll);
  return bytes;
}
