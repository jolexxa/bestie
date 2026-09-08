import 'package:win32_dart/win32_dart.dart'
    show SUB_CONTAINERS_AND_OBJECTS_INHERIT;

/// The native AppContainer operations `SandboxWindows` orchestrates, behind
/// an interface so the adapter's logic — which paths to ACL, how the network
/// tier degrades, teardown ordering — is unit-testable without crossing the FFI
/// boundary. The real implementation is `Win32Provisioner`; tests fake this.
abstract interface class WindowsProvisioner {
  /// Provisions (creates, or derives if it already exists) the profile [name],
  /// returning its container SID and the folder Windows keeps for it.
  ProvisionOutcome provision(String name);

  /// Grants the container [containerSid] read (+execute), or read-write when
  /// [write], on [path], inherited. Returns a failure reason, null on success.
  String? grant({
    required String containerSid,
    required String path,
    required bool write,
  });

  /// Whether [path]'s own DACL already carries what [grant] would set.
  GrantInspection holds({
    required String containerSid,
    required String path,
    required bool write,
  });

  /// Whether [path]'s own DACL already carries what [grantCapability] would
  /// set for [capabilitySid], at [inheritance].
  GrantInspection holdsCapability({
    required String capabilitySid,
    required String path,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  });

  /// Grants the capability [capabilitySid] read (+execute) on [path] with
  /// [inheritance]. Returns a failure reason, or null on success.
  String? grantCapability({
    required String capabilitySid,
    required String path,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  });

  /// Removes the capability [capabilitySid]'s ACEs from [path] (undo
  /// [grantCapability]).
  void revokeCapability({
    required String capabilitySid,
    required String path,
  });

  /// Carves a hole at [path] by breaking DACL inheritance and leaving it
  /// ungranted. Returns a failure reason, or null on success.
  String? protect(String path);

  /// Removes the container [containerSid]'s ACEs from [path] (undo [grant]).
  void revoke({required String containerSid, required String path});

  /// Restores inheritance at [path] (undo [protect]).
  void unprotect(String path);

  /// Merges [containerSid] into the live loopback-exemption set.
  LoopbackOutcome addLoopback(String containerSid);

  /// Removes [containerSid] from the live loopback-exemption set.
  void removeLoopback(String containerSid);

  /// Deletes the profile for [containerSid] and frees its resources.
  void dispose(String containerSid);
}

/// What a DACL inspection found.
sealed class GrantInspection {
  const GrantInspection();
}

/// The grant is in place.
final class GrantHeld extends GrantInspection {
  /// Const so it composes once.
  const GrantHeld();
}

/// The grant is not there.
final class GrantMissing extends GrantInspection {
  /// Const so it composes once.
  const GrantMissing();
}

/// The DACL could not be read, for [reason].
final class GrantInspectionFailed extends GrantInspection {
  /// Wraps the failure [reason].
  const GrantInspectionFailed(this.reason);

  /// Why the DACL could not be read.
  final String reason;
}

/// Whether provisioning yielded a container SID.
sealed class ProvisionOutcome {
  const ProvisionOutcome();
}

/// Provisioned; the child runs as [containerSid] and owns [folder].
final class ProvisionSucceeded extends ProvisionOutcome {
  /// Wraps the container SID string and the profile's [folder].
  const ProvisionSucceeded(this.containerSid, {required this.folder});

  /// The AppContainer package SID (SDDL).
  final String containerSid;

  /// The profile's own folder under `%LOCALAPPDATA%\Packages`, which the
  /// container can already write without any grant.
  final String folder;
}

/// Provisioning failed, for [reason].
final class ProvisionFailed extends ProvisionOutcome {
  /// Wraps the failure [reason].
  const ProvisionFailed(this.reason);

  /// Why the profile could not be provisioned.
  final String reason;
}

/// Whether the loopback exemption stuck. The tri-state that carries the
/// Developer Mode gate up to the adapter's tier decision.
sealed class LoopbackOutcome {
  const LoopbackOutcome();
}

/// The exemption is programmed; loopback is reachable.
final class LoopbackApplied extends LoopbackOutcome {
  /// Const so it composes once.
  const LoopbackApplied();
}

/// Developer Mode is off — the exemption cannot be programmed unelevated.
final class LoopbackDeveloperModeOff extends LoopbackOutcome {
  /// Const so it composes once.
  const LoopbackDeveloperModeOff();
}

/// The exemption failed for a reason other than Developer Mode.
final class LoopbackFailed extends LoopbackOutcome {
  /// Wraps the failure [reason].
  const LoopbackFailed(this.reason);

  /// Why the exemption could not be programmed.
  final String reason;
}
