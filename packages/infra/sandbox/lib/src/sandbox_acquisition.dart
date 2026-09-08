import 'package:process_host/process_host.dart';
import 'package:sandbox/src/sandbox_enforcement.dart';

/// The outcome of asking for a sandbox.
sealed class SandboxAcquisition {
  const SandboxAcquisition();
}

/// A sandbox was acquired. [enforcement] may report less than was asked for.
final class SandboxAcquired extends SandboxAcquisition {
  /// Wraps the [sandbox] and the [enforcement] it holds.
  const SandboxAcquired(this.sandbox, this.enforcement);

  /// The confinement to hand to a spawn.
  final Sandbox sandbox;

  /// What it actually enforces.
  final SandboxEnforcement enforcement;
}

/// Still being set up (e.g. the Windows one-time broad-read ACL walk) and not
/// ready to confine yet — wait and retry rather than run unconfined.
final class SandboxInitializing extends SandboxAcquisition {
  /// Const so it composes once.
  const SandboxInitializing();
}

/// This machine cannot confine a process at all.
final class SandboxUnavailable extends SandboxAcquisition {
  /// Wraps the [reason] no sandbox could be built.
  const SandboxUnavailable(this.reason);

  /// Why confinement is unavailable here.
  final String reason;
}

/// The user declined the permission change confinement needs.
final class SandboxConsentDeclined extends SandboxAcquisition {
  /// Wraps the [path] whose permissions the user would not let bestie change.
  const SandboxConsentDeclined(this.path);

  /// The path consent was refused for.
  final String path;
}

/// Setting the confinement up failed partway.
final class SandboxProvisioningFailed extends SandboxAcquisition {
  /// Wraps the [operation] that failed and its [reason].
  const SandboxProvisioningFailed({
    required this.operation,
    required this.reason,
  });

  /// What was being provisioned.
  final String operation;

  /// Why it failed.
  final String reason;
}
