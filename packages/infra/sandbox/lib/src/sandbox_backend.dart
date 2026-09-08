import 'package:process_host/process_host.dart';
import 'package:sandbox/src/sandbox_acquisition.dart';
import 'package:sandbox/src/sandbox_spec.dart';

/// Builds and tears down the platform's own process confinement.
abstract interface class SandboxBackend {
  /// Provisions a sandbox matching [spec].
  Future<SandboxAcquisition> acquire(SandboxSpec spec);

  /// Releases whatever [sandbox] provisioned. Idempotent.
  Future<void> release(Sandbox sandbox);

  /// Releases any backend-wide resources this holds (e.g. a worker isolate) at
  /// the end of the session. Idempotent.
  Future<void> dispose();
}
