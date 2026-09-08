import 'dart:io' show Platform;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:sandbox_windows/src/sandbox_worker.dart';
import 'package:win32_dart/win32_dart.dart' show capabilityInternetClientSid;

/// Windows confinement, via an AppContainer profile and the ACLs that grant it.
///
/// Reads are broad and shared: home is ACL'd once to the bestie-read capability
/// (via [grantSharedRead]), which every child carries. Writes are the jail: a
/// per-workspace package SID granted write on the workspace, applied once and
/// left in place. Nothing is reversed on [release] — reclamation is the
/// repository's startup GC driving [reverseWorkspace] and [reverseSharedRead].
class SandboxWindows implements SandboxBackend {
  /// Confines through [worker] and [fileSystem]. [bestieReadCapabilitySid],
  /// when set, is attached to every child so it reads whatever the shared
  /// read grant covers. [systemRoots] are the trees already readable via
  /// `ALL APPLICATION PACKAGES` (System32, Program Files) — grants there are
  /// skipped, since re-ACLing a system directory is redundant and needs admin.
  SandboxWindows(
    SandboxWorker worker, {
    String? bestieReadCapabilitySid,
    String? helperExecutable,
    List<String> helperArguments = const [],
    FileSystem fileSystem = const LocalFileSystem(),
    List<String>? systemRoots,
  }) : _worker = worker,
       _bestieReadCapabilitySid = bestieReadCapabilitySid,
       _helperExecutable = helperExecutable,
       _helperArguments = helperArguments,
       _fs = fileSystem,
       _systemRoots = systemRoots ?? _defaultSystemRoots(),
       _compiler = LoweringCompiler(const NativeDenyLowering(), fileSystem);

  final FileSystem _fs;
  final String? _bestieReadCapabilitySid;

  final String? _helperExecutable;

  final List<String> _helperArguments;
  final List<String> _systemRoots;
  final LoweringCompiler _compiler;
  final SandboxWorker _worker;

  /// The trees every AppContainer can already list.
  List<String> get systemRoots => _systemRoots;

  /// Provisions [spec]; the worker re-walks only a tree whose ACE is missing.
  @override
  Future<SandboxAcquisition> acquire(SandboxSpec spec) async {
    final outcome = _compiler.compile(spec);
    if (outcome is! LoweringSucceeded) {
      return SandboxUnavailable(outcome.toString());
    }
    // Windows composes NativeDenyLowering, which always yields a MaskedProgram.
    final masked = outcome.policy as MaskedProgram;
    final report = outcome.report;

    final response = await _worker.send(ApplyPlan(_plan(spec, masked)));
    switch (response) {
      case ProvisionApplied(
        :final containerSid,
        :final tempDir,
        :final network,
      ):
        final enforcement = SandboxEnforcement(
          enforced: const {
            SandboxCapability.filesystemRead,
            SandboxCapability.filesystemWrite,
          },
          readableRoots: report.readableRoots,
          writableRoots: [...report.writableRoots, tempDir],
          deniedReads: report.deniedReads,
          network: network,
          backend: 'AppContainer',
        );
        return SandboxAcquired(
          _ConfinedWindowsSandbox(
            containerSid: containerSid,
            capabilitySids: _capabilitiesFor(spec.network),
            workingDirectory: spec.workspaceRoot,
            tempDir: tempDir,
            enforcement: enforcement,
          ),
          enforcement,
        );
      case ProvisionFailedResponse(:final operation, :final reason):
        return SandboxProvisioningFailed(operation: operation, reason: reason);
      case SharedReadApplied() ||
          Reversed() ||
          AncestorsInspected() ||
          AncestorGrantApplied() ||
          AncestorGrantRefused():
        return const SandboxProvisioningFailed(
          operation: 'apply',
          reason: 'worker returned an unexpected response',
        );
    }
  }

  /// Grants the bestie-read capability [readRoots] RX with [holes] carved out,
  /// skipping absent paths so a secret dir the user lacks can't fail the grant.
  /// Returns a failure reason, or null on success.
  Future<String?> grantSharedRead({
    required String capabilitySid,
    required List<String> readRoots,
    required List<String> holes,
  }) async {
    final response = await _worker.send(
      GrantSharedRead(
        capabilitySid: capabilitySid,
        readRoots: readRoots.where(_present).toList(),
        holes: holes.where(_present).toList(),
      ),
    );
    return switch (response) {
      SharedReadApplied() => null,
      ProvisionFailedResponse(:final operation, :final reason) =>
        '$operation: $reason',
      _ => 'worker returned an unexpected response',
    };
  }

  /// Reverses a prior [grantSharedRead], over the same present paths.
  Future<void> reverseSharedRead({
    required String capabilitySid,
    required List<String> readRoots,
    required List<String> holes,
  }) async {
    await _worker.send(
      ReverseSharedRead(
        capabilitySid: capabilitySid,
        readRoots: readRoots.where(_present).toList(),
        holes: holes.where(_present).toList(),
      ),
    );
  }

  /// Which of [ancestors] the bestie-read capability cannot list yet; all are
  /// listable when no capability is set.
  Future<AncestorInspection> unlistedAncestors(List<String> ancestors) async {
    final capabilitySid = _bestieReadCapabilitySid;
    if (capabilitySid == null || ancestors.isEmpty) {
      return const AncestorsListable();
    }
    final response = await _worker.send(
      InspectAncestors(capabilitySid: capabilitySid, paths: ancestors),
    );
    return switch (response) {
      AncestorsInspected(:final missing) =>
        missing.isEmpty
            ? const AncestorsListable()
            : AncestorsUnlisted(missing),
      ProvisionFailedResponse(:final operation, :final reason) =>
        AncestorInspectionFailed('$operation: $reason'),
      _ => const AncestorInspectionFailed(
        'worker returned an unexpected response',
      ),
    };
  }

  /// Grants the bestie-read capability list access on [ancestors] through the
  /// elevated helper, then reports what the DACLs say.
  Future<AncestorGrantOutcome> grantAncestorListing(
    List<String> ancestors,
  ) async {
    final capabilitySid = _bestieReadCapabilitySid;
    final executable = _helperExecutable;
    if (capabilitySid == null || executable == null) {
      return const AncestorGrantFailed('no elevated helper is configured');
    }
    final response = await _worker.send(
      GrantAncestors(
        capabilitySid: capabilitySid,
        paths: ancestors,
        executable: executable,
        leadingArguments: _helperArguments,
      ),
    );
    return switch (response) {
      AncestorGrantApplied() => const AncestorsGranted(),
      AncestorGrantRefused() => const AncestorGrantDeclined(),
      ProvisionFailedResponse(:final operation, :final reason) =>
        AncestorGrantFailed('$operation: $reason'),
      _ => const AncestorGrantFailed('worker returned an unexpected response'),
    };
  }

  /// Reclaims a stale workspace: revokes its write grants, on the workspace
  /// and on [widenedRoots] beyond it, and deletes its profile. Called by the
  /// repository's startup GC and reset.
  Future<void> reverseWorkspace({
    required String profileName,
    required String workspaceRoot,
    required List<String> widenedRoots,
  }) async {
    await _worker.send(
      ReverseWorkspace(
        profileName: profileName,
        workspaceRoot: workspaceRoot,
        widenedRoots: widenedRoots,
      ),
    );
  }

  /// Takes write on [roots] back from a live workspace's container, leaving
  /// its profile for the narrower spec about to be acquired.
  Future<void> narrowWorkspace({
    required String profileName,
    required List<String> roots,
  }) async {
    await _worker.send(NarrowWorkspace(profileName: profileName, roots: roots));
  }

  /// The deterministic profile name for [workspaceRoot], so the GC and a later
  /// acquire agree on which profile a workspace maps to.
  String profileNameFor(String workspaceRoot) => _profileName(workspaceRoot);

  /// A no-op: grants persist across sessions; reclamation is the startup GC.
  @override
  Future<void> release(Sandbox sandbox) async {}

  /// Shuts the provisioning worker isolate down. Call at app teardown.
  @override
  Future<void> dispose() => _worker.close();

  /// Compiles the masked program into a flat plan the worker executes — only
  /// the write grants; reads are the shared capability's.
  ProvisionPlan _plan(SandboxSpec spec, MaskedProgram masked) {
    final grants = <PlanGrant>[
      for (final grant in masked.grants)
        if (grant.access == GrantAccess.readWrite &&
            !_coveredBySystem(grant.path) &&
            _present(grant.path))
          PlanGrant(grant.path, write: true),
    ];
    return ProvisionPlan(
      profileName: _profileName(spec.workspaceRoot),
      grants: grants,
      network: spec.network,
    );
  }

  List<String> _capabilitiesFor(NetworkTier tier) => [
    ?_bestieReadCapabilitySid,
    if (tier == NetworkTier.all) capabilityInternetClientSid,
  ];

  bool _present(String path) =>
      _fs.typeSync(path) != FileSystemEntityType.notFound;

  bool _coveredBySystem(String path) {
    final lower = path.toLowerCase();
    return _systemRoots.any((root) => lower.startsWith(root.toLowerCase()));
  }

  /// A deterministic, filesystem-safe profile name per workspace, so reopening
  /// the same workspace reuses its profile (create-or-derive). FNV-1a keeps it
  /// stable across runs, where `hashCode` would not.
  String _profileName(String workspaceRoot) =>
      'bestie.sandbox.${_fnv1a(workspaceRoot)}';
}

/// Whether the bestie-read capability can list a set of ancestor directories.
sealed class AncestorInspection {
  /// Const base for the sealed hierarchy.
  const AncestorInspection();
}

/// Every ancestor is listable; nothing to grant.
final class AncestorsListable extends AncestorInspection {
  /// Const so it composes once.
  const AncestorsListable();
}

/// [missing] cannot be listed yet.
final class AncestorsUnlisted extends AncestorInspection {
  /// Wraps the [missing] directories.
  const AncestorsUnlisted(this.missing);

  /// The directories the capability cannot list.
  final List<String> missing;
}

/// The DACLs could not be read, for [reason].
final class AncestorInspectionFailed extends AncestorInspection {
  /// Wraps the failure [reason].
  const AncestorInspectionFailed(this.reason);

  /// Why the DACLs could not be read.
  final String reason;
}

/// What came of the elevated ancestor grant.
sealed class AncestorGrantOutcome {
  /// Const base for the sealed hierarchy.
  const AncestorGrantOutcome();
}

/// Every ancestor now holds its list grant.
final class AncestorsGranted extends AncestorGrantOutcome {
  /// Const so it composes once.
  const AncestorsGranted();
}

/// The user declined the elevation prompt; nothing changed.
final class AncestorGrantDeclined extends AncestorGrantOutcome {
  /// Const so it composes once.
  const AncestorGrantDeclined();
}

/// The helper could not run or left ancestors unlisted, for [reason].
final class AncestorGrantFailed extends AncestorGrantOutcome {
  /// Wraps the failure [reason].
  const AncestorGrantFailed(this.reason);

  /// Why the grant failed.
  final String reason;
}

/// A Windows [Sandbox] carrying the container SID and capabilities the host
/// rebuilds `SECURITY_CAPABILITIES` from, plus what it enforces.
class _ConfinedWindowsSandbox implements WindowsSandbox, ConfinedSandbox {
  const _ConfinedWindowsSandbox({
    required this.containerSid,
    required this.capabilitySids,
    required this.workingDirectory,
    required this.tempDir,
    required this.enforcement,
  });

  @override
  final String containerSid;

  @override
  final List<String> capabilitySids;

  @override
  final String workingDirectory;

  @override
  final String tempDir;

  @override
  final SandboxEnforcement enforcement;
}

List<String> _defaultSystemRoots() => [
  for (final key in const [
    'SystemRoot',
    'ProgramFiles',
    'ProgramFiles(x86)',
    'ProgramW6432',
  ])
    ?Platform.environment[key],
];

String _fnv1a(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = (hash ^ unit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
