// coverage:ignore-file
//
// Every method here is a one-line delegation to an ffigen-generated
// class. There is no branch or arithmetic to get wrong, and the property
// worth protecting — that the generated surface still matches what bestie
// calls — is enforced by the compiler: regenerating bindings with a
// changed signature breaks this file at build time rather than at
// runtime with a `NoSuchMethodError`. Tests would restate the compiler.

// Method names mirror `bindings_api.dart`, which mirrors libc.
// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:posix_dart/src/bindings/linux_bindings.dart' as linux;
import 'package:posix_dart/src/bindings/macos_bindings.dart' as macos;
import 'package:posix_dart/src/bindings_api.dart';

/// Bridges the ffigen-generated Linux class onto the typed interfaces.
final class LinuxBindingsAdapter implements PosixBindings, LinuxStructBindings {
  const LinuxBindingsAdapter(this._bindings);

  final linux.LinuxPosixBindings _bindings;

  @override
  int dup(int fd) => _bindings.dup(fd);

  @override
  int dup2(int oldFd, int newFd) => _bindings.dup2(oldFd, newFd);

  @override
  int close(int fd) => _bindings.close(fd);

  @override
  int read(int fd, Pointer<Void> buf, int nbytes) =>
      _bindings.read(fd, buf, nbytes);

  @override
  int write(int fd, Pointer<Void> buf, int nbytes) =>
      _bindings.write(fd, buf, nbytes);

  @override
  int openMode(Pointer<Char> path, int flags, int mode) =>
      _bindings.openMode(path, flags, mode);

  @override
  int posix_openpt(int flags) => _bindings.posix_openpt(flags);

  @override
  int grantpt(int fd) => _bindings.grantpt(fd);

  @override
  int unlockpt(int fd) => _bindings.unlockpt(fd);

  @override
  Pointer<Char> ptsname(int fd) => _bindings.ptsname(fd);

  @override
  int fcntlInt(int fd, int cmd, int arg) => _bindings.fcntlInt(fd, cmd, arg);

  @override
  int kill(int pid, int sig) => _bindings.kill(pid, sig);

  @override
  int pipe(Pointer<Int> fds) => _bindings.pipe(fds);

  // The spawn handles are opaque by necessity, not by erasure — see the
  // note on `SpawnBindings`. glibc inlines both as structs.
  @override
  int posix_spawnp(
    Pointer<Int> pid,
    Pointer<Char> file,
    Pointer<Void> fileActions,
    Pointer<Void> attr,
    Pointer<Pointer<Char>> argv,
    Pointer<Pointer<Char>> envp,
  ) => _bindings.posix_spawnp(
    pid,
    file,
    fileActions.cast<linux.posix_spawn_file_actions_t>(),
    attr.cast<linux.posix_spawnattr_t>(),
    argv,
    envp,
  );

  @override
  int posix_spawn_file_actions_init(Pointer<Void> fileActions) =>
      _bindings.posix_spawn_file_actions_init(
        fileActions.cast<linux.posix_spawn_file_actions_t>(),
      );

  @override
  int posix_spawn_file_actions_adddup2(
    Pointer<Void> fileActions,
    int fd,
    int newFd,
  ) => _bindings.posix_spawn_file_actions_adddup2(
    fileActions.cast<linux.posix_spawn_file_actions_t>(),
    fd,
    newFd,
  );

  @override
  int posix_spawn_file_actions_destroy(Pointer<Void> fileActions) =>
      _bindings.posix_spawn_file_actions_destroy(
        fileActions.cast<linux.posix_spawn_file_actions_t>(),
      );

  @override
  int posix_spawnattr_init(Pointer<Void> attr) =>
      _bindings.posix_spawnattr_init(attr.cast<linux.posix_spawnattr_t>());

  @override
  int posix_spawnattr_destroy(Pointer<Void> attr) =>
      _bindings.posix_spawnattr_destroy(attr.cast<linux.posix_spawnattr_t>());

  @override
  Pointer<Char> strerror(int errno) => _bindings.strerror(errno);

  // ── LinuxStructBindings — pointee types already agree, no casts ──

  @override
  int tcgetattr(int fd, Pointer<linux.termios> termios) =>
      _bindings.tcgetattr(fd, termios);

  @override
  int tcsetattr(
    int fd,
    int optionalActions,
    Pointer<linux.termios> termios,
  ) => _bindings.tcsetattr(fd, optionalActions, termios);

  @override
  int statvfs(Pointer<Char> path, Pointer<linux.Statvfs> buf) =>
      _bindings.statvfs(path, buf);

  @override
  int ioctlWinSize(int fd, int request, Pointer<linux.WinSize> winsize) =>
      _bindings.ioctlWinSize(fd, request, winsize);
}

/// Bridges the ffigen-generated macOS class onto the typed interfaces,
/// plus the Darwin-only surface.
final class MacosBindingsAdapter
    implements PosixBindings, MacosStructBindings, DarwinBindings {
  const MacosBindingsAdapter(this._bindings);

  final macos.MacosPosixBindings _bindings;

  @override
  int dup(int fd) => _bindings.dup(fd);

  @override
  int dup2(int oldFd, int newFd) => _bindings.dup2(oldFd, newFd);

  @override
  int close(int fd) => _bindings.close(fd);

  @override
  int read(int fd, Pointer<Void> buf, int nbytes) =>
      _bindings.read(fd, buf, nbytes);

  @override
  int write(int fd, Pointer<Void> buf, int nbytes) =>
      _bindings.write(fd, buf, nbytes);

  @override
  int openMode(Pointer<Char> path, int flags, int mode) =>
      _bindings.openMode(path, flags, mode);

  @override
  int posix_openpt(int flags) => _bindings.posix_openpt(flags);

  @override
  int grantpt(int fd) => _bindings.grantpt(fd);

  @override
  int unlockpt(int fd) => _bindings.unlockpt(fd);

  @override
  Pointer<Char> ptsname(int fd) => _bindings.ptsname(fd);

  @override
  int fcntlInt(int fd, int cmd, int arg) => _bindings.fcntlInt(fd, cmd, arg);

  @override
  int kill(int pid, int sig) => _bindings.kill(pid, sig);

  @override
  int pipe(Pointer<Int> fds) => _bindings.pipe(fds);

  // Darwin typedefs both handles to `void *`, so these casts land on
  // `Pointer<Pointer<Void>>` rather than a struct pointer — which is
  // precisely why the interface leaves them opaque.
  @override
  int posix_spawnp(
    Pointer<Int> pid,
    Pointer<Char> file,
    Pointer<Void> fileActions,
    Pointer<Void> attr,
    Pointer<Pointer<Char>> argv,
    Pointer<Pointer<Char>> envp,
  ) => _bindings.posix_spawnp(
    pid,
    file,
    fileActions.cast<macos.posix_spawn_file_actions_t>(),
    attr.cast<macos.posix_spawnattr_t>(),
    argv,
    envp,
  );

  @override
  int posix_spawn_file_actions_init(Pointer<Void> fileActions) =>
      _bindings.posix_spawn_file_actions_init(
        fileActions.cast<macos.posix_spawn_file_actions_t>(),
      );

  @override
  int posix_spawn_file_actions_adddup2(
    Pointer<Void> fileActions,
    int fd,
    int newFd,
  ) => _bindings.posix_spawn_file_actions_adddup2(
    fileActions.cast<macos.posix_spawn_file_actions_t>(),
    fd,
    newFd,
  );

  @override
  int posix_spawn_file_actions_destroy(Pointer<Void> fileActions) =>
      _bindings.posix_spawn_file_actions_destroy(
        fileActions.cast<macos.posix_spawn_file_actions_t>(),
      );

  @override
  int posix_spawnattr_init(Pointer<Void> attr) =>
      _bindings.posix_spawnattr_init(attr.cast<macos.posix_spawnattr_t>());

  @override
  int posix_spawnattr_destroy(Pointer<Void> attr) =>
      _bindings.posix_spawnattr_destroy(attr.cast<macos.posix_spawnattr_t>());

  @override
  Pointer<Char> strerror(int errno) => _bindings.strerror(errno);

  // ── MacosStructBindings — pointee types already agree, no casts ──

  @override
  int tcgetattr(int fd, Pointer<macos.termios> termios) =>
      _bindings.tcgetattr(fd, termios);

  @override
  int tcsetattr(
    int fd,
    int optionalActions,
    Pointer<macos.termios> termios,
  ) => _bindings.tcsetattr(fd, optionalActions, termios);

  @override
  int statvfs(Pointer<Char> path, Pointer<macos.Statvfs> buf) =>
      _bindings.statvfs(path, buf);

  @override
  int ioctlWinSize(int fd, int request, Pointer<macos.WinSize> winsize) =>
      _bindings.ioctlWinSize(fd, request, winsize);

  // ── DarwinBindings ──

  @override
  int mach_host_self() => _bindings.mach_host_self();

  @override
  int host_statistics64(
    int hostPriv,
    int flavor,
    Pointer<Int> hostInfo64Out,
    Pointer<UnsignedInt> hostInfo64OutCnt,
  ) => _bindings.host_statistics64(
    hostPriv,
    flavor,
    hostInfo64Out,
    hostInfo64OutCnt,
  );

  @override
  int sysctlbyname(
    Pointer<Char> name,
    Pointer<Void> oldp,
    Pointer<Size> oldlenp,
    Pointer<Void> newp,
    int newlen,
  ) => _bindings.sysctlbyname(name, oldp, oldlenp, newp, newlen);
}
