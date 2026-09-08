import 'package:intentions/intentions.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/src/host_preparation.dart';

/// Inputs to the readiness state machine.
@model
sealed class SandboxReadinessInput {
  const SandboxReadinessInput();
}

/// Start the session's confinement for [spec].
@model
final class WarmUp extends SandboxReadinessInput {
  const WarmUp(this.spec);

  /// The policy to confine under.
  final SandboxSpec spec;
}

/// The user answered the gate: put the host's one-time grants in place.
@model
final class Initialize extends SandboxReadinessInput {
  const Initialize();
}

/// Reverse every grant, forget every record, and start over.
@model
final class Reset extends SandboxReadinessInput {
  const Reset();
}

/// The host answered whether its one-time grants are in place.
@model
final class HostChecked extends SandboxReadinessInput {
  const HostChecked({required this.prepared});

  /// Whether the session can start without asking the user.
  final bool prepared;
}

/// Putting the host's one-time grants in place settled.
@model
final class HostPreparationSettled extends SandboxReadinessInput {
  const HostPreparationSettled(this.preparation);

  /// What came of it.
  final HostPreparation preparation;
}

/// Provisioning the session's confinement settled, one way or the other.
@model
final class SessionProvisioned extends SandboxReadinessInput {
  const SessionProvisioned();
}

/// The host's grants and records are gone.
@model
final class HostReset extends SandboxReadinessInput {
  const HostReset();
}

/// A step the host was asked for threw instead of answering.
@model
final class HostWorkFailed extends SandboxReadinessInput {
  const HostWorkFailed(this.reason);

  /// What it threw.
  final String reason;
}
