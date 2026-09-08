import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_linux/src/probes.dart';

/// Linux confinement: lowers a [SandboxSpec] to a Landlock grant program the
/// forked child applies via `bestie_guard` before `exec`. Landlock has no
/// native deny, so reads are confined by enumeration (see
/// [EnumeratedDenyLowering]).
class SandboxLinux implements SandboxBackend {
  /// Confines through [fileSystem]. The [kernelProbe] is injectable so
  /// acquisition is testable without a real kernel.
  SandboxLinux({
    required FileSystem fileSystem,
    KernelProbe? kernelProbe,
  }) : _compiler = LoweringCompiler(
         const EnumeratedDenyLowering(),
         fileSystem,
       ),
       _kernel = kernelProbe ?? RealKernelProbe(fileSystem: fileSystem);

  final LoweringCompiler _compiler;
  final KernelProbe _kernel;

  @override
  Future<SandboxAcquisition> acquire(SandboxSpec spec) async {
    if (!await _kernel.landlockAvailable()) {
      return const SandboxUnavailable(
        'Landlock is not active on this kernel; confinement is unavailable.',
      );
    }

    switch (_compiler.compile(spec)) {
      case LoweringSucceeded(:final policy, :final report):
        final enforcement = await _enforcementFrom(report, spec.network);
        return SandboxAcquired(
          _ConfinedLinuxSandbox(
            confineProgram: encodeWire(policy, _wireTier(enforcement, spec)),
            enforcement: enforcement,
          ),
          enforcement,
        );
    }
  }

  /// Nothing is provisioned outside the child, so there is nothing to release.
  @override
  Future<void> release(Sandbox sandbox) async {}

  /// Nothing backend-wide is held, so there is nothing to dispose.
  @override
  Future<void> dispose() async {}

  Future<SandboxEnforcement> _enforcementFrom(
    EffectivePolicy report,
    NetworkTier requested,
  ) async => SandboxEnforcement(
    enforced: const {
      SandboxCapability.filesystemRead,
      SandboxCapability.filesystemWrite,
    },
    readableRoots: report.readableRoots,
    writableRoots: report.writableRoots,
    deniedReads: report.deniedReads,
    network: await _networkEnforcement(requested),
    backend: 'landlock',
  );

  /// Only `local` depends on unprivileged netns. Where it is unavailable the
  /// tier is reported ineligible; `none` and `all` are always enforceable.
  Future<NetworkEnforcement> _networkEnforcement(NetworkTier requested) async {
    if (requested == NetworkTier.local && !await _kernel.netnsAvailable()) {
      return const NetworkIneligibleForConfinement(
        NetworkTier.local,
        'unprivileged user+network namespaces are unavailable on this host',
      );
    }
    return NetworkConfined(requested);
  }

  /// The tier actually sent to the child. An ineligible `local` fails closed to
  /// the more restrictive `none` — never a silent widen to `all`.
  NetworkTier _wireTier(SandboxEnforcement enforcement, SandboxSpec spec) =>
      enforcement.network is NetworkIneligibleForConfinement
      ? NetworkTier.none
      : spec.network;
}

/// A Linux [Sandbox] carrying its lowered grant program and what it enforces.
class _ConfinedLinuxSandbox implements PosixSandbox, ConfinedSandbox {
  const _ConfinedLinuxSandbox({
    required this.confineProgram,
    required this.enforcement,
  });

  @override
  final Uint8List confineProgram;

  @override
  final SandboxEnforcement enforcement;
}
