import 'package:isolate_worker/isolate_worker.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:sandbox_windows/src/windows_provision_command_handler.dart';

/// Runs AppContainer provisioning on a long-lived worker isolate to avoid
/// blocking.
abstract interface class SandboxWorker {
  /// Sends [request] to the worker and awaits its response.
  Future<ProvisionResponse> send(ProvisionRequest request);

  /// Shuts the worker isolate down.
  Future<void> close();
}

/// The real [SandboxWorker], over an [IsolateWorker].
final class Win32SandboxWorker implements SandboxWorker {
  /// Wraps a spawned isolate worker.
  const Win32SandboxWorker(this._worker);

  final IsolateWorker<ProvisionRequest, ProvisionResponse> _worker;

  /// Spawns the worker isolate. [isolateSpawner] is injectable for tests.
  /// Whether a failed spawn is fatal is the caller's call — the composition
  /// root treats it as one, since confinement needs this isolate.
  static Future<SandboxWorkerCreateResult> spawn({
    IsolateSpawner isolateSpawner = const DartIsolateSpawner(),
  }) async {
    final result =
        await IsolateWorker.spawn<ProvisionRequest, ProvisionResponse>(
          commandHandler: WindowsProvisionCommandHandler().call,
          isolateSpawner: isolateSpawner,
          debugName: 'bestie-sandbox',
        );
    return switch (result) {
      IsolateSpawnSucceeded(:final worker) => SandboxWorkerCreateSucceeded(
        Win32SandboxWorker(worker),
      ),
      IsolateSpawnFailed(:final message, :final stackTrace) =>
        SandboxWorkerCreateFailed(message: message, stackTrace: stackTrace),
    };
  }

  @override
  Future<ProvisionResponse> send(ProvisionRequest request) async {
    final result = await _worker.send(request);
    return switch (result) {
      IsolateSucceeded(:final value) => value,
      IsolateFailed(:final message) => ProvisionFailedResponse(
        operation: 'worker',
        reason: message,
      ),
    };
  }

  @override
  Future<void> close() => _worker.close();
}

/// Whether the worker isolate spawned.
sealed class SandboxWorkerCreateResult {
  const SandboxWorkerCreateResult();
}

/// Spawned; drive it through [worker].
final class SandboxWorkerCreateSucceeded extends SandboxWorkerCreateResult {
  /// Wraps the spawned [worker].
  const SandboxWorkerCreateSucceeded(this.worker);

  /// The spawned worker.
  final SandboxWorker worker;
}

/// The worker isolate could not be spawned.
final class SandboxWorkerCreateFailed extends SandboxWorkerCreateResult {
  /// Failed for [message], with [stackTrace].
  const SandboxWorkerCreateFailed({
    required this.message,
    required this.stackTrace,
  });

  /// Why the spawn failed.
  final String message;

  /// Where it failed.
  final String stackTrace;
}
