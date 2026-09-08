import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// How far the session's sandbox has come since startup.
@model
sealed class SandboxReadiness {
  const SandboxReadiness();
}

/// The host needs one-time grants the user has to approve; nothing happens
/// until initialized.
@model
final class SandboxAwaitingInitialization extends SandboxReadiness {
  const SandboxAwaitingInitialization();
}

/// The host's one-time grants are being put in place.
@model
final class SandboxPreparingHost extends SandboxReadiness {
  const SandboxPreparingHost();
}

/// The host is prepared and the session's confinement is being provisioned.
/// Acquiring joins the work in flight.
@model
final class SandboxProvisioning extends SandboxReadiness {
  const SandboxProvisioning();
}

/// Startup work has settled: acquiring answers without waiting on it.
@model
final class SandboxReady extends SandboxReadiness {
  const SandboxReady();
}

/// Preparing the host failed for [reason]; the user may try again.
@model
@immutable
final class SandboxInitializationFailed extends SandboxReadiness {
  const SandboxInitializationFailed(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is SandboxInitializationFailed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}
