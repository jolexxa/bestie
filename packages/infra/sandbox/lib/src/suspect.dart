import 'package:process_host/process_host.dart';
import 'package:sandbox/src/confined_sandbox.dart';
import 'package:sandbox/src/sandbox_enforcement.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:sandbox/src/suspicion.dart';

/// Diagnoses which live restrictions could explain a confined process failure.
class SandboxSuspector {
  /// Const so a caller can compose it once.
  const SandboxSuspector();

  /// Every live restriction that could explain [exit], with the [output]
  /// lines consistent with it.
  List<SandboxSuspicion> suspect({
    required ProcessExit exit,
    required Sandbox? sandbox,
    required List<String> output,
  }) {
    if (exit case ProcessExited(code: 0)) return const [];
    if (sandbox is! ConfinedSandbox) return const [];

    final enforcement = sandbox.enforcement;
    final lines = output.map((line) => line.toLowerCase()).toList();

    return [
      for (final dimension in SandboxDimension.values)
        if (_isLive(dimension, enforcement))
          SandboxSuspicion(
            dimension: dimension,
            evidence: _evidenceFor(dimension, output, lines),
          ),
    ];
  }
}

bool _isLive(SandboxDimension dimension, SandboxEnforcement enforcement) =>
    switch (dimension) {
      SandboxDimension.filesystemRead => enforcement.enforced.contains(
        SandboxCapability.filesystemRead,
      ),
      SandboxDimension.filesystemWrite => enforcement.enforced.contains(
        SandboxCapability.filesystemWrite,
      ),
      SandboxDimension.network => switch (enforcement.network) {
        NetworkConfined(:final tier) => tier != NetworkTier.all,
        // `all` minus loopback still blocks localhost, so it can explain a
        // failure; an ineligible tier confined nothing, so it cannot.
        NetworkPartiallyConfined() => true,
        NetworkIneligibleForConfinement() => false,
      },
    };

/// [lowered] is [output] pre-folded, so the markers match case-insensitively
/// while the evidence keeps the child's own wording.
List<String> _evidenceFor(
  SandboxDimension dimension,
  List<String> output,
  List<String> lowered,
) {
  final markers = _markers[dimension]!;
  return [
    for (var i = 0; i < output.length; i++)
      if (markers.any(lowered[i].contains)) output[i],
  ];
}

const _denialMarkers = [
  'permission denied',
  'operation not permitted',
  'access is denied',
  'eacces',
  'eperm',
];

const Map<SandboxDimension, List<String>> _markers = {
  SandboxDimension.filesystemRead: _denialMarkers,
  SandboxDimension.filesystemWrite: [
    ..._denialMarkers,
    'read-only file system',
    'erofs',
  ],
  SandboxDimension.network: [
    'network is unreachable',
    'connection refused',
    'could not resolve host',
    'temporary failure in name resolution',
    'enetunreach',
    'econnrefused',
  ],
};
