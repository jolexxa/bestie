import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';

/// macOS confinement: lowers a [SandboxSpec] to a Seatbelt grant program the
/// forked child applies via `bestie_guard` before `exec`.
class SandboxMacos implements SandboxBackend {
  /// Confines through [fileSystem].
  SandboxMacos({required FileSystem fileSystem})
    : _compiler = LoweringCompiler(const NativeDenyLowering(), fileSystem);

  final LoweringCompiler _compiler;

  @override
  Future<SandboxAcquisition> acquire(SandboxSpec spec) async {
    switch (_compiler.compile(spec)) {
      case LoweringSucceeded(:final policy, :final report):
        final enforcement = _enforcementFrom(report, spec.network);
        return SandboxAcquired(
          _ConfinedMacosSandbox(
            confineProgram: encodeWire(policy, spec.network),
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

  SandboxEnforcement _enforcementFrom(
    EffectivePolicy report,
    NetworkTier network,
  ) => SandboxEnforcement(
    // `(deny default)` confines both dimensions unconditionally; empty
    // writableRoots means "writable to nothing", not "writes unconfined".
    enforced: const {
      SandboxCapability.filesystemRead,
      SandboxCapability.filesystemWrite,
    },
    readableRoots: report.readableRoots,
    writableRoots: report.writableRoots,
    deniedReads: report.deniedReads,
    network: _networkEnforcement(network),
    backend: 'seatbelt',
  );

  // Seatbelt enforces every tier in the one profile: it applies whole or the
  // child fails closed to `SandboxUnavailable`.
  NetworkEnforcement _networkEnforcement(NetworkTier network) =>
      NetworkConfined(network);
}

/// A macOS [Sandbox] carrying its lowered grant program and what it enforces.
class _ConfinedMacosSandbox implements PosixSandbox, ConfinedSandbox {
  const _ConfinedMacosSandbox({
    required this.confineProgram,
    required this.enforcement,
  });

  @override
  final Uint8List confineProgram;

  @override
  final SandboxEnforcement enforcement;
}
