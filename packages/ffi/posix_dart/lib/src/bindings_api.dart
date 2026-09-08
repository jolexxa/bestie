// Method names mirror the libc symbols they wrap so the adapters in
// `bindings_adapters.dart` stay one-line delegations and a reader can
// match them against the man pages.
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;

/// Typed view over the libc symbols bestie calls.
///
/// ffigen emits `MacosPosixBindings` and `LinuxPosixBindings` as
/// unrelated classes — POSIX is standardized, so their signatures agree,
/// but Dart is nominally typed and ffigen cannot be told to emit an
/// `implements` clause. These interfaces supply the missing common type;
/// `bindings_adapters.dart` bridges each generated class onto them.
///
/// Split into a struct-free [PosixBindings] both platforms share, plus
/// [LinuxStructBindings] / [MacosStructBindings] for the handful of
/// calls whose pointee types genuinely differ. That split is deliberate:
/// `struct termios`, `struct statvfs` and `struct winsize` have
/// different field widths and offsets per platform, and flattening them
/// to `Pointer<Void>` would hide exactly the divergence the ffigen
/// structs exist to catch.

/// File-descriptor primitives. No struct crosses this boundary.
abstract interface class FdBindings {
  int dup(int fd);
  int dup2(int oldFd, int newFd);
  int close(int fd);
  int read(int fd, Pointer<Void> buf, int nbytes);
  int write(int fd, Pointer<Void> buf, int nbytes);
  int openMode(Pointer<Char> path, int flags, int mode);
}

/// Pseudoterminal allocation and fd flag control. No struct crosses this
/// boundary — the `winsize` ioctl lives on the per-platform interfaces.
abstract interface class PtyCoreBindings {
  int posix_openpt(int flags);
  int grantpt(int fd);
  int unlockpt(int fd);
  Pointer<Char> ptsname(int fd);
  int fcntlInt(int fd, int cmd, int arg);
}

/// Process creation and signalling.
///
/// The `posix_spawn` handles are the one place a `Pointer<Void>` is the
/// honest type rather than an erasure: Darwin typedefs
/// `posix_spawnattr_t` and `posix_spawn_file_actions_t` to `void *`,
/// while glibc inlines a struct. There is no common pointee to name, and
/// callers already allocate them as raw byte buffers sized by
/// `PosixSizes`. Everything else here is a plain integer or fd.
abstract interface class SpawnBindings {
  int kill(int pid, int sig);
  int pipe(Pointer<Int> fds);
  int posix_spawnp(
    Pointer<Int> pid,
    Pointer<Char> file,
    Pointer<Void> fileActions,
    Pointer<Void> attr,
    Pointer<Pointer<Char>> argv,
    Pointer<Pointer<Char>> envp,
  );
  int posix_spawn_file_actions_init(Pointer<Void> fileActions);
  int posix_spawn_file_actions_adddup2(
    Pointer<Void> fileActions,
    int fd,
    int newFd,
  );
  int posix_spawn_file_actions_destroy(Pointer<Void> fileActions);
  int posix_spawnattr_init(Pointer<Void> attr);
  int posix_spawnattr_destroy(Pointer<Void> attr);
}

/// Error-number formatting.
// This is a bindings interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class ErrnoBindings {
  Pointer<Char> strerror(int errno);
}

/// The surface that is identical on macOS and Linux.
abstract interface class PosixBindings
    implements FdBindings, PtyCoreBindings, SpawnBindings, ErrnoBindings {}

/// Calls whose pointee types differ per platform, named against glibc's
/// structs. See [MacosStructBindings] for the Darwin counterpart.
abstract interface class LinuxStructBindings {
  int tcgetattr(int fd, Pointer<linux.termios> termios);
  int tcsetattr(int fd, int optionalActions, Pointer<linux.termios> termios);
  int statvfs(Pointer<Char> path, Pointer<linux.Statvfs> buf);
  int ioctlWinSize(int fd, int request, Pointer<linux.WinSize> winsize);
}

/// Darwin counterpart to [LinuxStructBindings].
abstract interface class MacosStructBindings {
  int tcgetattr(int fd, Pointer<macos.termios> termios);
  int tcsetattr(int fd, int optionalActions, Pointer<macos.termios> termios);
  int statvfs(Pointer<Char> path, Pointer<macos.Statvfs> buf);
  int ioctlWinSize(int fd, int request, Pointer<macos.WinSize> winsize);
}

/// Darwin-only surface. Linux has no portable equivalent for any of
/// these, so they sit outside [PosixBindings] rather than being stubbed
/// to throw on one platform.
abstract interface class DarwinBindings {
  int mach_host_self();
  int host_statistics64(
    int hostPriv,
    int flavor,
    Pointer<Int> hostInfo64Out,
    Pointer<UnsignedInt> hostInfo64OutCnt,
  );
  int sysctlbyname(
    Pointer<Char> name,
    Pointer<Void> oldp,
    Pointer<Size> oldlenp,
    Pointer<Void> newp,
    int newlen,
  );
}
