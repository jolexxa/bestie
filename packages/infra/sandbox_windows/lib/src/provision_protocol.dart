import 'package:sandbox/sandbox.dart';

/// The wire protocol between `SandboxWindows` on the main isolate and the
/// `WindowsProvisionCommandHandler` on the worker isolate.

/// One grant to apply: read (+execute) on [path], or read-write when [write].
class PlanGrant {
  /// A grant of [path], read-write when [write].
  const PlanGrant(this.path, {required this.write});

  /// The path to grant the container.
  final String path;

  /// Whether the grant includes write.
  final bool write;
}

/// The fully-resolved per-workspace provisioning to apply.
class ProvisionPlan {
  /// Provisions [profileName], applying [grants] and the [network] tier.
  const ProvisionPlan({
    required this.profileName,
    required this.grants,
    required this.network,
  });

  /// The deterministic AppContainer profile name for this workspace.
  final String profileName;

  /// The grants to apply, already filtered of system-covered and absent paths.
  final List<PlanGrant> grants;

  /// The requested network tier.
  final NetworkTier network;
}

/// A request the worker isolate handles.
sealed class ProvisionRequest {
  const ProvisionRequest();
}

/// Provision a profile and apply [plan] to it.
final class ApplyPlan extends ProvisionRequest {
  /// Applies [plan].
  const ApplyPlan(this.plan);

  /// The plan to provision and apply.
  final ProvisionPlan plan;
}

/// Grant the shared bestie-read capability broad read: [readRoots] RX
/// (inherited) to [capabilitySid], with [holes] carved out.
final class GrantSharedRead extends ProvisionRequest {
  /// Grants [readRoots] to [capabilitySid] with [holes] carved out.
  const GrantSharedRead({
    required this.capabilitySid,
    required this.readRoots,
    required this.holes,
  });

  /// The bestie-read capability SID (SDDL) the roots are ACL'd to.
  final String capabilitySid;

  /// The roots granted RX, inherited.
  final List<String> readRoots;

  /// The secret subpaths carved out of the granted roots.
  final List<String> holes;
}

/// Reverse a prior [GrantSharedRead] — undo the holes and revoke the capability
/// from each root.
final class ReverseSharedRead extends ProvisionRequest {
  /// Reverses [readRoots] and [holes] for [capabilitySid].
  const ReverseSharedRead({
    required this.capabilitySid,
    required this.readRoots,
    required this.holes,
  });

  /// The capability SID whose grants to revoke.
  final String capabilitySid;

  /// The roots to revoke.
  final List<String> readRoots;

  /// The holes to restore.
  final List<String> holes;
}

/// Which of [paths] the capability [capabilitySid] cannot yet list.
final class InspectAncestors extends ProvisionRequest {
  /// Inspects [paths] for [capabilitySid].
  const InspectAncestors({required this.capabilitySid, required this.paths});

  /// The bestie-read capability SID (SDDL).
  final String capabilitySid;

  /// The ancestor directories to inspect.
  final List<String> paths;
}

/// Grant [capabilitySid] list access on [paths] through the elevated helper.
final class GrantAncestors extends ProvisionRequest {
  /// Grants [paths] to [capabilitySid] through an elevated [executable].
  const GrantAncestors({
    required this.capabilitySid,
    required this.paths,
    required this.executable,
    this.leadingArguments = const [],
  });

  /// The bestie-read capability SID (SDDL).
  final String capabilitySid;

  /// The ancestor directories to grant.
  final List<String> paths;

  /// The program to run elevated.
  final String executable;

  /// Arguments ahead of the helper flag (`run <script>` from source).
  final List<String> leadingArguments;
}

/// Reclaim a workspace: revoke its write grants, drop its loopback exemption,
/// and delete its profile.
final class ReverseWorkspace extends ProvisionRequest {
  /// Reverses the workspace at [workspaceRoot] provisioned under [profileName],
  /// widened to [widenedRoots].
  const ReverseWorkspace({
    required this.profileName,
    required this.workspaceRoot,
    required this.widenedRoots,
  });

  /// The profile to derive, reverse, and delete.
  final String profileName;

  /// The workspace root whose write grant to revoke.
  final String workspaceRoot;

  /// The directories beyond the workspace whose write grants to revoke.
  final List<String> widenedRoots;
}

/// Take write on [roots] back from a live workspace's container. The profile
/// stays: the workspace goes on under it, narrower.
final class NarrowWorkspace extends ProvisionRequest {
  /// Revokes [roots] from the container of [profileName].
  const NarrowWorkspace({required this.profileName, required this.roots});

  /// The profile to derive and narrow.
  final String profileName;

  /// The directories whose write grants to revoke.
  final List<String> roots;
}

/// A response the worker isolate returns.
sealed class ProvisionResponse {
  const ProvisionResponse();
}

/// The plan was applied; the child runs as [containerSid] with [tempDir] as
/// its own temp directory. [network] is what the tier actually became, and
/// [loopbackExempted] whether an exemption was programmed.
final class ProvisionApplied extends ProvisionResponse {
  /// Provisioned as [containerSid] with [tempDir] and [network] enforcement.
  const ProvisionApplied({
    required this.containerSid,
    required this.tempDir,
    required this.network,
    required this.loopbackExempted,
  });

  /// The AppContainer package SID (SDDL).
  final String containerSid;

  /// The container's own temp directory, inside its profile folder.
  final String tempDir;

  /// What became of the requested network tier.
  final NetworkEnforcement network;

  /// Whether a loopback exemption was programmed.
  final bool loopbackExempted;
}

/// The shared read capability's roots and holes were applied.
final class SharedReadApplied extends ProvisionResponse {
  /// Applied.
  const SharedReadApplied();
}

/// A prior shared-read grant, or a stale workspace, was reversed.
final class Reversed extends ProvisionResponse {
  /// Reversed.
  const Reversed();
}

/// The ancestors were inspected; [missing] cannot be listed yet.
final class AncestorsInspected extends ProvisionResponse {
  /// Wraps the [missing] directories.
  const AncestorsInspected(this.missing);

  /// The directories still lacking a list grant.
  final List<String> missing;
}

/// The elevated helper ran and every ancestor now holds its grant.
final class AncestorGrantApplied extends ProvisionResponse {
  /// Granted.
  const AncestorGrantApplied();
}

/// The user declined the elevation prompt; nothing changed.
final class AncestorGrantRefused extends ProvisionResponse {
  /// Declined.
  const AncestorGrantRefused();
}

/// Provisioning failed at [operation], for [reason].
final class ProvisionFailedResponse extends ProvisionResponse {
  /// Failed at [operation] for [reason].
  const ProvisionFailedResponse({
    required this.operation,
    required this.reason,
  });

  /// The step that failed (provision, a grant, a hole).
  final String operation;

  /// Why it failed.
  final String reason;
}
