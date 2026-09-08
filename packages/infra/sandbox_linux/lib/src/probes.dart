import 'dart:io';

import 'package:file/file.dart';

/// The kernel confinement capabilities the Linux adapter branches on. Injected
/// so acquisition is testable without a real kernel.
abstract interface class KernelProbe {
  /// Whether Landlock is active and an unprivileged ruleset will apply. When it
  /// is not, the adapter reports the sandbox unavailable.
  Future<bool> landlockAvailable();

  /// Whether `unshare(CLONE_NEWUSER | CLONE_NEWNET)` succeeds unprivileged
  /// *and* loopback can be brought up inside — the mechanism the `local`
  /// network tier needs. Stock Ubuntu locks this down, so `local` degrades
  /// there; `none`/`all` never depend on it.
  Future<bool> netnsAvailable();
}

/// The real probe: reads the active LSM list for Landlock, and attempts a
/// throwaway `unshare` for netns. Both results are cached — capabilities do not
/// change within a session.
class RealKernelProbe implements KernelProbe {
  /// Probes through [fileSystem].
  RealKernelProbe({required FileSystem fileSystem}) : _fs = fileSystem;

  final FileSystem _fs;
  bool? _landlock;
  Future<bool>? _netns;

  @override
  Future<bool> landlockAvailable() async => _landlock ??= _checkLandlock();

  // Landlock needs no privilege to apply once it is in the active LSM list, so
  // its presence there is a sound availability check.
  bool _checkLandlock() {
    try {
      final lsm = _fs.file('/sys/kernel/security/lsm');
      return lsm.existsSync() &&
          lsm.readAsStringSync().trim().split(',').contains('landlock');
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<bool> netnsAvailable() => _netns ??= _checkNetns();

  // Actually attempting the unshare in a throwaway child is the one reliable
  // signal — the AppArmor lockdown that blocks it is not a single sysctl, and
  // it can admit the unshare itself while denying CAP_NET_ADMIN inside, so the
  // probe must also bring `lo` up the way the guard will.
  Future<bool> _checkNetns() async {
    try {
      final result = await Process.run('unshare', [
        '--user',
        '--map-root-user',
        '--net',
        '--',
        'ip',
        'link',
        'set',
        'lo',
        'up',
      ]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
