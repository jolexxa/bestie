/// Test-only helpers for driving a real confined process.
library;

import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';

/// A confined-command probe bound to one acquired sandbox.
class ConfinedProbe {
  const ConfinedProbe._(this._runner, this.sandbox, this.enforcement);

  final ProcessRunner _runner;

  /// The confinement every command this probe runs is spawned under.
  final Sandbox sandbox;

  /// What that confinement actually enforces.
  final SandboxEnforcement enforcement;

  /// Acquires a sandbox for [spec] through [guard], running its children on
  /// [runner].
  static Future<ConfinedProbe?> tryAcquire(
    SandboxBackend guard,
    ProcessRunner runner,
    SandboxSpec spec,
  ) async {
    final acquisition = await guard.acquire(spec);
    return switch (acquisition) {
      SandboxAcquired(:final sandbox, :final enforcement) => ConfinedProbe._(
        runner,
        sandbox,
        enforcement,
      ),
      _ => null,
    };
  }

  /// Runs [executable] confined, capturing its output and exit.
  Future<ProcessCaptureResult> run(
    String executable, {
    List<String> arguments = const [],
    List<int> stdin = const [],
  }) => _runner.runCaptured(
    executable,
    arguments: arguments,
    stdin: stdin,
    sandbox: sandbox,
  );

  /// Runs [script] under [shell] confined — sugar over [run].
  Future<ProcessCaptureResult> runScript(
    String script, {
    String shell = '/bin/sh',
  }) => run(shell, arguments: ['-c', script]);
}
