import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/src/host_preparation.dart';

/// The work the readiness machine asks of the host at each step.
abstract interface class SandboxReadinessHost {
  /// Whether the host's one-time grants are already in place for [spec].
  Future<bool> hostPrepared(SandboxSpec spec);

  /// Puts the host's one-time grants in place for [spec].
  Future<HostPreparation> prepareHost(SandboxSpec spec);

  /// Provisions the session's confinement for [spec].
  Future<void> provisionSession(SandboxSpec spec);

  /// Reclaims what the host no longer needs.
  Future<void> reclaimHost();

  /// Releases the live confinement and reverses every grant the host holds.
  Future<void> resetSession();
}
