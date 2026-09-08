// Shared plumbing for the standalone integration harnesses.
import 'package:sandbox_windows/sandbox_windows.dart';

/// The real provisioning worker isolate; a probe is pointless without it.
Future<SandboxWorker> spawnWorker() async =>
    switch (await Win32SandboxWorker.spawn()) {
      SandboxWorkerCreateSucceeded(:final worker) => worker,
      SandboxWorkerCreateFailed(:final message) => throw StateError(
        'sandbox worker isolate failed to spawn: $message',
      ),
    };
