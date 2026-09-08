import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:posix_dart/posix_dart.dart';

/// `posix_openpt` + `grantpt` + `unlockpt` + `ptsname` + `open(slave)`
/// — the standard POSIX recipe for getting a master/slave pseudo-
/// terminal pair.
///
/// Both fds are stamped with `FD_CLOEXEC` so that **any other
/// `Process.start` / `fork()` happening elsewhere in the host does
/// not silently inherit our pty fds**. Without `CLOEXEC` an
/// unrelated child holding the slave keeps the master from ever
/// seeing EOF when our pty child dies, and an unrelated child
/// holding the master is just a fd-leak waiting to wedge a future
/// `read()` / kernel pty slot.
class PosixOpenpty {
  /// Defaults to the host's libc. Pass [bindings] to substitute a double.
  PosixOpenpty({PtyCoreBindings? bindings}) : _b = bindings ?? posixBindings;

  final PtyCoreBindings _b;

  OpenptyResult open() {
    final masterFd = _b.posix_openpt(oRdwr | oNoctty);
    if (masterFd < 0) {
      return OpenptyFailed(
        PosixFailure.withoutErrno('posix_openpt', 'returned $masterFd'),
      );
    }

    final cloexecMaster = _setCloexec(masterFd);
    if (cloexecMaster != null) {
      posixFd.close(masterFd);
      return OpenptyFailed(cloexecMaster);
    }

    if ((_b.grantpt(masterFd)) != 0) {
      posixFd.close(masterFd);
      return OpenptyFailed(
        PosixFailure.withoutErrno('grantpt', 'nonzero return'),
      );
    }
    if ((_b.unlockpt(masterFd)) != 0) {
      posixFd.close(masterFd);
      return OpenptyFailed(
        PosixFailure.withoutErrno('unlockpt', 'nonzero return'),
      );
    }

    final namePtr = _b.ptsname(masterFd);
    if (namePtr == ffi.nullptr) {
      posixFd.close(masterFd);
      return OpenptyFailed(
        PosixFailure.withoutErrno('ptsname', 'returned NULL'),
      );
    }
    final slavePath = namePtr.cast<Utf8>().toDartString();

    final opened = posixFd.open(slavePath, oRdwr | oNoctty);
    final int slaveFd;
    switch (opened) {
      case FdOpenSucceeded(:final fd):
        slaveFd = fd;
      case FdOpenFailed(:final failure):
        posixFd.close(masterFd);
        return OpenptyFailed(failure);
    }

    final cloexecSlave = _setCloexec(slaveFd);
    if (cloexecSlave != null) {
      posixFd
        ..close(masterFd)
        ..close(slaveFd);
      return OpenptyFailed(cloexecSlave);
    }

    return OpenptySucceeded(
      masterFd: masterFd,
      slaveFd: slaveFd,
      slavePath: slavePath,
    );
  }
}

/// [PosixOpenpty] over the host's libc.
final PosixOpenpty posixOpenpty = PosixOpenpty();

/// Set `FD_CLOEXEC` on [fd]. Returns `null` on success, or a
/// [PosixFailure] describing which fcntl call failed.
///
/// Uses the variadic 3-arg `fcntlInt` shape for both calls — the
/// kernel ignores the third arg for `F_GETFD`, but ffigen only
/// emits the variadic shape once `fcntl` is registered as variadic,
/// so we route through it consistently.
PosixFailure? _setCloexec(int fd) {
  final flags = posixBindings.fcntlInt(fd, fGetfd, 0);
  if (flags < 0) {
    return PosixFailure.withoutErrno('fcntl(F_GETFD)', 'returned $flags');
  }
  final rc = posixBindings.fcntlInt(fd, fSetfd, flags | fdCloexec);
  if (rc < 0) {
    return PosixFailure.withoutErrno('fcntl(F_SETFD)', 'returned $rc');
  }
  return null;
}

sealed class OpenptyResult {
  const OpenptyResult();
}

/// The master/slave fd pair plus the slave's pseudo-terminal
/// device path.
final class OpenptySucceeded extends OpenptyResult {
  const OpenptySucceeded({
    required this.masterFd,
    required this.slaveFd,
    required this.slavePath,
  });

  final int masterFd;
  final int slaveFd;
  final String slavePath;
}

final class OpenptyFailed extends OpenptyResult {
  const OpenptyFailed(this.failure);
  final PosixFailure failure;
}
