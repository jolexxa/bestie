import 'dart:io';

import 'package:sandbox_windows/src/win32_provisioner.dart';
import 'package:sandbox_windows/src/windows_provisioner.dart';
import 'package:win32_dart/win32_dart.dart';

/// The argument that turns a bestie launch into the elevated helper.
const grantSandboxAncestorsFlag = '--grant-sandbox-ancestors';

/// The elevated helper: grants the bestie-read capability list access, this
/// folder only, on each directory it is handed.
class SandboxAncestorGrant {
  /// Grants through [provisioner] to [capabilitySid], complaining on [stderr].
  /// A null SID is reported as a failure.
  SandboxAncestorGrant({
    required String? capabilitySid,
    WindowsProvisioner? provisioner,
    StringSink? stderr,
  }) : _provisioner = provisioner,
       _capabilitySid = capabilitySid,
       _stderr = stderr;

  final WindowsProvisioner? _provisioner;
  final String? _capabilitySid;
  final StringSink? _stderr;

  /// The exit code the helper ends with when every grant applied.
  static const applied = 0;

  /// The exit code the helper ends with when a grant could not be applied.
  static const failed = 2;

  /// Grants each of [paths], reporting the exit code for the helper process.
  int run(List<String> paths) {
    final capabilitySid = _capabilitySid;
    if (capabilitySid == null) {
      (_stderr ?? stderr).writeln(
        'could not derive the bestie.read capability',
      );
      return failed;
    }
    final provisioner = _provisioner ?? Win32Provisioner();
    for (final path in paths) {
      final reason = provisioner.grantCapability(
        capabilitySid: capabilitySid,
        path: path,
        inheritance: NO_INHERITANCE,
      );
      if (reason != null) {
        (_stderr ?? stderr).writeln('$path: $reason');
        return failed;
      }
    }
    return applied;
  }

  // coverage:ignore-start
  /// The bestie-read capability SID on this host, or null if it cannot be
  /// derived.
  static String? derivedCapabilitySid() {
    final derived = Capabilities(win32).sidFor(bestieReadCapabilityName);
    if (derived is! SidSucceeded) return null;
    try {
      return derived.sid.asString();
    } finally {
      derived.sid.close();
    }
  }

  // coverage:ignore-end
}
