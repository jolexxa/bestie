import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_grant_store/sandbox_grant_store.dart';
import 'package:sandbox_repository/src/host_preparation.dart';
import 'package:sandbox_repository/src/sandbox_read_policy.dart';
import 'package:sandbox_repository/src/sandbox_repository.dart';
import 'package:sandbox_windows/sandbox_windows.dart';

/// The Windows sandbox lifecycle: read the world, write the jail. The DACLs,
/// not the store, say what is granted; the store only says what to take back,
/// at the startup GC, on reset, and when a spec narrows.
@repository
class SandboxRepositoryForWindows extends SandboxRepository {
  SandboxRepositoryForWindows({
    required SandboxWindows sandboxBackend,
    required SandboxGrantStore store,
    required String bestieReadCapabilitySid,
    required SandboxReadPolicy readPolicy,
    Clock clock = const Clock(),
    Duration staleAfter = const Duration(days: 30),
  }) : _sandboxBackend = sandboxBackend,
       _store = store,
       _bestieReadCapabilitySid = bestieReadCapabilitySid,
       _readPolicy = readPolicy,
       _clock = clock,
       _staleAfter = staleAfter,
       super(sandboxBackend, preparesHost: true);

  final SandboxWindows _sandboxBackend;
  final SandboxGrantStore _store;
  final String _bestieReadCapabilitySid;
  final SandboxReadPolicy _readPolicy;
  final Clock _clock;
  final Duration _staleAfter;

  /// Prepared once the shared read grant matches the policy and every
  /// ancestor is listable.
  @override
  Future<bool> hostPrepared(SandboxSpec spec) async {
    if (_store.load().read != _desiredRead) return false;
    return await _sandboxBackend.unlistedAncestors(_ancestorsOf(spec))
        is AncestorsListable;
  }

  /// The elevated ancestor grant for whatever is missing, then the shared
  /// read reconcile. A declined prompt stops before the walk over home.
  @override
  Future<HostPreparation> prepareHost(SandboxSpec spec) async {
    switch (await _sandboxBackend.unlistedAncestors(_ancestorsOf(spec))) {
      case AncestorsListable():
        break;
      case AncestorInspectionFailed(:final reason):
        return HostPreparationFailed(reason);
      case AncestorsUnlisted(:final missing):
        switch (await _sandboxBackend.grantAncestorListing(missing)) {
          case AncestorsGranted():
            break;
          case AncestorGrantDeclined():
            return const HostPreparationDeclined();
          case AncestorGrantFailed(:final reason):
            return HostPreparationFailed(reason);
        }
    }
    final reason = await _reconcileSharedRead();
    return reason == null
        ? const HostPrepared()
        : HostPreparationFailed(reason);
  }

  /// Reclaims workspaces unseen past the stale window.
  @override
  Future<void> reclaimHost() => _collectGarbage();

  /// Reverses every grant on record and forgets the store. The ancestor
  /// grants stay: list-only, and needed again as soon as the sandbox is
  /// rebuilt.
  @override
  Future<void> resetHost() async {
    final grants = _store.load();
    final read = grants.read;
    if (read != null) {
      await _sandboxBackend.reverseSharedRead(
        capabilitySid: read.capabilitySid,
        readRoots: read.readRoots,
        holes: read.holes,
      );
    }
    for (final entry in grants.workspaces) {
      await _reverse(entry);
    }
    _store.clear();
  }

  /// Takes back the widened roots on record that [spec] drops, provisions it,
  /// and records the workspace for the startup GC.
  @override
  Future<SandboxAcquisition> provision(SandboxSpec spec) async {
    final widened = _widenedBy(spec);
    final stale = _store
        .load()
        .workspaces
        .where((entry) => entry.workspaceRoot == spec.workspaceRoot)
        .expand((entry) => entry.widenedRoots)
        .where((root) => !widened.contains(root))
        .toList();
    if (stale.isNotEmpty) {
      await _sandboxBackend.narrowWorkspace(
        profileName: _sandboxBackend.profileNameFor(spec.workspaceRoot),
        roots: stale,
      );
    }
    final acquisition = await _sandboxBackend.acquire(spec);
    if (acquisition case SandboxAcquired(
      :final sandbox,
    ) when sandbox is WindowsSandbox) {
      _record(spec.workspaceRoot, sandbox.containerSid, widened);
    }
    return acquisition;
  }

  SandboxReadGrant get _desiredRead => SandboxReadGrant(
    capabilitySid: _bestieReadCapabilitySid,
    readRoots: _readPolicy.readRoots,
    holes: _readPolicy.holes,
    policyVersion: _readPolicy.policyVersion,
  );

  List<String> _ancestorsOf(SandboxSpec spec) => unlistedAncestorsOf(
    roots: [
      ..._readPolicy.readRoots,
      ...spec.readableRoots,
      spec.workspaceRoot,
    ],
    systemRoots: _sandboxBackend.systemRoots,
    context: p.windows,
  );

  /// The write roots [spec] names beyond its workspace.
  List<String> _widenedBy(SandboxSpec spec) =>
      spec.writableRoots.where((root) => root != spec.workspaceRoot).toList();

  Future<void> _reverse(SandboxWorkspaceEntry entry) =>
      _sandboxBackend.reverseWorkspace(
        profileName: entry.profileName,
        workspaceRoot: entry.workspaceRoot,
        widenedRoots: entry.widenedRoots,
      );

  /// Reconciles broad read; returns a failure reason, or null once the record
  /// matches.
  Future<String?> _reconcileSharedRead() async {
    final grants = _store.load();
    final desired = _desiredRead;
    final current = grants.read;
    if (current == desired) return null;

    if (current != null) {
      await _sandboxBackend.reverseSharedRead(
        capabilitySid: current.capabilitySid,
        readRoots: current.readRoots,
        holes: current.holes,
      );
    }
    final reason = await _sandboxBackend.grantSharedRead(
      capabilitySid: desired.capabilitySid,
      readRoots: desired.readRoots,
      holes: desired.holes,
    );
    if (reason != null) return reason;
    _store.save(SandboxGrants(read: desired, workspaces: grants.workspaces));
    return null;
  }

  Future<void> _collectGarbage() async {
    final grants = _store.load();
    final cutoff = _clock.now().subtract(_staleAfter);
    final live = <SandboxWorkspaceEntry>[];
    final stale = <SandboxWorkspaceEntry>[];
    for (final entry in grants.workspaces) {
      (entry.lastSeen.isBefore(cutoff) ? stale : live).add(entry);
    }
    if (stale.isEmpty) return;

    for (final entry in stale) {
      await _reverse(entry);
    }
    _store.save(SandboxGrants(read: grants.read, workspaces: live));
  }

  void _record(
    String workspaceRoot,
    String containerSid,
    List<String> widenedRoots,
  ) {
    final grants = _store.load();
    final entry = SandboxWorkspaceEntry(
      workspaceRoot: workspaceRoot,
      profileName: _sandboxBackend.profileNameFor(workspaceRoot),
      containerSid: containerSid,
      lastSeen: _clock.now(),
      widenedRoots: widenedRoots,
    );
    final others = grants.workspaces.where(
      (w) => w.workspaceRoot != workspaceRoot,
    );
    _store.save(
      SandboxGrants(read: grants.read, workspaces: [...others, entry]),
    );
  }
}
