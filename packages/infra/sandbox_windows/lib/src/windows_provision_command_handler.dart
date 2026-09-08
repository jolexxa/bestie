import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_windows/src/ancestor_grant_helper.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:sandbox_windows/src/win32_provisioner.dart';
import 'package:sandbox_windows/src/windows_elevator.dart';
import 'package:sandbox_windows/src/windows_provisioner.dart';
import 'package:win32_dart/win32_dart.dart' show NO_INHERITANCE;

/// Runs the blocking AppContainer provisioning on the worker isolate.
class WindowsProvisionCommandHandler {
  /// Confines through [provisioner] when supplied; otherwise the real win32
  /// host, built lazily inside the worker isolate on first use. The container
  /// temp directory is created through [fileSystem].
  WindowsProvisionCommandHandler({
    WindowsProvisioner? provisioner,
    WindowsElevator? elevator,
    FileSystem fileSystem = const LocalFileSystem(),
  }) : _provided = provisioner,
       _providedElevator = elevator,
       _fs = fileSystem;

  final WindowsProvisioner? _provided;
  final WindowsElevator? _providedElevator;
  final FileSystem _fs;

  WindowsProvisioner? _instance;
  WindowsProvisioner get _provisioner =>
      _instance ??= _provided ?? Win32Provisioner();

  WindowsElevator? _elevatorInstance;
  WindowsElevator get _elevator =>
      _elevatorInstance ??= _providedElevator ?? Win32Elevator();

  /// The [IsolateCommandHandler] entry point.
  FutureOr<ProvisionResponse> call(
    ProvisionRequest request, [
    IsolateRequestContext context = IsolateRequestContext.none,
  ]) => switch (request) {
    ApplyPlan(:final plan) => _apply(plan),
    GrantSharedRead() => _grantSharedRead(request),
    ReverseSharedRead() => _reverseSharedRead(request),
    ReverseWorkspace() => _reverseWorkspace(request),
    NarrowWorkspace() => _narrowWorkspace(request),
    InspectAncestors(:final capabilitySid, :final paths) => _inspectAncestors(
      capabilitySid,
      paths,
    ),
    GrantAncestors() => _grantAncestors(request),
  };

  /// Which of [paths] lack a this-folder-only list grant for [capabilitySid];
  /// an unreadable DACL counts as missing.
  ProvisionResponse _inspectAncestors(
    String capabilitySid,
    List<String> paths,
  ) {
    final missing = <String>[
      for (final path in paths)
        if (_provisioner.holdsCapability(
              capabilitySid: capabilitySid,
              path: path,
              inheritance: NO_INHERITANCE,
            )
            is! GrantHeld)
          path,
    ];
    return AncestorsInspected(missing);
  }

  /// Runs the helper elevated, then reads the DACLs rather than trusting the
  /// exit code.
  ProvisionResponse _grantAncestors(GrantAncestors request) {
    final ran = _elevator.run(
      executable: request.executable,
      arguments: [
        ...request.leadingArguments,
        grantSandboxAncestorsFlag,
        ...request.paths,
      ],
    );
    switch (ran) {
      case ElevatedRunDeclined():
        return const AncestorGrantRefused();
      case ElevatedRunFailed(:final reason):
        return ProvisionFailedResponse(operation: 'elevate', reason: reason);
      case ElevatedRunCompleted():
        final inspected =
            _inspectAncestors(request.capabilitySid, request.paths)
                as AncestorsInspected;
        if (inspected.missing.isEmpty) return const AncestorGrantApplied();
        return ProvisionFailedResponse(
          operation: 'grant ancestors',
          reason:
              'the helper ended with ${ran.exitCode} and left '
              '${inspected.missing.join(', ')} unlisted',
        );
    }
  }

  ProvisionResponse _apply(ProvisionPlan plan) {
    final provisioned = _provisioner.provision(plan.profileName);
    if (provisioned is ProvisionFailed) {
      return ProvisionFailedResponse(
        operation: 'provision',
        reason: provisioned.reason,
      );
    }
    final sid = (provisioned as ProvisionSucceeded).containerSid;

    // The profile folder is the container's already; only the temp directory
    // inside it needs to exist before the child looks for it.
    final tempDir = _fs.path.join(provisioned.folder, 'AC', 'Temp');
    try {
      _fs.directory(tempDir).createSync(recursive: true);
    } on FileSystemException catch (error) {
      _provisioner.dispose(sid);
      return ProvisionFailedResponse(
        operation: 'temp $tempDir',
        reason: error.message,
      );
    }

    // Only grants this call applied are rolled back on failure.
    final granted = <String>[];
    ProvisionFailedResponse fail(String operation, String reason) {
      for (final path in granted) {
        _provisioner.revoke(containerSid: sid, path: path);
      }
      _provisioner.dispose(sid);
      return ProvisionFailedResponse(operation: operation, reason: reason);
    }

    for (final grant in plan.grants) {
      switch (_provisioner.holds(
        containerSid: sid,
        path: grant.path,
        write: grant.write,
      )) {
        case GrantHeld():
          continue;
        case GrantInspectionFailed(:final reason):
          return fail('inspect ${grant.path}', reason);
        case GrantMissing():
          final reason = _provisioner.grant(
            containerSid: sid,
            path: grant.path,
            write: grant.write,
          );
          if (reason != null) return fail('grant ${grant.path}', reason);
          granted.add(grant.path);
      }
    }

    return _applied(sid, tempDir, plan.network);
  }

  ProvisionResponse _grantSharedRead(GrantSharedRead request) {
    final granted = <String>[];
    for (final root in request.readRoots) {
      final reason = _provisioner.grantCapability(
        capabilitySid: request.capabilitySid,
        path: root,
      );
      if (reason != null) {
        for (final path in granted) {
          _provisioner.revokeCapability(
            capabilitySid: request.capabilitySid,
            path: path,
          );
        }
        return ProvisionFailedResponse(
          operation: 'shared read $root',
          reason: reason,
        );
      }
      granted.add(root);
    }
    for (final hole in request.holes) {
      final reason = _provisioner.protect(hole);
      if (reason != null) {
        return ProvisionFailedResponse(
          operation: 'protect $hole',
          reason: reason,
        );
      }
    }
    return const SharedReadApplied();
  }

  ProvisionResponse _reverseSharedRead(ReverseSharedRead request) {
    // An empty reversal has nothing to undo, so it must not touch the native
    // provisioner — reading `_provisioner` here (even to tear off a method)
    // would build the win32 host for no reason.
    if (request.holes.isEmpty && request.readRoots.isEmpty) {
      return const Reversed();
    }
    final provisioner = _provisioner;
    request.holes.forEach(provisioner.unprotect);
    for (final root in request.readRoots) {
      // A revoke walks the whole tree, so a root never granted is skipped.
      final held = provisioner.holdsCapability(
        capabilitySid: request.capabilitySid,
        path: root,
      );
      if (held is GrantMissing) continue;
      provisioner.revokeCapability(
        capabilitySid: request.capabilitySid,
        path: root,
      );
    }
    return const Reversed();
  }

  ProvisionResponse _reverseWorkspace(ReverseWorkspace request) {
    final provisioned = _provisioner.provision(request.profileName);
    if (provisioned is! ProvisionSucceeded) return const Reversed();
    final sid = provisioned.containerSid;
    _revoke(sid, [request.workspaceRoot, ...request.widenedRoots]);
    _provisioner
      ..removeLoopback(sid)
      ..dispose(sid);
    return const Reversed();
  }

  ProvisionResponse _narrowWorkspace(NarrowWorkspace request) {
    final provisioned = _provisioner.provision(request.profileName);
    if (provisioned is! ProvisionSucceeded) return const Reversed();
    _revoke(provisioned.containerSid, request.roots);
    return const Reversed();
  }

  void _revoke(String sid, List<String> paths) {
    for (final path in paths) {
      _provisioner.revoke(containerSid: sid, path: path);
    }
  }

  /// The applied response for [sid], with the loopback exemption programmed
  /// for any [tier] that reaches localhost.
  ProvisionApplied _applied(String sid, String tempDir, NetworkTier tier) {
    ProvisionApplied applied(
      NetworkEnforcement network, {
      bool exempted = false,
    }) => ProvisionApplied(
      containerSid: sid,
      tempDir: tempDir,
      network: network,
      loopbackExempted: exempted,
    );
    switch (tier) {
      case NetworkTier.none:
        return applied(const NetworkConfined(NetworkTier.none));
      case NetworkTier.local:
        return switch (_provisioner.addLoopback(sid)) {
          LoopbackApplied() => applied(
            const NetworkConfined(NetworkTier.local),
            exempted: true,
          ),
          LoopbackDeveloperModeOff() => applied(
            const NetworkIneligibleForConfinement(
              NetworkTier.local,
              'loopback needs Developer Mode',
            ),
          ),
          LoopbackFailed(:final reason) => applied(
            NetworkIneligibleForConfinement(NetworkTier.local, reason),
          ),
        };
      case NetworkTier.all:
        return switch (_provisioner.addLoopback(sid)) {
          LoopbackApplied() => applied(
            const NetworkConfined(NetworkTier.all),
            exempted: true,
          ),
          LoopbackDeveloperModeOff() => applied(
            const NetworkPartiallyConfined(
              NetworkTier.all,
              'loopback',
              'localhost needs Developer Mode',
            ),
          ),
          LoopbackFailed(:final reason) => applied(
            NetworkPartiallyConfined(NetworkTier.all, 'loopback', reason),
          ),
        };
    }
  }
}
